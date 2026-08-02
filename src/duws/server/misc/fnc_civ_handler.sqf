// Locality: server -- one thread for all towns, started by fnc_civ_init_Tomata at registration.
/*
    fnc_civ_handler.sqf
    Streams every town's civilians: fill a town when players arrive, empty it once they have been
    gone long enough. No params. Never returns.

    Per town this is the enemy zone gate from server/init_zones/fnc_spawnWait.sqf -- confirm a
    sighting before filling, then a grace period that restarts on every sighting. Answering those
    two questions a second way is what the mutex, the spawning/spawned flag pair and the recycle
    pass were each patching around. The campaign-wide ceiling stays: it is not an answer to those
    questions but a bound on the total crowd, which nothing else provides (fnc_civ_liveTarget).

    One thread for every town rather than one each, which is the one place this departs from the
    zone gate. Selection hands three towns to the HQ and three to every zone, then adds a top-up
    wave, so a 40-zone campaign registers over 160 of them against a zone count of 40. A thread
    apiece would have each of those build its own player list every tick; here the list is built
    once and every town is tested against it.

    RAVAGE and WBK keep the older trigger-driven handlers.
*/
if (!isServer) exitWith {};

#define POLL_INTERVAL 10

// Half the zone gate's grace, deliberately. Towns are disjoint -- the cull in
// fnc_civ_init_Tomata pushes them apart until they are -- so a player is inside at most one, and a
// long grace leaves a trail of fully populated towns behind anyone crossing the map. The
// ceiling thins that trail but does not end it: its floor of three keeps every occupied town
// holding somebody, so the overshoot tracks how many towns are occupied at once, and the grace is
// what decides that. A zone can afford the longer clock because there are forty of it at the very most.
#define DESPAWN_TIMER 60

// How far outside a town its arrival is noticed, so the fill lands before the player does. Not the
// zone gate's 400: zones sit 1200 m apart by zones_spacing, towns only until their discs stop
// touching, so two small ones can be 210 m apart. What 200 double-triggers is self-limiting --
// radius is buildings x 10 floored at 100, so the tight pairs are towns of ten civilians or fewer.
#define STREAM_BUFFER 200

// Share of the crowd placed on open ground beside a building rather than inside one. All-indoors
// reads as a ghost town whose houses happen to be occupied; all-outdoors as a bus queue.
#define OUTDOOR_SHARE 0.6

private _locations = missionNamespace getVariable ["civ_locations", []];
private _radii = missionNamespace getVariable ["civ_radii", []];
private _count = count _locations;
if (_count == 0) exitWith {};

// Read once: fnc_civ_setup_array runs before registration and never writes the list again.
if ((missionNamespace getVariable ["civ_array", []]) isEqualTo []) exitWith {
    ["ERROR", "CIV", "civ_array is empty; no town will be populated"] call fnc_log;
};

// fnc_civ_spawnUnit reads this out of the mission namespace for every civilian it creates and
// throws on a nil, so it has to exist before the first fill.
missionNamespace setVariable ["CIV_KILLED_HANDLER", {
    params ["_dead", "_killer", "_instigator"];
    if ((_dead getVariable ["civ_locIndex", -1]) == -1) exitWith {};
    if (_dead getVariable ["isHostile", false]) exitWith {};
    if (side _dead == resistance) exitWith {};
    [_dead, _killer, _instigator] call fnc_civ_rep_Tomata;
}];

// Spawned rather than called: a fill sleeps between units, and this thread owns the grace clock of
// every other town. Nothing from this scope reaches it -- spawn breaks the scope chain -- so it
// reads the town's own state back out of the mission namespace.
private _fnc_fill = {
    params ["_locIndex", "_centerPos", "_radius"];

    // Surveyed once at campaign generation and kept for the rest of the mission: the terrain sweep
    // behind it is the heaviest engine call in the civilian system, and every town entry used to
    // repeat it. Destroyed buildings go null, so the list is filtered rather than trusted.
    private _buildings = (missionNamespace getVariable [format ["civ_buildings_%1", _locIndex], []])
        select { !isNull _x };
    private _civArray = missionNamespace getVariable ["civ_array", []];
    // Read at fill time, so the throttle sees whichever towns are occupied at this moment. It
    // reads occupancy from civ_spawned_<n>, which the poller sets as it dispatches this.
    private _target = [missionNamespace getVariable ["civ_density", 15], _locIndex] call fnc_civ_liveTarget;
    private _maxOutdoorDist = _radius * 0.8;
    private _outdoorRange = 100 min _maxOutdoorDist;

    private _groups = [];
    for "_i" from 1 to _target do {
        // selectRandom returns nil on an empty list, which the isNull below cannot be asked about.
        private _building = if (_buildings isEqualTo []) then { objNull } else { selectRandom _buildings };
        private _pos = [0,0,0];
        if (isNull _building) then {
            _pos = [_centerPos, 10, _maxOutdoorDist, 3, 0, 0.5, 0] call BIS_fnc_findSafePos;
            if (_pos isEqualTo [0,0,0]) then { _pos = _centerPos };
        } else {
            // An empty position list stands in for the outdoor roll, so a building with no
            // interior positions falls through to the same open-ground placement.
            private _positions = if (random 1 < OUTDOOR_SHARE) then { [] } else { [_building] call BIS_fnc_buildingPositions };
            if (_positions isEqualTo []) then {
                _pos = [_building, 5, _outdoorRange, 3, 0, 0.3, 0] call BIS_fnc_findSafePos;
                if (_pos isEqualTo [0,0,0]) then { _pos = getPos _building };
            } else {
                _pos = selectRandom _positions;
            };
        };

        private _unit = [_locIndex, _pos, selectRandom _civArray, false] call fnc_civ_spawnUnit;
        if (!isNull _unit) then {
            _groups pushBack (group _unit);
            ([[_locIndex] call fnc_town_site_key, "crowd"] call fnc_site_roster) pushBack _unit;
        };
        sleep 0.2;
    };

    [_groups, _buildings] spawn fnc_civ_wp_Tomata;
    if (duws_log_level >= 4) then {
        ["DEBUG", "CIV", format ["Town %1 filled with %2 of a target %3", _locIndex, count _groups, _target]] call fnc_log;
    };
};

