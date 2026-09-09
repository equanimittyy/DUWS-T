// Locality: server, [] call'd at load to define the streaming helpers. The mobile analogue of hardpoint
// streaming: a virtualised tasking de-virtualises into a live A3 group near a player and stows back to a
// world point once it leaves. OPCOM cannot steer a live group -- it runs the order set at spawn until it
// re-virtualises (docs/plans/opcom/opcom_plan.md) -- so that order carries the whole intent on its own.
if (!isServer) exitWith {};

// The closest native order to a tasking, set at spawn. Cleared first so a re-spawn inherits no stale
// waypoint. (Waypoints/behaviour take only on a server-local group, which every spawn here is.)
DUWS_fnc_opcom_applyOrder = {
    params ["_grp", "_order", "_target"];
    while {count waypoints _grp > 0} do { deleteWaypoint ((waypoints _grp) select 0) };
    switch (_order) do {
        case "assault": {
            _grp setBehaviour "AWARE"; _grp setCombatMode "RED";
            (_grp addWaypoint [_target, 0]) setWaypointType "SAD";
        };
        case "supply": {
            // Drive to the drop in SAFE; arrival (deletion + success) is handled by the tasking step.
            _grp setBehaviour "SAFE"; _grp setCombatMode "BLUE";
            (_grp addWaypoint [_target, 0]) setWaypointType "MOVE";
        };
        case "move": {
            _grp setBehaviour "SAFE";
            (_grp addWaypoint [_target, 0]) setWaypointType "MOVE";
        };
        default {   // guard, and any resting unit forced live: hold ground where it stands
            _grp setBehaviour "SAFE"; _grp setCombatMode "YELLOW";
        };
    };
};

// OPCOM's own de-virt spawn, so air spawns flying at the tasking's point: the zone spawner flies air in from
// off-map, wrong for a stowed unit resuming where it stood. grpNull leaves no orphan hull.
DUWS_fnc_opcom_spawnComp = {
    params ["_token", "_pos"];
    if !(([_token] call DUWS_fnc_teamRow) isEqualTo []) exitWith {
        [_token, _pos, 100, "none", _pos] call fnc_spawn_team
    };
    private _class = [_token] call DUWS_fnc_tokenClass;
    if (_class isEqualTo "") exitWith {
        ["WARN", "OPCOM", format ["spawn: token %1 resolves to no class for this faction", _token]] call fnc_log;
        grpNull
    };
    if !(_class isKindOf "Air") exitWith {
        [_class, _pos, 100, "none", _pos] call fnc_spawn_vehicle
    };
    private _created = [[_pos select 0, _pos select 1, OPCOM_AIR_SPAWN_ALT], 0, _class, EAST] call BIS_fnc_spawnVehicle;
    _created params ["_veh", "_crew", "_grp"];
    if (isNull _grp || {_crew isEqualTo []}) exitWith {
        if (!isNull _veh) then { deleteVehicle _veh };
        ["ERROR", "OPCOM", format ["air spawn failed for token %1 (%2)", _token, _class]] call fnc_log;
        grpNull
    };
    _grp deleteGroupWhenEmpty true;
    _veh engineOn true;
    _veh flyInHeight OPCOM_AIR_SPAWN_ALT;
    private _skill = missionNamespace getVariable ["opfor_ai_skill_random", opfor_ai_skill_random];
    {
        [_x] call fnc_addRandomLoot;
        // Crew's body-search faction identity; skip the BLUFOR files that dress their own pilots.
        if (!(("OPTRE" in BLUFOR_FactionFile_X) || {"HL2ECR" in BLUFOR_FactionFile_X} || {"TIOW" in BLUFOR_FactionFile_X})) then {
            _x forceAddUniform "U_I_pilotCoveralls";
        };
        _x setSkill _skill;
    } forEach _crew;
    _grp
};

// Spawn the composition at its world point (DUWS_fnc_opcom_spawnComp), matched to stored strength, and give
// it its order; true on a live group. One hull/team per tasking, never a column.
DUWS_fnc_opcom_deVirt = {
    params ["_t"];
    private _token = (_t get "comp") param [0, ""];
    private _pos = _t get "pos";
    private _grp = [_token, _pos] call DUWS_fnc_opcom_spawnComp;
    if (isNull _grp) exitWith {
        ["ERROR", "OPCOM", format ["de-virt spawn failed for tasking %1 token %2", _t get "id", _token]] call fnc_log;
        false
    };
    private _full = _t get "fullForce";
    if (_full > 0) then { [_grp, (_t get "effForce") / _full] call DUWS_fnc_opcom_matchStrength };
    _t set ["grp", netId _grp];
    _t set ["status", "moving"];
    _t set ["farTicks", 0];   // fresh live period: a re-used record must not carry a spent stow debounce
    [_grp, _t get "order", _t get "target"] call DUWS_fnc_opcom_applyOrder;
    true
};

// Stow a live group back to a world point: bank surviving strength, take the leader's position, delete the
// group and any hulls. Route is cleared so the next step replans from there. A dead group is the status
// read's job, not here.
DUWS_fnc_opcom_reVirt = {
    params ["_t"];
    private _grp = groupFromNetId (_t get "grp");
    if (isNull _grp || {count units _grp == 0}) exitWith {
        _t set ["grp", ""]; _t set ["status", "virtual"];
    };
    _t set ["effForce", [_grp] call DUWS_fnc_opcom_effForceLive];
    _t set ["pos", getPosASL (leader _grp)];
    private _hulls = [];
    { private _v = vehicle _x; if (_v != _x && {!(_v in _hulls)}) then { _hulls pushBack _v } } forEach (units _grp);
    { deleteVehicle _x } forEach (units _grp);
    { deleteVehicle _x } forEach _hulls;
    deleteGroup _grp;
    _t set ["grp", ""];
    _t set ["route", []];
    _t set ["status", "virtual"];
};
