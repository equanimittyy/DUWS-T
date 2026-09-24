// Locality: server, [] call'd at load. A Patrol's Value: the need on the ground a unit sweeps, weighted by how long
// that ground has gone unseen (opcom_plan.md §Value). Read from the pick's unscheduled pass, so nothing may suspend.
if (!isServer) exitWith {};

DUWS_fnc_opcom_stalenessAt = {
    params ["_c"];
    ((DUWS_opcom_tick - (DUWS_opcom_grid_seen select _c)) / OPCOM_BELIEF_EXPIRE) min 1
};

// The cells a patrol sweeps on the way: every cell within its K of the straight line it walks. The line, not the route,
// for the reason the delay discount measures straight: no candidate may plan a route inside the pick's pass.
DUWS_fnc_opcom_patrolCells = {
    params ["_from", "_to", "_k"];
    private _steps = (ceil ((_from distance2D _to) / (OPCOM_GRID_CELL / 2))) max 1;
    private _line = [];
    for "_i" from 0 to _steps do {
        private _f = _i / _steps;
        _line pushBackUnique ([[(_from select 0) + ((_to select 0) - (_from select 0)) * _f,
            (_from select 1) + ((_to select 1) - (_from select 1)) * _f, 0]] call DUWS_fnc_opcom_w2c);
    };
    private _cells = [];
    {
        { _cells pushBackUnique _x } forEach ([_x, _k] call DUWS_fnc_opcom_blockCells);
    } forEach _line;
    _cells
};

// The share keeps Patrol under the ground it sweeps: a patrol takes and protects nothing itself. The threat scale is
// the caller's, being the unit's and not the line's.
DUWS_fnc_opcom_patrolValue = {
    params ["_from", "_to", "_k"];
    private _sum = 0;
    {
        _sum = _sum + ([_x] call DUWS_fnc_opcom_needAt) * ([_x] call DUWS_fnc_opcom_stalenessAt);
    } forEach ([_from, _to, _k] call DUWS_fnc_opcom_patrolCells);
    _sum * OPCOM_PATROL_SHARE
};

// The two axes the kinds scale apart on: a recon is worth the reach of its certain bubble, a combatant only the
// narrower ground it can fight over, scaled by the threat it walks with. Cost already prices the force staked, so
// unscaled it would leave every patrol to the cheapest infantry and the hulls parked.
DUWS_fnc_opcom_patrolReach = {
    params ["_flags", "_moveType"];
    if ("recon" in _flags) then {
        OPCOM_RECON_K getOrDefault [_moveType, 1]
    } else {
        DUWS_opcom_streamK getOrDefault [_moveType, 1]
    }
};

DUWS_fnc_opcom_patrolScale = {
    params ["_flags", "_force"];
    if ("recon" in _flags) then { 1 } else { _force / OPCOM_PATROL_FORCE_REF }
};
