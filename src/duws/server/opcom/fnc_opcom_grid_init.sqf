// Locality: server. Builds the influence-grid substrate once, at OPCOM init: the two live force layers
// (zeroed, the rebuild fills them each tick) and the two static per-cell arrays it never rebuilds -- a
// land mask and a flood-fill labelling connected land components. A ground tasking is ordered only where
// source and target cell share a component, so the director never routes a squad at an island it cannot
// reach. Server-local, numbers only, never persisted; a restored campaign refills the live layers on its
// first tick.
if (!isServer) exitWith {};

private _cell = OPCOM_GRID_CELL;
private _w = ceil (worldSize / _cell);
private _n = _w * _w;
DUWS_opcom_grid_w = _w;                       // cell width; every reader indexes _cy * _w + _cx

DUWS_opcom_grid_fri = []; DUWS_opcom_grid_fri resize _n;
DUWS_opcom_grid_ene = []; DUWS_opcom_grid_ene resize _n;
private _land = []; _land resize _n;          // true = land, passable to ground
private _comp = []; _comp resize _n;          // component id per land cell; -1 on water

// One pass sets every slot in all four arrays, so none is left nil. surfaceIsWater once per cell centre.
for "_cy" from 0 to (_w - 1) do {
    for "_cx" from 0 to (_w - 1) do {
        private _i = _cy * _w + _cx;
        _land set [_i, !(surfaceIsWater [(_cx + 0.5) * _cell, (_cy + 0.5) * _cell])];
        _comp set [_i, -1];
        DUWS_opcom_grid_fri set [_i, 0];
        DUWS_opcom_grid_ene set [_i, 0];
    };
};

// 8-neighbour flood fill: label each connected land region, matching the router's diagonal steps. An
// explicit stack, not recursion (SQF has no tail call); a cell can be pushed twice before it is labelled,
// so the pop re-checks. Water cells keep -1 and share a component with nothing.
private _next = 0;
for "_start" from 0 to (_n - 1) do {
    if ((_land select _start) && {(_comp select _start) < 0}) then {
        private _id = _next; _next = _next + 1;
        private _stack = [_start];
        while {count _stack > 0} do {
            private _i = _stack deleteAt (count _stack - 1);
            if ((_comp select _i) < 0) then {
                _comp set [_i, _id];
                private _ix = _i mod _w;
                private _iy = floor (_i / _w);
                for "_dy" from -1 to 1 do {
                    for "_dx" from -1 to 1 do {
                        if (_dx != 0 || _dy != 0) then {
                            private _nx = _ix + _dx;
                            private _ny = _iy + _dy;
                            if (_nx >= 0 && {_nx < _w} && {_ny >= 0} && {_ny < _w}) then {
                                private _j = _ny * _w + _nx;
                                if ((_land select _j) && {(_comp select _j) < 0}) then { _stack pushBack _j };
                            };
                        };
                    };
                };
            };
        };
    };
};

DUWS_opcom_grid_land = _land;
DUWS_opcom_grid_comp = _comp;

// Water connectivity, the boat/air domain split: flood-fill the water cells (the mask's complement), size
// each component, keep only the navigable ones. grid_water >= 0 is navigable water a boat routes and reaches
// within one component (size >= OPCOM_WATER_MIN_CELLS); a smaller pool and all land read -1, air-only.
private _wcomp = []; _wcomp resize _n;
for "_i" from 0 to (_n - 1) do { _wcomp set [_i, -1] };
private _wsize = [];
private _wnext = 0;
for "_start" from 0 to (_n - 1) do {
    if (!(_land select _start) && {(_wcomp select _start) < 0}) then {
        private _id = _wnext; _wnext = _wnext + 1;
        private _cnt = 0;
        private _stack = [_start];
        while {count _stack > 0} do {
            private _i = _stack deleteAt (count _stack - 1);
            if ((_wcomp select _i) < 0) then {
                _wcomp set [_i, _id];
                _cnt = _cnt + 1;
                private _ix = _i mod _w;
                private _iy = floor (_i / _w);
                for "_dy" from -1 to 1 do {
                    for "_dx" from -1 to 1 do {
                        if (_dx != 0 || _dy != 0) then {
                            private _nx = _ix + _dx;
                            private _ny = _iy + _dy;
                            if (_nx >= 0 && {_nx < _w} && {_ny >= 0} && {_ny < _w}) then {
                                private _j = _ny * _w + _nx;
                                if (!(_land select _j) && {(_wcomp select _j) < 0}) then { _stack pushBack _j };
                            };
                        };
                    };
                };
            };
        };
        _wsize set [_id, _cnt];
    };
};
private _water = []; _water resize _n;
for "_i" from 0 to (_n - 1) do {
    private _c = _wcomp select _i;
    _water set [_i, [-1, _c] select (_c >= 0 && {(_wsize select _c) >= OPCOM_WATER_MIN_CELLS})];
};
DUWS_opcom_grid_water = _water;
