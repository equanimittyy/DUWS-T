// Locality: server; the trigger bodies that call this run on the machine that triggers them.
/*
    fnc_civ_handler_ravage.sqf
    RAVAGE crowd handling for one town: spawn and cleanup. Params: [_locIndex, _mode],
    _mode "spawn" or "cleanup".

    Split out of fnc_civ_handler when the plain civilian path moved onto the enemy-zone streaming
    model. This is the older trigger-driven system carried over as it stood -- the mutex, the
    campaign-wide ceiling and the recycle pass are all still here because RAVAGE was to keep its
    behaviour unchanged, not because any of them proved necessary.
*/
if (!isServer) exitWith {};

// How many buildings the crowd is spread over, and the one number that sets how busy a town
// feels. Fixed, NOT scaled by the density setting: sizing it as a multiple of the crowd made the
// area grow in step with the head count, so civilians-per-square-metre came out identical at
// every setting and the slider only widened the populated patch. Held constant, density and
// crowding rise together, and a town's own building density decides how much ground those 20
// buildings cover -- 97 m in Kavala against 228 m in a 47-building town. Matched in
// fnc_civ_recycle, which re-clusters around the player on the same footing.
#define CLUSTER_BUILDINGS 20

params ["_locIndex", "_mode"];

if (isNil "civ_current_active_location") then {
    civ_current_active_location = -1;
    publicVariable "civ_current_active_location";
};

private _locations = missionNamespace getVariable ["civ_locations", []];
private _radii = missionNamespace getVariable ["civ_radii", []];
if (_locIndex >= count _locations) exitWith {
    ["ERROR", "CIV", format ["Invalid location index %1", _locIndex]] call fnc_log;
};
private _location = _locations select _locIndex;
private _centerPos = getPos _location;
private _triggerRadius = _radii param [_locIndex, 500];
if (_centerPos isEqualTo [0,0,0]) exitWith {
    if (duws_log_level >= 4) then { ["DEBUG", "CIV", format ["Location %1 has zero position", _locIndex]] call fnc_log; };
};
if (_mode == "cleanup") exitWith {
    if (duws_log_level >= 4) then { ["DEBUG", "CIV", format ["[Cleanup] Requested for location %1, will execute in 30 seconds", _locIndex]] call fnc_log; };
    private _pendingVar = format ["civ_pending_cleanup_%1", _locIndex];
    missionNamespace setVariable [_pendingVar, true];

    // The monitor is deliberately left running through the grace period. Killing it here meant a
    // player who stepped back in during the grace cancelled the deletion but kept a town with no
    // monitor: nothing recycled it, and nothing would ever clean it up either, because the
    // presence trigger only fires on a fresh entry they never made. It exits on its own once
    // civ_spawned goes false below.
    sleep 30;

    if (!(missionNamespace getVariable [_pendingVar, false])) exitWith {
        if (duws_log_level >= 4) then { ["DEBUG", "CIV", format ["[Cleanup] Pending cleanup cancelled for %1", _locIndex]] call fnc_log; };
    };

    private _playersInArea = allPlayers select { _x distance _centerPos < _triggerRadius };
    if (count _playersInArea > 0) exitWith {
        ["ERROR", "CIV", format ["[Cleanup] Cleanup aborted for %1 because players are still in area", _locIndex]] call fnc_log;
        missionNamespace setVariable [_pendingVar, false];
    };

    if (duws_log_level >= 4) then { ["DEBUG", "CIV", format ["[Cleanup] Executing cleanup for location %1", _locIndex]] call fnc_log; };

    private _spawnedKey = format ["civ_spawned_%1", _locIndex];
    if (!(missionNamespace getVariable [_spawnedKey, false])) exitWith {
        if (duws_log_level >= 4) then { ["DEBUG", "CIV", format ["[Cleanup] Location %1 not spawned, ignoring", _locIndex]] call fnc_log; };
        missionNamespace setVariable [_pendingVar, false];
        [_locIndex] call fnc_civ_mode_releaseLock;
    };

    private _allUnits = allUnits;
    private _deletedUnits = 0;
    {
        private _locIdx = _x getVariable ["civ_locIndex", -1];
        if (_locIdx == _locIndex) then {
            if (side _x == WEST && !(_x getVariable ["isHostile", false])) then {
                _x setVariable ["civ_locIndex", nil];
            } else {
                deleteVehicle _x;
                _deletedUnits = _deletedUnits + 1;
            };
        };
    } forEach _allUnits;
    if (duws_log_level >= 4) then { ["DEBUG", "CIV", format ["[Cleanup] Deleted %1 units via allUnits scan", _deletedUnits]] call fnc_log; };

    private _groups = missionNamespace getVariable [format ["civ_groups_%1", _locIndex], []];
    private _deletedGroups = 0;
    {
        if (!isNull _x) then {
            { deleteVehicle _x } forEach units _x;
            deleteGroup _x;
            _deletedGroups = _deletedGroups + 1;
        };
    } forEach _groups;
    if (duws_log_level >= 4) then { ["DEBUG", "CIV", format ["[Cleanup] Deleted %1 groups from civ_groups list", _deletedGroups]] call fnc_log; };
    missionNamespace setVariable [format ["civ_groups_%1", _locIndex], nil];

    private _allDead = allDeadMen;
    private _deletedCorpses = 0;
    {
        private _locIdx = _x getVariable ["civ_locIndex", -1];
        if (_locIdx == _locIndex) then {
            deleteVehicle _x;
            _deletedCorpses = _deletedCorpses + 1;
        };
    } forEach _allDead;
    if (duws_log_level >= 4) then { ["DEBUG", "CIV", format ["[Cleanup] Deleted %1 corpses", _deletedCorpses]] call fnc_log; };

    missionNamespace setVariable [_spawnedKey, false];
    missionNamespace setVariable [_pendingVar, false];

    [_locIndex] call fnc_civ_mode_releaseLock;
    if (duws_log_level >= 4) then { ["DEBUG", "CIV", format ["[Cleanup] Lock released for location %1", _locIndex]] call fnc_log; };

    if (duws_log_level >= 4) then { ["DEBUG", "CIV", format ["[Cleanup] Finished for location %1", _locIndex]] call fnc_log; };
};

