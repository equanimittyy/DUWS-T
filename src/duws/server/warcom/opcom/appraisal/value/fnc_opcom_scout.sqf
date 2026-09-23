// Locality: server, [] call'd at load. A Scout's Value: the need it reveals along its route, weighted by how long that
// ground has gone unseen (opcom_plan.md §Value). Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

DUWS_fnc_opcom_stalenessAt = {
    params ["_c"];
    ((DUWS_opcom_tick - (DUWS_opcom_grid_seen select _c)) / OPCOM_BELIEF_EXPIRE) min 1
};

// The cells a recon sweeps on the way: every cell within its K of the straight line it walks. The line, not the route,
// for the reason the delay discount measures straight: no candidate may plan a route inside the pick's pass.
DUWS_fnc_opcom_scoutCells = {
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

// The share keeps Scout under the ground it reveals: scouting takes and protects nothing itself.
DUWS_fnc_opcom_scoutValue = {
    params ["_from", "_to", "_k"];
    private _sum = 0;
    {
        _sum = _sum + ([_x] call DUWS_fnc_opcom_needAt) * ([_x] call DUWS_fnc_opcom_stalenessAt);
    } forEach ([_from, _to, _k] call DUWS_fnc_opcom_scoutCells);
    _sum * OPCOM_SCOUT_SHARE
};
