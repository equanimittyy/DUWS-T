// Locality: server, [] call'd at load. Streaming helpers: de-virtualise a tasking into a live A3 group near a
// player, stow it back to a world point when it leaves. A live group is steered by re-issuing its order; a
// transportable unit whose route crosses water is walked only to the near shore, where the ferry takes over
// (fnc_opcom_ferry).
if (!isServer) exitWith {};

// Cleared first so a re-spawn inherits no stale waypoint. (Waypoints take only on a server-local group.) _via: MOVE
// points walked before the order's own waypoint.
DUWS_fnc_opcom_applyOrder = {
    params ["_grp", "_order", "_target", ["_via", []]];
    while {count waypoints _grp > 0} do { deleteWaypoint ((waypoints _grp) select 0) };
    { (_grp addWaypoint [_x, 0]) setWaypointType "MOVE" } forEach _via;
    switch (_order) do {
        case "capture";
        case "intercept": {
            _grp setBehaviour "AWARE"; _grp setCombatMode "RED"; _grp setSpeedMode "FULL";
            (_grp addWaypoint [_target, 0]) setWaypointType "SAD";
        };
        // BLUE keeps the courier out of fights; arrival/delete is the tasking step's job.
        case "errand": {
            _grp setBehaviour "AWARE"; _grp setCombatMode "BLUE"; _grp setSpeedMode "NORMAL";
            (_grp addWaypoint [_target, 0]) setWaypointType "MOVE";
        };
        // The ferry stages ask for "move" by hand to march a hull or a rider to a shore, whatever order it holds.
        case "move";
        case "patrol";
        case "probe";
        case "return": {
            _grp setBehaviour "AWARE"; _grp setCombatMode "YELLOW"; _grp setSpeedMode "NORMAL";
            (_grp addWaypoint [_target, 0]) setWaypointType "MOVE";
        };
        default {
            _grp setBehaviour "AWARE"; _grp setCombatMode "YELLOW"; _grp setSpeedMode "NORMAL";
        };
    };
};

// -> the rest of a threat-bent route as MOVE points a cell apart, [] at lambda 0. One waypoint at the target lets the
// engine path a live group straight through what the route went around; a cell apart keeps a road route's dense
// polyline to a handful of waypoints.
DUWS_fnc_opcom_routeVia = {
    params ["_t", "_from"];
    private _route = _t get "route";
    if ((_t getOrDefault ["lambda", 0]) <= 0 || {count _route < 2}) exitWith { [] };
    private _near = 0;
    { if ((_x distance2D _from) < ((_route select _near) distance2D _from)) then { _near = _forEachIndex } } forEach _route;
    private _via = [];
    private _last = _from;
    for "_i" from (_near + 1) to (count _route - 2) do {
        private _p = _route select _i;
        if ((_p distance2D _last) >= OPCOM_GRID_CELL) then { _via pushBack _p; _last = _p };
    };
    _via
};

// Near-shore staging point of a route that crosses water: [_crosses, _stage], _stage the last land point before
// the first water leg. Shared by the live re-order and the ferry request so the two agree on where the shore is.
DUWS_fnc_opcom_shoreStage = {
    params ["_t", "_from"];
    private _stage = _from;
    private _crosses = false;
    { if ([_x] call DUWS_fnc_opcom_isWaterPt) exitWith { _crosses = true }; _stage = _x } forEach (_t get "route");
    [_crosses, _stage]
};

// Push a re-order onto a live group. A transportable unit whose route crosses water drives only to the near shore,
// where the tasking step borrows a ferry.
DUWS_fnc_opcom_reOrderLive = {
    params ["_t"];
    private _grp = groupFromNetId (_t get "grp");
    if (isNull _grp) exitWith {};
    // A bound ferry rider never marches -- the transport owns it. Pin it where it stands (its shore pickup) with a
    // HOLD, or it walks its destination route on past the shore while the lift comes in.
    if ((_t getOrDefault ["ridingOn", -1]) >= 0) exitWith {
        private _here = getPosASL (leader _grp);
        [_grp, "move", _here] call DUWS_fnc_opcom_applyOrder;
        (_grp addWaypoint [_here, 0]) setWaypointType "HOLD";
    };
    private _order = _t get "order";
    if ("transportable" in (_t get "flags") && {_order isNotEqualTo "guard"}) then {
        ([_t, getPosASL (leader _grp)] call DUWS_fnc_opcom_shoreStage) params ["_crosses", "_stage"];
        if (_crosses) exitWith {
            [_grp, "move", _stage] call DUWS_fnc_opcom_applyOrder;
            // A lone MOVE completes and the group drifts off; HOLD pins it at the shore until the ferry clears it.
            (_grp addWaypoint [_stage, 0]) setWaypointType "HOLD";
        };
    };
    [_grp, _order, _t get "target", [_t, getPosASL (leader _grp)] call DUWS_fnc_opcom_routeVia] call DUWS_fnc_opcom_applyOrder;
};

