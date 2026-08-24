// Locality: any (pure geometry, no spawning). Both convoy callers are server-side.
//
// Lay a convoy as a column ON a precomputed drive route (the breadcrumb from fnc_convoy_path), so the hulls
// are born exactly on the path they will drive, in trail order, instead of on a road line that may diverge
// from the actual route. Given the route and a hull count, return
// one [_pos, _dir] slot per hull -- LEAD FIRST (index 0), spaced _spacing metres by arc length, each facing
// forward along the route toward the destination. The caller spawns one hull per slot and hands the SAME
// route to fnc_convoy_drive (DUWS_convoy_route0) so the driver reuses it for the first leg -- no recompute,
// and no teleport-snap to reorder the column, because it already sits on the route in order.
//
// The lead sits (_count - 1) * _spacing metres INTO the route and the tail at its start, so the whole column
// lies on the route with the lead ahead and the convoy drives forward off it. A route too short to seat the
// column (never in practice -- routes run kilometres, columns tens of metres) falls back to a straight trail
// laid BEHIND the start along the reverse of the initial heading, so the caller always gets _count slots.
//
// [_route, _count, _spacing] -> [[_pos, _dir], ...]   // _count entries, lead first
params ["_route", "_count", ["_spacing", 22]];

private _n = count _route;
private _slots = [];

// Total route length, and a short-route guard: if the column cannot fit on the route, trail it straight
// behind the start (a straight-line trail) so hulls never overlap or clamp onto one
// point. Lead (index 0) at the start, the rest behind it against travel.
private _total = 0;
for "_i" from 0 to (_n - 2) do { _total = _total + ((_route select _i) distance2D (_route select (_i + 1))) };
if (_n < 2 || {_total < (_count - 1) * _spacing}) exitWith {
    private _start = _route select 0;
    private _fwd = if (_n >= 2) then { (_route select 0) getDir (_route select 1) } else { 0 };
    for "_k" from 0 to (_count - 1) do { _slots pushBack [_start getPos [_k * _spacing, _fwd + 180], _fwd] };
    _slots
};

// Point and forward tangent at arc-distance _d from the route start (clamped to the route ends).
private _atDist = {
    params ["_d"];
    private _acc = 0;
    private _res = [];
    for "_i" from 0 to (_n - 2) do {
        private _a = _route select _i;
        private _b = _route select (_i + 1);
        private _seg = _a distance2D _b;
        if (_acc + _seg >= _d) exitWith {
            private _t = if (_seg > 0) then { (_d - _acc) / _seg } else { 0 };
            _res = [[(_a select 0) + ((_b select 0) - (_a select 0)) * _t,
                     (_a select 1) + ((_b select 1) - (_a select 1)) * _t, 0], _a getDir _b];
        };
        _acc = _acc + _seg;
    };
    if (_res isEqualTo []) then {   // past the last point: hold there, facing the final segment
        _res = [_route select (_n - 1), (_route select (_n - 2)) getDir (_route select (_n - 1))];
    };
    _res
};

// Lead (index 0) deepest into the route, tail (last) at the start, all facing forward.
for "_k" from 0 to (_count - 1) do {
    _slots pushBack ([((_count - 1) - _k) * _spacing] call _atDist);
};
_slots
