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
    private _first = [];
    private _add = {
        params ["_p", "_type"];
        private _wp = _grp addWaypoint [_p, 0];
        _wp setWaypointType _type;
        if (_first isEqualTo []) then { _first = _wp };
    };
    { [_x, "MOVE"] call _add } forEach _via;
    switch (_order) do {
        case "capture";
        case "intercept": {
            _grp setBehaviour "AWARE"; _grp setCombatMode "RED"; _grp setSpeedMode "FULL";
            [_target, "SAD"] call _add;
        };
        // BLUE keeps the courier out of fights; arrival/delete is the tasking step's job.
        case "errand": {
            _grp setBehaviour "AWARE"; _grp setCombatMode "BLUE"; _grp setSpeedMode "NORMAL";
            [_target, "MOVE"] call _add;
        };
        // The ferry stages ask for "move" by hand to march a hull or a rider to a shore, whatever order it holds.
        case "move";
        case "patrol";
        case "probe";
        case "return": {
            _grp setBehaviour "AWARE"; _grp setCombatMode "YELLOW"; _grp setSpeedMode "NORMAL";
            [_target, "MOVE"] call _add;
        };
        default {
            _grp setBehaviour "AWARE"; _grp setCombatMode "YELLOW"; _grp setSpeedMode "NORMAL";
        };
    };
    // deleteWaypoint leaves currentWaypoint where it was, which can point past every new leg (arma_engine_gotchas.md).
    if (_first isNotEqualTo []) then { _grp setCurrentWaypoint _first };
};

