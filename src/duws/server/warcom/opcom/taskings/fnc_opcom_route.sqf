// Locality: server. Plans a tasking's route: [_pts, _mode] -- _pts an [x,y,z] chain ending at the target
// ([] = none), _mode "road"/"grid". Runs scheduled (the road branch may yield), never in the scoring isNil
// block. Wheeled/tracked route on roads (fnc_convoy_path's polyline, stepped as one hull -- no convoy driver);
// infantry/air/boat take an A* cost-field cell chain, cost = stepLen + OPCOM_ROUTE_LAMBDA*_lambda*gridEne.
// Road routing is threat-blind: the lambda term steers only the cell chain, never which road a hull takes.
params ["_startPos", "_destPos", "_moveType", ["_lambda", 0]];
if (!isServer) exitWith { [[], "grid"] };

// A segment is [points, "road"|"gap"]; a "gap" carries only its two endpoints (a bridge the hull drives itself).
if (_moveType in ["wheeled", "tracked"]) exitWith {
    private _segs = [_startPos, _destPos] call fnc_convoy_path;
    private _pts = [];
    {
        _x params ["_p", "_tag"];
        // A water-crossing gap would beach a ground hull; the router avoids it where it can, so log and bridge.
        if (_tag isEqualTo "gap" && {[_p select 0, _p select (count _p - 1)] call fnc_route_has_water}) then {
            ["WARN", "OPCOM", format ["road route gap crosses water %1->%2", _p select 0, _p select (count _p - 1)]] call fnc_log;
        };
        { if (_pts isEqualTo [] || {(_pts select (count _pts - 1)) distance2D _x > 1}) then { _pts pushBack _x } } forEach _p;
    } forEach _segs;
    [_pts, "road"]
};

private _w    = DUWS_opcom_grid_w;
private _n    = _w * _w;
// Out-of-box cells are never built, so a neighbour outside the play box is impassable; ends are box-clamped by w2c.
(missionNamespace getVariable ["DUWS_opcom_box", [0, 0, _w - 1, _w - 1]]) params ["_bMinCx", "_bMinCy", "_bMaxCx", "_bMaxCy"];
private _land = DUWS_opcom_grid_land;
private _gwater = DUWS_opcom_grid_water;
private _ene  = DUWS_opcom_grid_ene;
private _water = DUWS_opcom_moveWater getOrDefault [_moveType, "land"];

// A land type may cross navigable water (at the lift penalty below), so its passable set includes water cells.
private _passable = {
    params ["_i"];
    switch (_water) do {
        case "air":   { true };
        case "water": { (_gwater select _i) >= 0 };   // navigable water only, sub-threshold pools excluded
        default       { (_land select _i) || {(_gwater select _i) >= 0} };
    };
};

private _s = [_startPos] call DUWS_fnc_opcom_w2c;
private _d = [_destPos]  call DUWS_fnc_opcom_w2c;
if (_s == _d) exitWith { [[_destPos], "grid"] };

// No land-component pre-check: a land type can cross navigable water, so ends on different masses may still join.

// A boat needs source and target in one navigable water component, or it cannot join them across land.
if (_water isEqualTo "water" && {!((_gwater select _s) >= 0 && {(_gwater select _d) >= 0} && {(_gwater select _s) == (_gwater select _d)})}) exitWith {
    ["WARN", "OPCOM", format ["no water route %1->%2 (not one navigable body); holding straight", _s, _d]] call fnc_log;
    [[_destPos], "grid"]
};

private _cell = OPCOM_GRID_CELL;
private _diag = _cell * sqrt 2;
private _lw = OPCOM_ROUTE_LAMBDA * _lambda;

private _g = []; _g resize _n;                 // best cost to a cell, -1 = unseen
private _from = []; _from resize _n;           // predecessor cell, -1 = none
for "_i" from 0 to (_n - 1) do { _g set [_i, -1]; _from set [_i, -1] };
_g set [_s, 0];

private _hCost = {                             // octile heuristic to _d, admissible at any lambda >= 0
    params ["_i"];
    private _dx = abs ((_i mod _w) - (_d mod _w));
    private _dy = abs ((floor (_i / _w)) - (floor (_d / _w)));
    (_cell * ((_dx max _dy) - (_dx min _dy))) + (_diag * (_dx min _dy))
};

private _open = [_s];
private _openF = [[_s] call _hCost];           // parallel f-scores, linear min-scan (open set stays small)
private _found = false;
private _guard = 0;                             // pop cap: bounds a pathological re-open, never hit on a direct route
while {count _open > 0 && {_guard < _n}} do {
    _guard = _guard + 1;
    private _bi = 0;
    for "_k" from 1 to (count _open - 1) do { if ((_openF select _k) < (_openF select _bi)) then { _bi = _k } };
    private _cur = _open deleteAt _bi;
    _openF deleteAt _bi;
    if (_cur == _d) exitWith { _found = true };
    private _cx = _cur mod _w;
    private _cy = floor (_cur / _w);
    for "_dy" from -1 to 1 do {
        for "_dx" from -1 to 1 do {
            if (_dx != 0 || _dy != 0) then {
                private _nx = _cx + _dx;
                private _ny = _cy + _dy;
                if (_nx >= _bMinCx && {_nx <= _bMaxCx} && {_ny >= _bMinCy} && {_ny <= _bMaxCy}) then {
                    private _j = _ny * _w + _nx;
                    if ([_j] call _passable) then {
                        private _step = [_cell, _diag] select (_dx != 0 && _dy != 0);
                        // A land type entering navigable water pays the ferry cost, so water is taken only when forced.
                        private _lift = [0, OPCOM_ROUTE_LIFT_PENALTY] select (_water isEqualTo "land" && {(_gwater select _j) >= 0});
                        private _tentative = (_g select _cur) + _step + _lw * (_ene select _j) + _lift;
                        if ((_g select _j) < 0 || {_tentative < (_g select _j)}) then {
                            _g set [_j, _tentative];
                            _from set [_j, _cur];
                            private _fi = _open find _j;
                            if (_fi < 0) then { _open pushBack _j; _openF pushBack (_tentative + ([_j] call _hCost)) }
                            else { _openF set [_fi, _tentative + ([_j] call _hCost)] };
                        };
                    };
                };
            };
        };
    };
};

if (!_found) exitWith {
    ["WARN", "OPCOM", format ["A* found no route %1->%2 (%3); holding straight", _s, _d, _moveType]] call fnc_log;
    [[_destPos], "grid"]
};

// Intermediate hops as cell centres, the exact target as the final waypoint; the start cell is dropped.
private _chain = [];
private _c = _d;
while {_c != _s && {_c >= 0}} do { _chain pushBack _c; _c = _from select _c };
reverse _chain;
private _pts = [];
{ if (_forEachIndex < (count _chain - 1)) then { _pts pushBack ([_x] call DUWS_fnc_opcom_c2w) } } forEach _chain;
_pts pushBack _destPos;
[_pts, "grid"]
