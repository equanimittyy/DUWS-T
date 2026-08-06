// Locality: server -- registered once for all towns by fnc_civ_init_Tomata.
/*
    fnc_civ_handler.sqf
    Registers every town's civilian crowd as an occupant of its site and hands the clock to the
    shared poller. No params. Returns once the hooks are in place.

    What is left here is the crowd's own three answers -- when it may exist, what it fills with, and
    how it is collected -- because everything else it used to do is the same question every other
    site asks. The poll interval, the two-sample confirm, the grace period and the presence test are
    fnc_site_poller's now.

    RAVAGE and WBK keep the older trigger-driven handlers.
*/
if (!isServer) exitWith {};

// The crowd streams on the "town_crowd" profile in DUWS_streamProfiles. Its grace is half the zone
// gate's, deliberately. Towns are disjoint -- the cull in fnc_civ_init_Tomata pushes them apart until
// they are -- so a player is inside at most one, and a long grace leaves a trail of fully populated
// towns behind anyone crossing the map. The ceiling thins that trail but does not end it: its floor of
// three keeps every occupied town holding somebody, so the overshoot tracks how many towns are occupied
// at once, and the grace is what decides that. A zone can afford the longer clock because there are
// forty of it at the very most.
//
// Its buffer is 200, not the zone gate's 400: zones sit 1200 m apart by zones_spacing, towns only until
// their discs stop touching, so two small ones can be 210 m apart. What 200 double-triggers is
// self-limiting -- radius is buildings x 10 floored at 100, so the tight pairs are towns of ten
// civilians or fewer.

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

// Collected by roster, which is what the town filled rather than whatever is standing in it. The
// scan this replaces walked allUnits + allDeadMen once per emptied town looking for a tag, which is
// a several-hundred-entry pass to find a list the fill already had.
//
// Corpses go with the living: they stay on the roster, and leaving them to the litter sweep does
// nothing at all when the campaign was started with the cleanup lifetime switched off. A recruited
// civilian is off the roster by then -- fnc_recruit_civilian_server drops it as it changes hands --
// and one who turned hostile is still this town's. Groups need no bookkeeping: fnc_civ_spawnUnit
// creates them with deleteWhenEmpty set.
private _fnc_empty = {
    params ["_key", "_o"];
    private _i = _o get "townIndex";
    missionNamespace setVariable [format ["civ_spawned_%1", _i], false];
    private _emptied = 0;
    {
        if (!isNull _x) then { deleteVehicle _x; _emptied = _emptied + 1 };
    } forEach ([_key, "crowd"] call fnc_site_roster);
    [_key, "crowd"] call fnc_site_roster_clear;
    if (duws_log_level >= 4) then {
        ["DEBUG", "CIV", format ["Town %1 emptied, %2 deleted", _i, _emptied]] call fnc_log;
    };
};

// Set before the fill is dispatched, not inside it: fnc_civ_liveTarget counts a town as occupied
// from this flag, and a town that fills on the same tick as another must already be visible to the
// other's throttle.
private _fnc_wake = {
    params ["_key", "_o"];
    private _i = _o get "townIndex";
    missionNamespace setVariable [format ["civ_spawned_%1", _i], true];
    [_i] call fnc_civ_town_reveal;
    private _site = [_key] call fnc_site_at;
    [_i, _site get "pos", _site get "radius"] spawn (missionNamespace getVariable "DUWS_civ_fill");
};

// Reached through the mission namespace because the hook runs from the poller's scope, not this one.
missionNamespace setVariable ["DUWS_civ_fill", _fnc_fill];

for "_i" from 0 to (_count - 1) do {
    private _key = [_i] call fnc_town_site_key;
    private _centre = _centres select _i;
    private _radius = _radii param [_i, 500];
    [_key, _centre, _radius] call fnc_site_register;
    // Unlatched, unlike a garrison. The latch exists to stop men appearing around a player who was
    // already standing there, and a crowd that never arrives is worse than one that fades in: a town
    // the player happens to start in would otherwise stay empty until they had left it once.
    private _o = [_key, "crowd", CIVILIAN, "town_crowd"] call fnc_site_occupant_register_profile;
    // The only field the crowd adds: everything else about where this town is lives on the site.
    _o set ["townIndex", _i];
    [_key, "crowd", createHashMapFromArray [["wake", _fnc_wake], ["sleep", _fnc_empty]]] call fnc_site_hooks_set;
};

["INFO", "CIV", format ["%1 town crowds registered with the site poller", _count]] call fnc_log;
