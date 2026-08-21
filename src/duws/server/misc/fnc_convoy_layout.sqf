// Locality: any (terrain queries only), but both callers are server-side. Pure geometry: no spawning.
//
// Lay a convoy as a column ON the road network. Given a start near a road and the direction the column
// will travel, walk connected road segments back from the nearest road and return one [_pos, _dir] slot
// per vehicle -- lead first, spaced ~_spacing metres by arc length, each facing down the road toward
// travel. The caller spawns one hull per slot.
//
// This is the fix for two convoy faults at once. Hulls used to be faced by a map bearing (start->via),
// so on a road that ran across that bearing they sat crossways; here the facing is the road's own tangent.
// And the column used to be laid by fixed offsets each snapped to its nearest road-segment CENTRE, which
// collapsed several slots onto one point -- overlapping hulls the physics engine then shoved apart into a
// scatter; here the slots are real arc-length spacing along one walked road, so nothing overlaps.
//
// Roadless start (a remote objective off the network): falls back to a straight line trailing back along
// the reverse-travel bearing, so a caller always gets exactly _count usable slots and never a short array.
//
// [_startPos, _travelDir, _count, _spacing] -> [[_pos, _dir], ...]   // _count entries, lead first
params ["_startPos", "_travelDir", "_count", ["_spacing", 22]];

private _slots = [];

// The road to lay on: nearest segment to the start. None near -> straight-line trail.
private _roads = _startPos nearRoads 50;
if (_roads isEqualTo []) exitWith {
    for "_k" from 0 to (_count - 1) do {
        _slots pushBack [_startPos getPos [_k * _spacing, _travelDir + 180], _travelDir];
    };
    _slots
};

// Walk the network backward from the lead (against travel) so trailing hulls sit behind it. At each
// segment take the connected road whose bearing best continues the walk and does not double back; a
// junction that only turns hard (dot < 0.2) ends the walk and the tail falls to the straight extension.
private _chain = [getPosATL (_roads select 0)];
private _cur  = _roads select 0;
private _prev = objNull;
private _walkDir = _travelDir + 180;
for "_step" from 1 to 60 do {
    private _here = getPosATL _cur;
    private _next = objNull;
    private _bestDot = -2;
    {
        if (_x != _prev && {_x != _cur}) then {
            private _dot = cos ((_here getDir (getPosATL _x)) - _walkDir);
            if (_dot > _bestDot) then { _bestDot = _dot; _next = _x };
        };
    } forEach (roadsConnectedTo _cur);
    if (isNull _next || {_bestDot < 0.2}) exitWith {};
    private _np = getPosATL _next;
    _walkDir = _here getDir _np;   // follow a curved road segment by segment
    _chain pushBack _np;
    _prev = _cur;
    _cur = _next;
};

// Arc-length placement along the walked polyline.
private _segLen = [];
for "_i" from 0 to (count _chain - 2) do {
    _segLen pushBack ((_chain select _i) distance2D (_chain select (_i + 1)));
};

for "_k" from 0 to (_count - 1) do {
    private _target = _k * _spacing;
    private _acc = 0;
    private _placed = false;
    {
        if (!_placed && {_acc + _x >= _target}) then {
            _placed = true;
            private _t = if (_x > 0) then { (_target - _acc) / _x } else { 0 };
            private _a = _chain select _forEachIndex;         // nearer the lead
            private _b = _chain select (_forEachIndex + 1);   // further back
            _slots pushBack [
                [(_a select 0) + ((_b select 0) - (_a select 0)) * _t,
                 (_a select 1) + ((_b select 1) - (_a select 1)) * _t, 0],
                _b getDir _a                                  // face toward the lead = travel direction
            ];
        };
        _acc = _acc + _x;
    } forEach _segLen;
    if (!_placed) then {
        // Past the walked road's end: extend straight from the last chain point along its final heading.
        private _n = count _chain;
        private _last = _chain select (_n - 1);
        private _backDir = if (_n >= 2) then { (_chain select (_n - 2)) getDir _last } else { _travelDir + 180 };
        _slots pushBack [_last getPos [_target - _acc, _backDir], _backDir + 180];
    };
};

_slots