if (_mode == "spawn") then {
    private _spawningKey = format ["civ_spawning_%1", _locIndex];
    private _spawnedKey = format ["civ_spawned_%1", _locIndex];

    ([_locIndex, _centerPos, _triggerRadius, "CIV"] call fnc_civ_mode_spawnGate) params ["_gateOk", "_targetPop"];
    if (!_gateOk) exitWith {};

    private _density = missionNamespace getVariable ["civ_density", 15];
    private _spawnCount = [_density, _locIndex] call fnc_civ_liveTarget;
    if (duws_log_level >= 4) then { ["DEBUG", "CIV", format ["[Spawn] Location %1: pop %2, live target %3", _locIndex, _targetPop, _spawnCount]] call fnc_log; };

    // Surveyed once at campaign generation and kept for the rest of the mission: the terrain sweep
    // behind it is the heaviest engine call in the civilian system, and every town entry used to
    // repeat it. Destroyed buildings go null, so the list is filtered rather than trusted.
    private _usableBuildings = (missionNamespace getVariable [format ["civ_buildings_%1", _locIndex], []]) select { !isNull _x };
    if (duws_log_level >= 4) then { ["DEBUG", "CIV", format ["[Spawn] Usable buildings count: %1", count _usableBuildings]] call fnc_log; };

    private _civArray = missionNamespace getVariable ["civ_array", []];
    if (_civArray isEqualTo []) exitWith {
        ["ERROR", "CIV", "[Spawn] civ_array is empty!"] call fnc_log;
        missionNamespace setVariable [_spawnedKey, false];
        missionNamespace setVariable [_spawningKey, false];
        [_locIndex] call fnc_civ_mode_releaseLock;
    };

    waitUntil { sleep 1; !isNil "blufor_helmets" && !isNil "opfor_helmets" };
    duws_blufor_helmets = +blufor_helmets;
    duws_opfor_helmets = +opfor_helmets;
    duws_blufor_vests = +blufor_vests;
    duws_opfor_vests = +opfor_vests;
    duws_blufor_uniforms = +blufor_uniforms;
    duws_opfor_uniforms = +opfor_uniforms;

    // Read by fnc_civ_spawnUnit, which only calls it on the RAVAGE path -- salvaged military kit
    // on the undead is what tells this mode's crowd from a living one.
    fnc_applyEquipment = {
        params ["_unit", "_isZombie", "_unitType", "_unitIndex"];
        if (_isZombie) then {
            { _unit setSkill [_x, 1.0]; } forEach ["aimingAccuracy", "aimingShake", "aimingSpeed", "spotDistance", "spotTime", "courage", "reloadSpeed", "commanding", "general"];
        };
        private _uniformSide = nil;
        if (_isZombie && random 1 < 0.7) then {
            private _uniformList = if (random 1 < 0.7) then { duws_blufor_uniforms } else { duws_opfor_uniforms };
            if (count _uniformList > 0) then {
                private _uniform = selectRandom _uniformList;
                _unit forceAddUniform _uniform;
                _uniformSide = if (_uniformList isEqualTo duws_blufor_uniforms) then { "BLU" } else { "OPF" };
            };
        };
        if (random 1 < 0.5) then {
            private _helmet = "";
            if (!isNil "_uniformSide") then {
                private _helmetList = if (_uniformSide == "BLU") then { duws_blufor_helmets } else { duws_opfor_helmets };
                if (count _helmetList > 0) then { _helmet = selectRandom _helmetList; };
            } else {
                if (count duws_all_helmets > 0) then { _helmet = selectRandom duws_all_helmets; };
            };
            if (_helmet != "") then { _unit addHeadgear _helmet; };
        };
        if (random 1 < 0.7) then {
            private _vest = "";
            if (!isNil "_uniformSide") then {
                private _vestList = if (_uniformSide == "BLU") then { duws_blufor_vests } else { duws_opfor_vests };
                if (count _vestList > 0) then { _vest = selectRandom _vestList; };
            } else {
                if (count duws_all_vests > 0) then { _vest = selectRandom duws_all_vests; };
            };
            if (_vest != "") then { _unit addVest _vest; };
        };
    };

    // The whole horde goes outdoors. A zombie standing in a kitchen is one the player never meets,
    // and the mode is about being closed on in the open.
    private _maxOutdoorDist = _triggerRadius * 0.8;
    private _outdoorRange = 100 min _maxOutdoorDist;

    private _recruitableTypes = ["C_man_p_beggar_F","C_Man_casual_1_F","C_Man_casual_3_F","C_Man_casual_8_F","C_Man_casual_6_v2_F","C_Man_casual_2_F","C_Man_UtilityWorker_01_F","C_Man_Fisherman_01_F","C_Man_casual_2_F","C_Man_p_shorts_1_F","C_Man_w_worker_F"];
    private _zombieTypes = _civArray select { !(_x in _recruitableTypes) };
    if (_zombieTypes isEqualTo []) then { _zombieTypes = _civArray; };

    private _groups = [];
    private _civToSpawn = round (_spawnCount * 0.2);
    if (_civToSpawn < 1 && _spawnCount > 0) then { _civToSpawn = 1; };

    // Nothing to do on a civilian death here: RAVAGE registers no town reputation, so there is no
    // standing for killing one to cost. fnc_civ_spawnUnit reads this for every unit it creates and
    // would throw on a nil, so the empty handler has to exist.
    missionNamespace setVariable ["CIV_KILLED_HANDLER", {}];

    // The budget goes into the buildings nearest one anchor rather than across the whole disc. A
    // town's radius grows with its building count, so a fixed crowd spread over the disc made the
    // big towns the empty ones -- the same people over three times the ground. Clustering on a
    // fixed number of buildings instead lets the dense town pack them onto a street corner while
    // the sparse one strings them across a valley, which is the difference the setting exists to
    // express. Anchored on the centre for the first fill, because the trigger fires at the disc
    // edge with the player walking inward; the recycle pass re-anchors on where they end up.
    // Ranked by index rather than by the building itself: sort compares element by element, and
    // two buildings at an identical distance would leave it comparing objects.
    private _ranked = [];
    { _ranked pushBack [_x distance2D _centerPos, _forEachIndex] } forEach _usableBuildings;
    _ranked sort true;
    private _cluster = (_ranked select [0, CLUSTER_BUILDINGS]) apply { _usableBuildings select (_x select 1) };

    for "_i" from 1 to _spawnCount do {
        // selectRandom returns nil on an empty list, which the isNull below cannot be asked about.
        private _building = if (_cluster isEqualTo []) then { objNull } else { selectRandom _cluster };
        private _pos = [0,0,0];
        if (isNull _building) then {
            _pos = [_centerPos, 10, _maxOutdoorDist, 3, 0, 0.5, 0] call BIS_fnc_findSafePos;
            if (_pos isEqualTo [0,0,0]) then { _pos = _centerPos; };
        } else {
            _pos = [_building, 5, _outdoorRange, 3, 0, 0.3, 0] call BIS_fnc_findSafePos;
            if (_pos isEqualTo [0,0,0]) then { _pos = getPos _building; };
        };

        private _isZombie = _i > _civToSpawn;
        private _unitType = selectRandom ([_recruitableTypes, _zombieTypes] select _isZombie);

        private _unit = [_locIndex, _pos, _unitType, _isZombie] call fnc_civ_spawnUnit;
        if (!isNull _unit) then { _groups pushBack (group _unit) };
        sleep 0.2;
    };

    [localize "STR_DUWS_T_OVERLORD", ([localize "STR_DUWS_T_civpopR"] call fnc_cs)] remoteExec ["fnc_duws_dialogue", 0];
    sleep 2;
    ["biohazard", [localize "STR_DUWS_T_civrescuetitle", localize "STR_DUWS_T_civrescue"]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];

    // Patrol targets come from the cluster, not the whole town: waypoints drawn across the full
    // disc would walk the crowd straight back out of the area it was concentrated into.
    [_groups, _cluster] spawn fnc_civ_wp_Tomata;

    private _players = call BIS_fnc_listPlayers;
    {
        private _group = _x;
        while {(count (waypoints _group)) > 0} do { deleteWaypoint ((waypoints _group) select 0); };
        _group setBehaviour "COMBAT";
        _group setCombatMode "RED";
        _group setFormation "WEDGE";
        { { if (side _x == WEST) then { _unit reveal [_x, 4]; }; } forEach units _group; } forEach _players;
        if (count _players > 0) then {
            private _groupPos = getPos (leader _group);
            private _nearestPlayer = _players select 0;
            private _minDist = _groupPos distance _nearestPlayer;
            { private _dist = _groupPos distance _x; if (_dist < _minDist) then { _minDist = _dist; _nearestPlayer = _x; }; } forEach _players;
            private _wp = _group addWaypoint [getPos _nearestPlayer, 0];
            _wp setWaypointType "SAD";
            _wp setWaypointCompletionRadius 50;
            _wp setWaypointTimeout [10, 20, 30];
            private _wpCycle = _group addWaypoint [getPos _nearestPlayer, 100];
            _wpCycle setWaypointType "CYCLE";
        };
    } forEach _groups;

    private _groupList = missionNamespace getVariable [format ["civ_groups_%1", _locIndex], []];
    _groupList append _groups;
    missionNamespace setVariable [format ["civ_groups_%1", _locIndex], _groupList];
    if (duws_log_level >= 4) then { ["DEBUG", "CIV", format ["[Spawn] Spawned %1 civilians at location %2 (target population %3)", count _groups, _locIndex, _targetPop]] call fnc_log; };

    missionNamespace setVariable [_spawningKey, false];
    if (duws_log_level >= 4) then { ["DEBUG", "CIV", format ["[Spawn] Spawning flag cleared for location %1", _locIndex]] call fnc_log; };

    // Released here rather than at cleanup. The lock only serialises the spawn burst; holding it
    // for the whole occupancy meant a second town could not fill until the 10-minute wait in the
    // gate expired, so a co-op pair splitting between two towns left one of them empty. The live
    // count is bounded by fnc_civ_liveTarget now, which is what the lock was standing in for.
    [_locIndex] call fnc_civ_mode_releaseLock;

    [_locIndex, _centerPos, _triggerRadius] spawn {
        params ["_locIndex", "_centerPos", "_triggerRadius"];
        private _threadVar = format ["civ_monitor_%1", _locIndex];
        missionNamespace setVariable [_threadVar, false];
        sleep 1;
        missionNamespace setVariable [_threadVar, true];
        private _noPlayerCount = 0;
        // One quiet tick arms the cleanup, whose own grace period makes up the rest of the minute
        // between the players leaving and the town emptying. Recycling lands every third tick.
        private _maxNoPlayer = 1;
        private _pass = 0;
        while {missionNamespace getVariable [_threadVar, false]} do {
            sleep 30;
            if (!(missionNamespace getVariable [format ["civ_spawned_%1", _locIndex], false])) exitWith {
                missionNamespace setVariable [_threadVar, false];
            };
            private _playersInArea = allPlayers select { _x distance _centerPos < _triggerRadius };
            if (count _playersInArea == 0) then {
                _noPlayerCount = _noPlayerCount + 1;
                // Armed once, not once per tick: the cleanup owns its own grace period, and this
                // thread stays alive through it so a player who walks back in resumes recycling.
                if (_noPlayerCount >= _maxNoPlayer
                    && {!(missionNamespace getVariable [format ["civ_pending_cleanup_%1", _locIndex], false])}) then {
                    [_locIndex, "cleanup"] spawn fnc_civ_handler_ravage;
                };
            } else {
                _noPlayerCount = 0;
                _pass = _pass + 1;
                if (_pass % 3 == 0) then { [_locIndex] call fnc_civ_recycle };
            };
        };
    };
};
