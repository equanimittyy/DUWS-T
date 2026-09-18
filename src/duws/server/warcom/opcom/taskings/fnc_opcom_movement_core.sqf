// Locality: server, [] call'd at load. Shared OPCOM movement core: the per-tick world-point mover and the
// grid-geometry tests every tasking's march uses, ferry or not.
if (!isServer) exitWith {};

// grid_water >= 0 is a navigable-water component; -1 is land or a sub-threshold pool.
DUWS_fnc_opcom_isWaterPt = {
    params ["_pt"];
    (DUWS_opcom_grid_water select ([_pt] call DUWS_fnc_opcom_w2c)) >= 0
};

DUWS_fnc_opcom_cellDist = {
    params ["_a", "_b"];
    private _w = DUWS_opcom_grid_w;
    private _ca = [_a] call DUWS_fnc_opcom_w2c;
    private _cb = [_b] call DUWS_fnc_opcom_w2c;
    (abs ((_ca mod _w) - (_cb mod _w))) max (abs (floor (_ca / _w) - floor (_cb / _w)))
};

// Returns "arrived", "water" (a transportable unit stopped at a ferry leg's near shore), "blocked" (a replan found
// no dry route for a hull), or "moving". Replans when the route chain is empty.
DUWS_fnc_opcom_advance = {
    params ["_t"];
    if ((_t get "route") isEqualTo [] && {(_t get "target") isNotEqualTo []}) then {
        ([_t get "pos", _t get "target", _t get "moveType", 0] call fnc_opcom_route) params ["_pts", "_mode"];
        _t set ["route", _pts]; _t set ["routeMode", _mode]; _t set ["leg", 0];
    };
    private _route = _t get "route";
    if (_route isEqualTo [] && {(_t get "target") isNotEqualTo []}) exitWith { "blocked" };
    private _leg = _t get "leg";
    private _pos = _t get "pos";
    private _transportable = "transportable" in (_t get "flags");
    private _remain = OPCOM_GRID_CELL / (DUWS_opcom_speed getOrDefault [_t get "moveType", 30]);
    private _water = false;
    while {_remain > 0 && {_leg < count _route} && {!_water}} do {
        private _wp = _route select _leg;
        if (_transportable && {[_wp] call DUWS_fnc_opcom_isWaterPt}) then {
            _water = true;
        } else {
            private _d = _pos distance2D _wp;
            if (_d <= _remain) then {
                _pos = +_wp; _leg = _leg + 1; _remain = _remain - _d;
            } else {
                private _dir = [(_wp select 0) - (_pos select 0), (_wp select 1) - (_pos select 1)];
                private _len = sqrt ((_dir select 0) ^ 2 + (_dir select 1) ^ 2);
                _pos = [(_pos select 0) + (_dir select 0) / _len * _remain, (_pos select 1) + (_dir select 1) / _len * _remain, 0];
                _remain = 0;
            };
        };
    };
    _t set ["pos", _pos];
    _t set ["leg", _leg];
    switch (true) do {
        case (_water): { "water" };
        case (_leg >= count _route): { "arrived" };
        default { "moving" };
    }
};
