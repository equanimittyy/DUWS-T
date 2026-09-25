// Locality: server, [] call'd at load. The intercept order: follow a belief row, look for certain on arrival,
// then hunt what the look found or guard.
if (!isServer) exitWith {};

// The interceptor's own arrival look: a hunt has to find a group that moved off the fix it was sent to, which no
// other order needs. A recon's sweep bought at one point instead of carried along a route (fnc_opcom_patrol_sense):
// every BLUFOR group in reach is stamped for certain, the reach reads swept-clear (fnc_opcom_cover_stamp) and belief
// the look disproves clears (fnc_opcom_cover_clear). -> the closest group's netId, or "".
DUWS_fnc_opcom_interceptLook = {
    if (isNil "DUWS_opcom_grid_w") exitWith { "" };
    params ["_point"];
    [_point, OPCOM_INTERCEPT_K] call fnc_opcom_cover_stamp;
    private _best = "";
    private _bd = 1e12;
    {
        private _l = [_x] call DUWS_fnc_opcom_sightLead;
        if (!isNull _l) then {
            private _lp = getPosASL _l;
            if (([_lp, _point] call DUWS_fnc_opcom_cellDist) <= OPCOM_INTERCEPT_K) then {
                [netId _x, [_lp select 0, _lp select 1, 0], [_x] call DUWS_fnc_opcom_sightStr] call fnc_opcom_belief_upsert;
                private _d = _point distance2D _lp;
                if (_d < _bd) then { _bd = _d; _best = netId _x };
            };
        };
    } forEach (allGroups select { side _x == west });
    [_point, OPCOM_INTERCEPT_K] call fnc_opcom_cover_clear;
    _best
};

// Re-plans only once the row's believed position moves past one cell: each re-plan is an A* search. A decayed row
// leaves the last position read.
DUWS_fnc_opcom_interceptFollow = {
    params ["_t", "_live", ["_force", false]];
    private _i = DUWS_opcom_belief_key findIf { _x isEqualTo (_t get "interceptKey") };
    if (_i < 0) exitWith {};
    private _bp = DUWS_opcom_belief_pos select _i;
    if (!_force && {([_bp, _t get "target"] call DUWS_fnc_opcom_cellDist) <= 1}) exitWith {};
    _t set ["target", +_bp];
    ([_t get "pos", _bp, _t get "moveType", _t getOrDefault ["lambda", 0]] call fnc_opcom_route) params ["_pts", "_mode"];
    _t set ["route", _pts]; _t set ["routeMode", _mode]; _t set ["leg", 0];
    if (_live) then { [_t] call DUWS_fnc_opcom_reOrderLive };
};

DUWS_fnc_opcom_interceptGuard = {
    params ["_t", "_pos", "_grp"];
    ["INFO", "OPCOM", format ["intercept: tasking %1 guards at %2, nothing within %3 cells", _t get "id", _pos apply { round _x }, OPCOM_INTERCEPT_K]] call fnc_log;
    _t set ["order", "guard"]; _t set ["target", _pos]; _t set ["route", []]; _t set ["interceptKey", ""];
    if (!isNull _grp) then { [_grp, "guard", _pos] call DUWS_fnc_opcom_applyOrder };
};

// Arrived where it was sent: it hunts the closest group the arrival look found, or guards. -> true if it guarded.
DUWS_fnc_opcom_interceptArrive = {
    params ["_t", "_pos", "_grp"];
    private _next = [_pos] call DUWS_fnc_opcom_interceptLook;
    if (_next isEqualTo "") exitWith { [_t, _pos, _grp] call DUWS_fnc_opcom_interceptGuard; true };
    private _switched = _next isNotEqualTo (_t get "interceptKey");
    if (_switched) then {
        ["INFO", "OPCOM", format ["intercept: tasking %1 switches to %2", _t get "id", _next]] call fnc_log;
        _t set ["interceptKey", _next];
    };
    // The follow's one-cell tolerance leaves the waypoint up to 1 km off a fix taken at arm's length.
    // Movement-gated: re-issuing the SAD waypoint every tick restarts the AI's search.
    private _i = DUWS_opcom_belief_key findIf { _x isEqualTo _next };
    private _moved = _i >= 0 && {((DUWS_opcom_belief_pos select _i) distance2D (_t get "target")) > OPCOM_MOVE_ARRIVE};
    if (_switched || _moved) then { [_t, !isNull _grp, true] call DUWS_fnc_opcom_interceptFollow };
    false
};

DUWS_fnc_opcom_refreshIntercept = {
    params ["_t", "_live"];
    [_t, _live] call DUWS_fnc_opcom_interceptFollow;
    if (_live) exitWith { "" };
    [_t] call DUWS_fnc_opcom_advance
};

DUWS_fnc_opcom_stepIntercept = {
    params ["_t", "_ctx"];
    _ctx params ["_pos", "_grp"];
    if (([_pos, _t get "target"] call DUWS_fnc_opcom_cellDist) != 0) exitWith { false };
    [_t, _pos, _grp] call DUWS_fnc_opcom_interceptArrive;
    false
};
