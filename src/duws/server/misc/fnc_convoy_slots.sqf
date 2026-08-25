// Locality: any (pure geometry, no spawning). Both convoy callers are server-side.
//
// Lay a convoy as a column ON the precomputed drive route (from fnc_convoy_path), so the hulls are born on the
// path they will drive, in trail order, facing the way the column travels. Given the route and a hull count,
// return one [_pos, _dir] slot per hull -- LEAD FIRST (index 0), each seated on an actual route node, at least
// _spacing metres apart by straight-line distance, all sharing ONE heading (the column's travel bearing). The
// caller spawns one hull per slot and hands the SAME route to fnc_convoy_drive (DUWS_convoy_route0), so the
// driver reuses it for the first leg -- no recompute, and no teleport-snap to reorder the column.
//
// Nodes + one shared heading, NOT arc-interpolated points each facing their own local tangent: the road route's
// points are unevenly spaced and dogleg at junctions. Arc-length spacing puts two hulls closer than _spacing in
// straight line across a bend -- they spawn overlapping and the physics engine flings them apart -- and a
// per-point tangent swings hull-to-hull at a dogleg; both read in-game as a scattered spawn, not a column.
// Seating on real nodes with a straight-line separation floor cannot overlap, and one bearing keeps the column
// coherent. The driver's setDriveOnPath re-aligns each hull to the road the instant it rolls, so a hull seated
// on a curve facing the shared bearing (not its local tangent) straightens out on the first tick.
//
// [_route, _count, _spacing] -> [[_pos, _dir], ...]   // _count entries, lead first
params ["_route", "_count", ["_spacing", 22]];

// fnc_convoy_path returns a SEGMENTED route ([points, "road"|"gap"] entries); seating only needs the geometry,
// so flatten it to one point run. A segment entry is [array, string] (its mode is a string), a raw point is
// [x,y,z] (all numbers) -- so a string second element marks the segmented form. Segments join end-to-start, so
// drop the duplicated boundary point as they concatenate.
if (count _route > 0 && {(_route select 0) isEqualType []} && {count (_route select 0) >= 2} && {((_route select 0) select 1) isEqualType ""}) then {
    private _flat = [];
    {
        {
            if (_flat isEqualTo [] || {(_x distance2D (_flat select (count _flat - 1))) > 0.1}) then { _flat pushBack _x };
        } forEach (_x select 0);
    } forEach _route;
    _route = _flat;
};

private _n = count _route;

// The column's travel bearing: start -> the node about a column-length ahead, so a short leading stub or a
// single junction dogleg cannot tilt the whole column. A degenerate route falls back to the first segment, then 0.
private _spanIdx = 0;
private _acc = 0;
for "_i" from 0 to (_n - 2) do {
    _acc = _acc + ((_route select _i) distance2D (_route select (_i + 1)));
    _spanIdx = _i + 1;
    if (_acc >= (_count - 1) * _spacing) exitWith {};
};
private _hdg = if (_spanIdx >= 1 && {(_route select 0) distance2D (_route select _spanIdx) > 1}) then {
    (_route select 0) getDir (_route select _spanIdx)
} else {
    if (_n >= 2) then { (_route select 0) getDir (_route select 1) } else { 0 }
};

// DEBUG (silent unless duws_log_level is 4): the min pairwise separation of the returned slots and which
// branch produced them, so a report of hulls spawning stacked can be told apart from a downstream pile (a
// regroup, a junction) -- a minSep well below _spacing means the seating itself overlapped.
private _fnc_dbgSlots = {
    params ["_slots", "_branch"];
    if (duws_log_level >= 4) then {
        private _minD = 1e9;
        for "_i" from 0 to (count _slots - 2) do {
            for "_j" from (_i + 1) to (count _slots - 1) do {
                _minD = _minD min ((_slots select _i select 0) distance2D (_slots select _j select 0));
            };
        };
        ["DEBUG", "CONVOY", format ["slots %1: n=%2 minSep=%3 want=%4 hdg=%5", _branch, count _slots, round _minD, _spacing, round _hdg]] call fnc_log;
    };
};

// A node is unfit to seat a hull if it sits in water or hard against a building/rock/wall. A road node is clear,
// so this only rejects the off-road stretches (a roadless start, or a gap the search bridged off-road).
private _fnc_unfit = {
    params ["_p"];
    surfaceIsWater _p
    || { !((nearestTerrainObjects [_p, ["BUILDING", "HOUSE", "WALL", "ROCK"], 4]) isEqualTo []) }
};

// Walk the route from the start, taking one node per hull, each at least _spacing (straight-line) from the last
// taken so no two hulls spawn overlapping. Collected start-outward here; reversed to lead-first below.
private _picked = [];
private _lastPos = [];
{
    if (_picked isEqualTo [] || {(_x distance2D _lastPos) >= _spacing}) then {
        _picked pushBack _x;
        _lastPos = _x;
    };
    if (count _picked >= _count) exitWith {};
} forEach _route;

// Enough separated nodes AND all on drivable ground -> seat on them, lead (deepest) first, all on the bearing.
if (count _picked == _count && {(_picked findIf { [_x] call _fnc_unfit }) < 0}) exitWith {
    reverse _picked;   // start-outward -> lead first
    private _slots = [];
    { _slots pushBack [_x, _hdg] } forEach _picked;
    [_slots, "nodes"] call _fnc_dbgSlots;
    _slots
};

// Fallback -- the route cannot supply _count separated on-road nodes (too short, or its near end runs off-road):
// a straight trail behind the start on the travel bearing (lead at the start, the rest trailing back against
// travel), so the caller always gets _count slots and no hull is seated in water or a building.
private _slots = [];
for "_k" from 0 to (_count - 1) do { _slots pushBack [(_route select 0) getPos [_k * _spacing, _hdg + 180], _hdg] };
[_slots, "fallback"] call _fnc_dbgSlots;
_slots
