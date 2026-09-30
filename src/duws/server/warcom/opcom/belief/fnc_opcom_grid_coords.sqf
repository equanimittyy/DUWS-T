// Locality: server, executed at load by server_fnc_init ([] call compile) so it can define several
// functions. They load before the grid exists and read it at call time, so a caller guards on isNil "DUWS_opcom_grid_w".
if (!isServer) exitWith {};

DUWS_fnc_opcom_w2c = {
    params ["_pos"];
    private _w = DUWS_opcom_grid_w;
    // Clamp to the play box: a point outside it resolves to the nearest edge cell, keeping routed/streamed cells inside.
    DUWS_opcom_box params ["_minCx", "_minCy", "_maxCx", "_maxCy"];
    private _cx = (floor ((_pos select 0) / OPCOM_GRID_CELL)) max _minCx min _maxCx;
    private _cy = (floor ((_pos select 1) / OPCOM_GRID_CELL)) max _minCy min _maxCy;
    _cy * _w + _cx
};

DUWS_fnc_opcom_c2w = {
    params ["_ci"];
    private _w = DUWS_opcom_grid_w;
    [((_ci mod _w) + 0.5) * OPCOM_GRID_CELL, ((floor (_ci / _w)) + 0.5) * OPCOM_GRID_CELL, 0]
};

// Clipped to the play box, so a block at its edge holds fewer cells.
DUWS_fnc_opcom_blockCells = {
    params ["_c", "_k"];
    private _w = DUWS_opcom_grid_w;
    private _cx = _c mod _w;
    private _cy = floor (_c / _w);
    DUWS_opcom_box params ["_minCx", "_minCy", "_maxCx", "_maxCy"];
    private _out = [];
    for "_iy" from ((_cy - _k) max _minCy) to ((_cy + _k) min _maxCy) do {
        for "_ix" from ((_cx - _k) max _minCx) to ((_cx + _k) min _maxCx) do {
            _out pushBack (_iy * _w + _ix);
        };
    };
    _out
};

// OPCOM's certain sensors (recon, an OP burst) are blind in these cells: a sweep from cells away would find a base's
// garrison and expose the base (fnc_opcom_belief_upsert). Not the MHQ: a moving blind ring hides its riders.
DUWS_fnc_opcom_baseCells = {
    private _w = DUWS_opcom_grid_w;
    private _r = DUWS_base_keep_radius;
    private _out = [];
    {
        _x params ["_bx", "_by"];
        for "_cy" from (floor ((_by - _r) / OPCOM_GRID_CELL)) to (floor ((_by + _r) / OPCOM_GRID_CELL)) do {
            for "_cx" from (floor ((_bx - _r) / OPCOM_GRID_CELL)) to (floor ((_bx + _r) / OPCOM_GRID_CELL)) do {
                private _nearX = _bx max (_cx * OPCOM_GRID_CELL) min ((_cx + 1) * OPCOM_GRID_CELL);
                private _nearY = _by max (_cy * OPCOM_GRID_CELL) min ((_cy + 1) * OPCOM_GRID_CELL);
                if (([_bx, _by] distance2D [_nearX, _nearY]) < _r) then { _out pushBackUnique (_cy * _w + _cx) };
            };
        };
    } forEach (Array_of_FOBpos + [PosOfBLUHQ]);
    _out
};

DUWS_fnc_opcom_nearestWater = {
    params ["_pos"];
    private _best = _pos;
    private _bd = 1e12;
    {
        if (_x >= 0) then {
            private _c = [_forEachIndex] call DUWS_fnc_opcom_c2w;
            private _dd = _pos distance2D _c;
            if (_dd < _bd) then { _bd = _dd; _best = _c };
        };
    } forEach DUWS_opcom_grid_water;
    _best
};

// -> the landmass id of _pos's cell, -1 on water.
DUWS_fnc_opcom_massAt = {
    params ["_pos"];
    DUWS_opcom_grid_mass select ([_pos] call DUWS_fnc_opcom_w2c)
};

// Not w2c: it clamps an off-box point onto an edge cell and would read that cell's land.
DUWS_fnc_opcom_landAt = {
    params ["_pos"];
    private _cx = floor ((_pos select 0) / OPCOM_GRID_CELL);
    private _cy = floor ((_pos select 1) / OPCOM_GRID_CELL);
    DUWS_opcom_box params ["_minCx", "_minCy", "_maxCx", "_maxCy"];
    _cx >= _minCx && {_cx <= _maxCx} && {_cy >= _minCy} && {_cy <= _maxCy} && {DUWS_opcom_grid_land select (_cy * DUWS_opcom_grid_w + _cx)}
};