// -> the rest of a bent route as MOVE points every OPCOM_GRID_CELL metres along it, [] when nothing bent it (lambda 0,
// nothing avoided). One waypoint at the target lets the engine path a live group straight through what the route went
// around; a fixed spacing keeps a road route's dense polyline to a handful of waypoints.
DUWS_fnc_opcom_routeVia = {
    params ["_t", "_from"];
    private _route = _t get "route";
    private _bent = (_t getOrDefault ["lambda", 0]) > 0 || {(_t getOrDefault ["avoid", []]) isNotEqualTo []};
    if (!_bent || {count _route < 2}) exitWith { [] };
    private _near = 0;
    { if ((_x distance2D _from) < ((_route select _near) distance2D _from)) then { _near = _forEachIndex } } forEach _route;
    private _via = [];
    private _last = _from;
    private _left = OPCOM_GRID_CELL;
    for "_i" from (_near + 1) to (count _route - 1) do {
        private _p = _route select _i;
        private _d = _last distance2D _p;
        // Strict: a point landing exactly on the target would stack a MOVE on the order's own waypoint.
        while {_d > _left} do {
            _last = _last getPos [_left, _last getDir _p];
            _via pushBack _last;
            _d = _d - _left;
            _left = OPCOM_GRID_CELL;
        };
        _left = _left - _d;
        _last = _p;
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

// -> [x, y] a de-virt may stand on, or [] for none this tick. The unit or a player can close several hundred metres
// over the de-virt debounce, so the spot is judged now, against every player. An aircraft, seen above any cover,
// keeps the whole sight range off. _class "" is a team.
DUWS_fnc_opcom_devirtSpot = {
    params ["_pos", "_class", "_dir", "_walk"];
    private _air = _class isKindOf "Air";
    private _boat = _class isKindOf "Ship";
    // A hull spawned into another detonates both.
    private _fits = switch (true) do {
        case (_air): { { true } };
        case (_class isEqualTo ""): { { !surfaceIsWater _this } };
        default { { (surfaceIsWater _this) isEqualTo _boat && {[_class, _this, _dir] call fnc_vehicle_spot_clear} } };
    };
    private _players = (call BIS_fnc_listPlayers) select { alive _x };
    private _floor = [OPCOM_DEVIRT_MIN_DIST, OPCOM_DEVIRT_SIGHT_RANGE] select _air;
    private _cands = [];
    for "_i" from 1 to 16 do { _cands pushBack (_pos getPos [random OPCOM_DEVIRT_SPREAD_R, random 360]) };
    _cands pushBack _pos;
    if (_walk > 0 && {_players isNotEqualTo []}) then {
        private _near = _players select 0;
        { if ((_x distance2D _pos) < (_near distance2D _pos)) then { _near = _x } } forEach _players;
        private _away = _near getDir _pos;
        for "_d" from 200 to _walk step 200 do {
            { _cands pushBack (_pos getPos [_d, _away + _x]) } forEach [0, 45, -45, 90, -90, 135, -135, 180];
        };
    };
    private _i = _cands findIf {
        private _p = _x;
        (_players findIf { (_x distance2D _p) < _floor }) < 0
        && {_p call _fits}
        && {_air || {(_players findIf { (_x distance2D _p) < OPCOM_DEVIRT_SIGHT_RANGE && {[_p, _x] call fnc_duws_posSeenBy} }) < 0}}
    };
    if (_i < 0) exitWith { [] };
    private _spot = _cands select _i;
    [_spot select 0, _spot select 1]
};

// OPCOM's own spawn, on the point it is handed: air must spawn flying there, not flown in from off-map like the zone spawner.
DUWS_fnc_opcom_spawnComp = {
    params ["_token", "_pos", "_class"];
    if !(([_token] call DUWS_fnc_teamRow) isEqualTo []) exitWith {
        private _g = [_token, _pos, 100, "none", _pos] call fnc_spawn_team;
        // Posture "none" drops the team on one point; scatter <20 m so it still reads as one group in the stream radius.
        { _x setPos (_pos getPos [4 + random 12, random 360]) } forEach units _g;
        _g
    };
    if (_class isEqualTo "") exitWith {
        ["WARN", "OPCOM", format ["spawn: token %1 resolves to no class for this faction", _token]] call fnc_log;
        grpNull
    };
    if !(_class isKindOf "Air") exitWith {
        // pos is banked ASL (grid frame); spawnVehicle reads a 3D z as ATL, so pass 2D or the hull floats.
        private _g = [_pos select 0, _pos select 1];
        [_class, _g, 100, "none", _g] call fnc_spawn_vehicle
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
// _spread false for a ferry drop, which must land on the point it is handed.
DUWS_fnc_opcom_deVirt = {
    params ["_t", ["_spread", true]];
    private _token = (_t get "comp") param [0, ""];
    private _pos = _t get "pos";
    private _tgt = _t get "target";
    private _dir = if (_tgt isEqualTo []) then { 0 } else { _pos getDir _tgt };
    private _class = "";
    if (([_token] call DUWS_fnc_teamRow) isEqualTo []) then {
        // Empty only for a record raised before spawnClass existed (hot-reloaded campaign): draw fresh.
        _class = _t getOrDefault ["spawnClass", ""];
        if (_class isEqualTo "") then { _class = [_token] call DUWS_fnc_tokenClass };
    };
    if (_spread) then {
        // A bound rider boards at its shore pickup, so it is never walked off it.
        private _walk = [OPCOM_DEVIRT_WALK, 0] select ((_t getOrDefault ["ridingOn", -1]) >= 0);
        private _spot = [_pos, _class, _dir, _walk] call DUWS_fnc_opcom_devirtSpot;
        _pos = if (_spot isEqualTo []) then { [] } else { [_spot select 0, _spot select 1, _pos select 2] };
    };
    // No clear spot: it stays virtual, and the stream stage retries next tick.
    if (_pos isEqualTo []) exitWith { false };
    private _grp = [_token, _pos, _class] call DUWS_fnc_opcom_spawnComp;
    if (isNull _grp) exitWith {
        ["ERROR", "OPCOM", format ["de-virt spawn failed for tasking %1 token %2", _t get "id", _token]] call fnc_log;
        false
    };
    private _full = _t get "fullForce";
    if (_full > 0) then { [_grp, (_t get "effForce") / _full] call DUWS_fnc_opcom_matchStrength };
    if (_tgt isNotEqualTo []) then {
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
