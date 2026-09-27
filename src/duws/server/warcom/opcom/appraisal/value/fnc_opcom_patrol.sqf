// Locality: server, [] call'd at load. A Patrol's Value: the need on the ground a unit sweeps, weighted by how long
// that ground has gone unseen (opcom_plan.md §Value). Read from the pick's unscheduled pass, so nothing may suspend.
if (!isServer) exitWith {};

DUWS_fnc_opcom_stalenessAt = {
    params ["_c"];
    ((DUWS_opcom_tick - (DUWS_opcom_grid_seen select _c)) / OPCOM_BELIEF_EXPIRE) min 1
};

// The mean staleness of the 3x3 block about _pos, the block P(win) and the muster bars read.
DUWS_fnc_opcom_blockStaleness = {
    params ["_pos"];
    private _cells = [[_pos] call DUWS_fnc_opcom_w2c, 1] call DUWS_fnc_opcom_blockCells;
    private _sum = 0;
    { _sum = _sum + ([_x] call DUWS_fnc_opcom_stalenessAt) } forEach _cells;
    _sum / ((count _cells) max 1)
};

// The cells a patrol sweeps on the way: every cell within its K of the straight line it walks. The line, not the route,
// for the reason the delay discount measures straight: no candidate may plan a route inside the pick's pass.
DUWS_fnc_opcom_patrolCells = {
    params ["_from", "_to", "_k"];
    private _w = DUWS_opcom_grid_w;
    DUWS_opcom_box params ["_minCx", "_minCy", "_maxCx", "_maxCy"];
    private _steps = (ceil ((_from distance2D _to) / (OPCOM_GRID_CELL / 2))) max 1;
    // A half-cell step moves the line at most one cell, so its rows run unbroken and its cells in each row form one
    // span. The band K about it is then one span a row, built without a per-cell dedupe.
    private _rows = [];
    private _lo = [];
    private _hi = [];
    for "_i" from 0 to _steps do {
        private _f = _i / _steps;
        private _c = [[(_from select 0) + ((_to select 0) - (_from select 0)) * _f,
            (_from select 1) + ((_to select 1) - (_from select 1)) * _f, 0]] call DUWS_fnc_opcom_w2c;
        private _cx = _c mod _w;
        private _cy = floor (_c / _w);
        private _j = count _rows - 1;
        if (_j < 0 || {(_rows select _j) != _cy}) then {
            _rows pushBack _cy;
            _lo pushBack _cx;
            _hi pushBack _cx;
        } else {
            _lo set [_j, (_lo select _j) min _cx];
            _hi set [_j, (_hi select _j) max _cx];
        };
    };
    private _y0 = _rows select 0;
    private _yN = _rows select (count _rows - 1);
    private _dir = [1, -1] select (_yN < _y0);
    private _cells = [];
    for "_cy" from (((_y0 min _yN) - _k) max _minCy) to (((_y0 max _yN) + _k) min _maxCy) do {
        private _a = 1e9;
        private _b = -1e9;
        for "_r" from ((_cy - _k) max (_y0 min _yN)) to ((_cy + _k) min (_y0 max _yN)) do {
            private _j = (_r - _y0) * _dir;
            _a = _a min (_lo select _j);
            _b = _b max (_hi select _j);
        };
        for "_cx" from ((_a - _k) max _minCx) to ((_b + _k) min _maxCx) do { _cells pushBack (_cy * _w + _cx) };
    };
    _cells
};

// The patrol lines of one pick cross the same cells many times over.
DUWS_fnc_opcom_sweepWeights = {
    ["sweepWeights", {
        private _out = [];
        { _out pushBack (([_forEachIndex] call DUWS_fnc_opcom_needAt) * ([_forEachIndex] call DUWS_fnc_opcom_stalenessAt)) } forEach DUWS_opcom_grid_land;
        _out
    }] call DUWS_fnc_opcom_tickCached
};

// The share keeps Patrol under the ground it sweeps: a patrol takes and protects nothing itself. The threat scale is
// the caller's, being the unit's and not the line's.
DUWS_fnc_opcom_patrolValue = {
    params ["_from", "_to", "_k"];
    private _weights = call DUWS_fnc_opcom_sweepWeights;
    private _sum = 0;
    { _sum = _sum + (_weights select _x) } forEach ([_from, _to, _k] call DUWS_fnc_opcom_patrolCells);
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