// OPCOM's own spawn: air must spawn flying at the tasking's point, not flown in from off-map like the zone spawner.
DUWS_fnc_opcom_spawnComp = {
    params ["_token", "_pos", ["_class", ""]];
    if !(([_token] call DUWS_fnc_teamRow) isEqualTo []) exitWith {
        private _g = [_token, _pos, 100, "none", _pos] call fnc_spawn_team;
        // Posture "none" drops the team on one point; scatter <20 m so it still reads as one group in the stream radius.
        { _x setPos (_pos getPos [4 + random 12, random 360]) } forEach units _g;
        _g
    };
    // Empty only for a record raised before spawnClass existed (hot-reloaded campaign): draw fresh.
    if (_class isEqualTo "") then { _class = [_token] call DUWS_fnc_tokenClass };
    if (_class isEqualTo "") exitWith {
        ["WARN", "OPCOM", format ["spawn: token %1 resolves to no class for this faction", _token]] call fnc_log;
        grpNull
    };
    if !(_class isKindOf "Air") exitWith {
        // pos is banked ASL (grid frame); spawnVehicle reads a 3D z as ATL, so pass 2D or the hull floats.
        private _g = [_pos select 0, _pos select 1];
        private _grp = [_class, _g, 100, "none", _g] call fnc_spawn_vehicle;
        // A supplied spawn point skips the clearance search, so a leg ending in a building or on water builds no hull.
        // findEmptyPosition, not BIS_fnc_findSafePos: it answers [] on failure rather than a far random point.
        if (isNull _grp) then {
            private _clear = _g findEmptyPosition [0, OPCOM_DEVIRT_CLEAR_R, _class];
            if (_clear isNotEqualTo []) then {
                _grp = [_class, _g, 100, "none", [_clear select 0, _clear select 1]] call fnc_spawn_vehicle;
            };
        };
        _grp
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

// Spawn the composition at its world point, matched to stored strength, and order it. One hull/team, never a column.
DUWS_fnc_opcom_deVirt = {
    params ["_t"];
    private _token = (_t get "comp") param [0, ""];
    private _pos = _t get "pos";
    private _grp = [_token, _pos, _t getOrDefault ["spawnClass", ""]] call DUWS_fnc_opcom_spawnComp;
    if (isNull _grp) exitWith {
        ["ERROR", "OPCOM", format ["de-virt spawn failed for tasking %1 token %2", _t get "id", _token]] call fnc_log;
        false
    };
    private _full = _t get "fullForce";
    if (_full > 0) then { [_grp, (_t get "effForce") / _full] call DUWS_fnc_opcom_matchStrength };
    private _tgt = _t get "target";
    if (_tgt isNotEqualTo []) then {
        private _dir = _pos getDir _tgt;
        _grp setFormDir _dir;
        {
            private _v = vehicle _x;
            // Model-space velocity carried across the turn: a hull spawned flying keeps its airspeed on the new heading.
            private _vel = velocityModelSpace _v;
            _v setDir _dir;
            _v setVelocityModelSpace _vel;
        } forEach units _grp;
    };
    _t set ["grp", netId _grp];
    _t set ["status", "moving"];
    _t set ["farTicks", 0];   // fresh live period: a re-used record must not carry a spent stow debounce
    _t set ["nearTicks", 0];
    // reOrderLive (not applyOrder): a transportable unit spawning mid-crossing walks only to the near shore.
    [_t] call DUWS_fnc_opcom_reOrderLive;
    true
};

// Deletes the hulls the men sit in too: deleting only the crew leaves an empty vehicle standing.
DUWS_fnc_opcom_despawn = {
    params ["_grp"];
    private _hulls = [];
    { private _v = vehicle _x; if (_v != _x && {!(_v in _hulls)}) then { _hulls pushBack _v } } forEach (units _grp);
    { deleteVehicle _x } forEach (units _grp);
    { deleteVehicle _x } forEach _hulls;
    deleteGroup _grp;
};

// effForceLive counts only the living, so a wiped group weighs 0 and drops out the same tick.
DUWS_fnc_opcom_bookkeep = {
    {
        private _grp = groupFromNetId (_x get "grp");
        // A ferry rider is strength-frozen from board order to full dismount: its live count is falling only
        // because it board-despawns man by man, so a live read here would bleed the snapshot toward zero.
        if (!isNull _grp && {!(_x getOrDefault ["ferryFrozen", false])}) then {
            _x set ["pos", getPosASL (leader _grp)];
            _x set ["effForce", [_grp] call DUWS_fnc_opcom_effForceLive];
        } else {
            // Embarked rider (no group of its own): track its point to the live hull it rides, so the grid
            // reads its frozen force at the hull's spot, not a tick behind the transport. effForce stays frozen.
            if ((_x getOrDefault ["ridingOn", -1]) >= 0) then {
                private _tr = [_x get "ridingOn"] call DUWS_fnc_opcom_byId;
                if (!isNil "_tr" && {_tr getOrDefault ["embarked", false]}) then {
                    private _tg = groupFromNetId (_tr get "grp");
                    if (!isNull _tg) then { _x set ["pos", getPosASL (leader _tg)] };
                };
            };
        };
    } forEach DUWS_opcom_taskings;
};

// Bank surviving strength, take the leader's position, delete the group and its hulls; clear the route to replan.
DUWS_fnc_opcom_reVirt = {
    params ["_t"];
    private _grp = groupFromNetId (_t get "grp");
    if (isNull _grp || {count units _grp == 0}) exitWith {
        _t set ["grp", ""]; _t set ["status", "virtual"];
    };
    _t set ["effForce", [_grp] call DUWS_fnc_opcom_effForceLive];
    _t set ["pos", getPosASL (leader _grp)];
    [_grp] call DUWS_fnc_opcom_despawn;
    _t set ["grp", ""];
    _t set ["route", []];
    _t set ["status", "virtual"];
};
