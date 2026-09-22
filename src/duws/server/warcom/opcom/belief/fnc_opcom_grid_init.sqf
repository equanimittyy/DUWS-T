// Locality: server. Builds the influence-grid substrate once, at OPCOM init: the two live force layers and the static
// layer cached under them (zeroed; the grid stage's first tick is a dirty-all), the per-cell arrays it never rebuilds
// -- a land mask and water connectivity -- and the coverage layer, a per-cell last-swept tick the sensors stamp and the
// rebuild never touches (accumulating memory, not a live layer). Server-local, numbers only, never persisted; a
// restored campaign refills the live layers on its first tick and re-learns coverage from cold.
//
// Only the play box is calculated. The full-width lattice is allocated so every reader keeps the absolute
// _cy * _w + _cx index, but surfaceIsWater and the water flood fill run only inside the box (DUWS_opcom_box, a
// cell-index rectangle around the zones, towns and HQ plus OPCOM_GRID_BOX_BUFFER_CELLS). Out-of-box cells stay
// land=false / water=-1 -- impassable to ground and boat, and the router rejects them -- so OPCOM
// never computes or routes over the empty rest of the map.
if (!isServer) exitWith {};

private _cell = OPCOM_GRID_CELL;
private _w = ceil (worldSize / _cell);
private _n = _w * _w;
DUWS_opcom_grid_w = _w;                       // cell width; every reader indexes _cy * _w + _cx

// Play box: grow world bounds by each play feature's own radius, then by the buffer, and snap to cells.
// Falls back to the whole map if no feature is present (a degenerate mission), so the grid is never empty.
private _minX = 1e12; private _minY = 1e12; private _maxX = -1e12; private _maxY = -1e12;
private _grow = {
    params ["_p", "_r"];
    _minX = _minX min ((_p select 0) - _r); _maxX = _maxX max ((_p select 0) + _r);
    _minY = _minY min ((_p select 1) - _r); _maxY = _maxY max ((_p select 1) + _r);
};
{ [_x select 1, _x select 2] call _grow } forEach zone_meta_array;
private _radii = missionNamespace getVariable ["civ_radii", []];
{ [getPos _x, (_radii param [_forEachIndex, 500])] call _grow } forEach (missionNamespace getVariable ["civ_locations", []]);
if (!isNil "PosOfBLUHQ" && {PosOfBLUHQ isNotEqualTo []}) then {
    [PosOfBLUHQ, missionNamespace getVariable ["DUWS_base_keep_radius", 250]] call _grow;
};

private _minCx = 0; private _minCy = 0; private _maxCx = _w - 1; private _maxCy = _w - 1;
if (_maxX > _minX) then {
    private _buf = OPCOM_GRID_BOX_BUFFER_CELLS * _cell;
    _minCx = (floor ((_minX - _buf) / _cell)) max 0;
    _minCy = (floor ((_minY - _buf) / _cell)) max 0;
    _maxCx = (floor ((_maxX + _buf) / _cell)) min (_w - 1);
    _maxCy = (floor ((_maxY + _buf) / _cell)) min (_w - 1);
};
DUWS_opcom_box = [_minCx, _minCy, _maxCx, _maxCy];

DUWS_opcom_grid_fri = []; DUWS_opcom_grid_fri resize _n;
DUWS_opcom_grid_ene = []; DUWS_opcom_grid_ene resize _n;
DUWS_opcom_grid_seen = []; DUWS_opcom_grid_seen resize _n;   // last-swept tick per cell
private _land = []; _land resize _n;          // true = land, passable to ground
DUWS_opcom_grid_traffic = []; DUWS_opcom_grid_traffic resize _n;           // believed force last crossing, decayed on read
DUWS_opcom_grid_trafficTick = []; DUWS_opcom_grid_trafficTick resize _n;

// Cheap default for every slot so none is left nil; the costly surfaceIsWater runs only inside the box.
// seen inits a full span in the past so an unswept cell reads max staleness via the same formula, no sentinel.
for "_i" from 0 to (_n - 1) do {
    _land set [_i, false];
    DUWS_opcom_grid_fri set [_i, 0];
    DUWS_opcom_grid_ene set [_i, 0];
    DUWS_opcom_grid_seen set [_i, -OPCOM_COVER_SPAN];
    DUWS_opcom_grid_traffic set [_i, 0];
    DUWS_opcom_grid_trafficTick set [_i, 0];
};
for "_cy" from _minCy to _maxCy do {
    for "_cx" from _minCx to _maxCx do {
        _land set [_cy * _w + _cx, !(surfaceIsWater [(_cx + 0.5) * _cell, (_cy + 0.5) * _cell])];
    };
};

// The 500 m centre-sample marks a coastal site's cell water when its centre falls offshore, so a ground route would
// need a ferry, or find no way in, to reach a garrison site that is really on land.
private _forceLand = {
    params ["_p"];
    private _fx = (floor ((_p select 0) / _cell)) min (_w - 1) max 0;
    private _fy = (floor ((_p select 1) / _cell)) min (_w - 1) max 0;
    _land set [_fy * _w + _fx, true];
};
{ [_x select 1] call _forceLand } forEach zone_meta_array;
{ [getPos _x] call _forceLand } forEach (missionNamespace getVariable ["civ_locations", []]);

DUWS_opcom_grid_land = _land;
DUWS_opcom_needStatic = _land apply { 0 };
DUWS_opcom_bandCells = [];
DUWS_opcom_needCells = [];
DUWS_opcom_needSig = [];
DUWS_opcom_needBuilding = false;

DUWS_opcom_gridStaticFri = +DUWS_opcom_grid_fri;
DUWS_opcom_gridStaticEne = +DUWS_opcom_grid_ene;
DUWS_opcom_gridSrc = createHashMap;
DUWS_opcom_gridAwake = createHashMap;
DUWS_opcom_gridDirty = createHashMap;
call DUWS_fnc_opcom_gridDirtyAll;

// Water connectivity, the boat/air domain split: flood-fill the water cells (the mask's complement), size
// each component, keep only the navigable ones. grid_water >= 0 is navigable water a boat routes and reaches
// within one component (size >= OPCOM_WATER_MIN_CELLS); a smaller pool and all land read -1, air-only. Bounded
// to the box so out-of-box cells (land=false by default) are not flooded into one bogus giant water body.
private _wcomp = []; _wcomp resize _n;
for "_i" from 0 to (_n - 1) do { _wcomp set [_i, -1] };
private _wsize = [];
private _wnext = 0;
for "_sy" from _minCy to _maxCy do {
    for "_sx" from _minCx to _maxCx do {
        private _start = _sy * _w + _sx;
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
                                if (_nx >= _minCx && {_nx <= _maxCx} && {_ny >= _minCy} && {_ny <= _maxCy}) then {
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
};
private _water = []; _water resize _n;
for "_i" from 0 to (_n - 1) do {
    private _c = _wcomp select _i;
    _water set [_i, [-1, _c] select (_c >= 0 && {(_wsize select _c) >= OPCOM_WATER_MIN_CELLS})];
};
DUWS_opcom_grid_water = _water;
