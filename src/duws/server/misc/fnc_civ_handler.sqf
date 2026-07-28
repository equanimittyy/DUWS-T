// Locality: server -- one thread per town, started by fnc_civ_init_Tomata at registration.
/*
    fnc_civ_handler.sqf
    Streams one town's civilians: fill it when players arrive, empty it once they have been gone
    long enough. Params: [_locIndex]. Never returns.

    Same shape as the enemy zone gate in server/init_zones/fnc_spawnWait.sqf, deliberately. A town
    and a zone answer the same two questions -- is anyone here, and has anyone been here lately --
    and answering them a second way is what the mutex, the campaign-wide ceiling, the spawning/
    spawned flag pair and the recycle pass were each patching around. RAVAGE and WBK keep the
    older trigger-driven handlers.
*/
if (!isServer) exitWith {};
params ["_locIndex"];

// Taken from fnc_spawnWait so a town and a zone come up and go down on the same clock. The
// confirm delay is what stops a helicopter crossing the disc filling a town for someone already
// past it; the grace period restarts on every sighting, so leaving is what starts the clock
// rather than how long you stayed.
#define POLL_INTERVAL 10
#define CONFIRM_DELAY 5
#define DESPAWN_TIMER 300

// Share of the crowd placed on open ground beside a building rather than inside one. All-indoors
// reads as a ghost town whose houses happen to be occupied; all-outdoors as a bus queue.
#define OUTDOOR_SHARE 0.6

private _locations = missionNamespace getVariable ["civ_locations", []];
if (_locIndex >= count _locations) exitWith {
    ["ERROR", "CIV", format ["Invalid location index %1", _locIndex]] call fnc_log;
};
private _centerPos = getPos (_locations select _locIndex);
private _radius = (missionNamespace getVariable ["civ_radii", []]) param [_locIndex, 500];
if (_centerPos isEqualTo [0,0,0]) exitWith {
    ["ERROR", "CIV", format ["Location %1 has zero position", _locIndex]] call fnc_log;
};

// Read once: fnc_civ_setup_array runs before registration and never writes the list again.
private _civArray = missionNamespace getVariable ["civ_array", []];
if (_civArray isEqualTo []) exitWith {
    ["ERROR", "CIV", format ["civ_array is empty; town %1 will not be populated", _locIndex]] call fnc_log;
};

// fnc_civ_spawnUnit reads this out of the mission namespace for every civilian it creates and
// throws on a nil, so it has to exist before the first fill. Set here rather than per fill
// because every town wants the same handler on its crowd.
missionNamespace setVariable ["CIV_KILLED_HANDLER", {
    params ["_dead", "_killer", "_instigator"];
    if ((_dead getVariable ["civ_locIndex", -1]) == -1) exitWith {};
    if (_dead getVariable ["isHostile", false]) exitWith {};
    if (side _dead == resistance) exitWith {};
    [_dead, _killer, _instigator] call fnc_civ_rep_Tomata;
}];

// Players only, where the zone gate counts friendly AI as well: a town fills so there is somebody
// to talk to, and an AI squad passing through has nobody to talk to it.
private _present = { [_centerPos, _radius] call fnc_civ_playerNear };

private _maxOutdoorDist = _radius * 0.8;
private _outdoorRange = 100 min _maxOutdoorDist;

while {true} do {
    waitUntil {
        sleep POLL_INTERVAL;
        private _seen = call _present;
        if (_seen) then { sleep CONFIRM_DELAY; _seen = call _present };
        _seen
    };

    [_locIndex] call fnc_civ_town_reveal;

    // Surveyed once at campaign generation and kept for the rest of the mission: the terrain sweep
    // behind it is the heaviest engine call in the civilian system, and every town entry used to
    // repeat it. Destroyed buildings go null, so the list is filtered rather than trusted.
    private _buildings = (missionNamespace getVariable [format ["civ_buildings_%1", _locIndex], []])
        select { !isNull _x };
    private _target = (missionNamespace getVariable ["civ_density", 15])
        min (missionNamespace getVariable [format ["civ_pop_%1", _locIndex], 0]);

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
        if (!isNull _unit) then { _groups pushBack (group _unit) };
        sleep 0.2;
    };

    [_groups, _buildings] spawn fnc_civ_wp_Tomata;
    if (duws_log_level >= 4) then {
        ["DEBUG", "CIV", format ["Town %1 filled with %2 of a target %3", _locIndex, count _groups, _target]] call fnc_log;
    };

    private _lastSeen = time;
    while {time - _lastSeen < DESPAWN_TIMER} do {
        sleep POLL_INTERVAL;
        if (call _present) then { _lastSeen = time };
    };

    // The tag is the whole test. fnc_recruit_civilian_server clears it before the civilian joins
    // the player, so nothing the player owns can be swept up here, and one who turned hostile is
    // still this town's. Corpses go with the living rather than being left to the litter sweep,
    // which does nothing at all when the campaign was started with the cleanup lifetime switched
    // off. Groups need no bookkeeping: fnc_civ_spawnUnit creates them with deleteWhenEmpty set.
    private _emptied = 0;
    {
        if ((_x getVariable ["civ_locIndex", -1]) == _locIndex) then {
            deleteVehicle _x;
            _emptied = _emptied + 1;
        };
    } forEach (allUnits + allDeadMen);
    if (duws_log_level >= 4) then {
        ["DEBUG", "CIV", format ["Town %1 emptied, %2 deleted", _locIndex, _emptied]] call fnc_log;
    };
};