private _centres = _locations apply { getPos _x };
// One record per town rather than three arrays indexed alike: fields indexed the same way are one
// transposition from a town streaming against another's clock. civ_spawned_<n> is the same "awake"
// fact published for fnc_civ_liveTarget, which has no other way to see which towns are occupied, and
// is written only at the two transitions below.
private _crowds = [];
for "_i" from 0 to (_count - 1) do {
    private _key = [_i] call fnc_town_site_key;
    [_key, _centres select _i, _radii param [_i, 500]] call fnc_site_register;
    _crowds pushBack ([_key, "crowd", CIVILIAN, STREAM_BUFFER, DESPAWN_TIMER] call fnc_site_occupant_register);
};

while {true} do {
    sleep POLL_INTERVAL;

    // Built once for every town, which is the whole point of the shared thread. Dead players are
    // dropped: a body lying in the street should not hold a town up until its owner respawns.
    private _players = (call BIS_fnc_listPlayers) select { alive _x };
    private _now = time;
    private _expired = [];

    for "_i" from 0 to (_count - 1) do {
        private _centre = _centres select _i;
        // Buffered for arrival only. The fill itself gets the town's own radius, or the crowd
        // would be scattered across the open ground the buffer reaches into.
        private _radius = _radii param [_i, 500];
        private _c = _crowds select _i;
        private _here = (_players findIf { _x distance _centre < _radius + (_c get "buffer") }) >= 0;

        if (_c get "awake") then {
            if (_here) then { _c set ["emptySince", _now] };
            if (_now - (_c get "emptySince") >= (_c get "grace")) then {
                _c set ["awake", false];
                missionNamespace setVariable [format ["civ_spawned_%1", _i], false];
                _expired pushBack _i;
            };
        } else {
            // Two consecutive polls, which is the confirm the zone gate spends a sleep on: a
            // helicopter crossing the disc is gone by the next sample, and a fill is expensive
            // enough to be worth the wait. A second sample rather than a sleep because this
            // thread holds the grace clock of every other town and must not stall on one.
            if (_here && {_c get "seenLast"}) then {
                _c set ["awake", true];
                // Set before the fill is dispatched, not inside it: fnc_civ_liveTarget counts a
                // town as occupied from this flag, and a town that fills on the same tick as
                // another must already be visible to the other's throttle.
                missionNamespace setVariable [format ["civ_spawned_%1", _i], true];
                _c set ["emptySince", _now];
                [_i] call fnc_civ_town_reveal;
                [_i, _centre, _radius] spawn _fnc_fill;
            };
        };
        _c set ["seenLast", _here];
    };

    // Collected by roster, which is what the town filled rather than whatever is standing in it.
    // The scan this replaces walked allUnits + allDeadMen once per emptied town looking for a tag,
    // which is a several-hundred-entry pass to find a list the fill already had.
    //
    // Corpses go with the living: they stay on the roster, and leaving them to the litter sweep does
    // nothing at all when the campaign was started with the cleanup lifetime switched off. A
    // recruited civilian is off the roster by then -- fnc_recruit_civilian_server drops it as it
    // changes hands -- and one who turned hostile is still this town's. Groups need no bookkeeping:
    // fnc_civ_spawnUnit creates them with deleteWhenEmpty set.
    if !(_expired isEqualTo []) then {
        private _emptied = 0;
        {
            private _key = [_x] call fnc_town_site_key;
            {
                if (!isNull _x) then { deleteVehicle _x; _emptied = _emptied + 1 };
            } forEach ([_key, "crowd"] call fnc_site_roster);
            [_key, "crowd"] call fnc_site_roster_clear;
        } forEach _expired;
        if (duws_log_level >= 4) then {
            ["DEBUG", "CIV", format ["Towns %1 emptied, %2 deleted", _expired, _emptied]] call fnc_log;
        };
    };
};
