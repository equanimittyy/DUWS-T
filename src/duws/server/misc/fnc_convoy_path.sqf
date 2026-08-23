// Locality: any (terrain queries only), but the caller (fnc_convoy_drive) is server-side. Pure geometry:
// no spawning, no unit orders.
//
// Build a drivable polyline from _startPos to _destPos for the convoy driver to hand to setDriveOnPath. We
// route it OURSELVES instead of letting Arma's native vehicle pathfinder choose the route: native route
// calculation is what wedges the convoy lead on open ground and at junctions. setDriveOnPath along a
// precomputed line does not -- it just drives the points.
//
//   On the road network: a walk of connected road segments greedily toward the destination -- depth-first
//   with backtracking and a visited set, so it always terminates and escapes a dead-end/cul-de-sac. It
//   finds A road path (not the strictly shortest); greedy ordering keeps it near-direct. SQF has no heap, so
//   this is DFS, not A* -- DFS needs no priority queue.
//
//   Off the network: the two short stubs from start/dest to their nearest road, or a whole leg with no road
//   at either end, are a straight run resampled every CP_OFF_STEP and deviated sideways around water and
//   large statics. Coarse on purpose -- "skirt the sea inlet / the rock", not a terrain-cost search; the
//   driver's recovery ladder covers any residual wedge.
//
// The result always starts exactly at _startPos and ends exactly at _destPos, so the lead reaches the real
// waypoint and its leg completes. Consecutive near-duplicate points are dropped so setDriveOnPath is not fed
// a zero-length segment.
//
// [_startPos, _destPos] -> [[x,y,z], ...]   // >= 2 points, start first, dest last
params ["_startPos", "_destPos"];

#define CP_ROAD_SNAP  80       // search this far (m) for a road to get on/off the network at each end, and
                               // the radius at which the road walk counts itself as having reached the dest
#define CP_MAX_STEPS  2000     // hard cap on segments expanded before falling back -- a terminating backstop,
                               // set far above any real route (~40 km of segments), not a tuning knob
#define CP_OFF_STEP   25       // off-road: resample the straight run every this many metres
#define CP_OFF_PROBE  35       // off-road: lateral offset tried to skirt water / a static
#define CP_OFF_WIDEN  4        // off-road: widening lateral probes each side before giving up on a point
#define CP_DEDUP      3        // drop a point within this (m) of the previous one

// A point is blocked for a ground vehicle if the sea or a large static sits on it. Water is the real
// convoy-killer; rocks/walls/buildings are a light guard for the off-road stubs (short, rarely near one).
private _fnc_blocked = {
    params ["_p"];
    surfaceIsWater _p || { !((nearestTerrainObjects [_p, ["ROCK", "WALL", "BUILDING", "HOUSE"], 8]) isEqualTo []) }
};

// A straight run _a -> _b resampled every CP_OFF_STEP, each sample nudged laterally to the nearest clear
// offset when it lands on water or a static. Returns the INTERMEDIATE points only (excludes _a and _b).
private _fnc_offroad = {
    params ["_a", "_b"];
    private _pts = [];
    private _dist = _a distance2D _b;
    if (_dist < CP_OFF_STEP) exitWith { _pts };
    private _steps = ceil (_dist / CP_OFF_STEP);
    private _dir = _a getDir _b;
    for "_i" from 1 to (_steps - 1) do {
        private _t = _i / _steps;
        private _p = [
            (_a select 0) + ((_b select 0) - (_a select 0)) * _t,
            (_a select 1) + ((_b select 1) - (_a select 1)) * _t,
            0
        ];
        if ([_p] call _fnc_blocked) then {
            private _found = false;
            for "_w" from 1 to CP_OFF_WIDEN do {
                {
                    private _cand = _p getPos [CP_OFF_PROBE * _w, _dir + _x];
                    if (!([_cand] call _fnc_blocked)) exitWith { _p = _cand; _found = true };
                } forEach [90, -90];
                if (_found) exitWith {};
            };
        };
        _pts pushBack _p;
    };
    _pts
};

// Snap both ends onto the network. nearRoads returns nearest-first, so `select 0` is the closest segment.
private _startRoads = _startPos nearRoads CP_ROAD_SNAP;
private _destRoads  = _destPos  nearRoads CP_ROAD_SNAP;

// Road-graph walk, only when BOTH ends reach the network. A key is the segment centre rounded to the metre
// -- unique per segment (they sit >1 m apart), and a valid hashmap key where the road object is not.
private _chain = [];
if !(_startRoads isEqualTo [] || {_destRoads isEqualTo []}) then {
    private _keyOf = { params ["_r"]; private _p = getPosATL _r; format ["%1_%2", round (_p select 0), round (_p select 1)] };
    private _visited = createHashMap;
    private _parent  = createHashMap;   // roadKey -> the road it was reached from (rebuilds the path)
    private _start   = _startRoads select 0;
    private _stack   = [_start];
    _visited set [[_start] call _keyOf, true];
    private _goal    = objNull;
    private _steps   = 0;

    while { count _stack > 0 && {isNull _goal} && {_steps < CP_MAX_STEPS} } do {
        _steps = _steps + 1;
        private _cur = _stack deleteAt (count _stack - 1);   // LIFO -> depth-first
        if ((getPosATL _cur) distance2D _destPos < CP_ROAD_SNAP) exitWith { _goal = _cur };
        // Unvisited neighbours, sorted FARTHEST-from-dest first so the nearest lands on TOP of the stack and
        // is expanded next -- greedy toward the destination, with the rest left below to backtrack into.
        private _nbrs = (roadsConnectedTo _cur) select { !(_visited getOrDefault [[_x] call _keyOf, false]) };
        _nbrs = [_nbrs, [], { (getPosATL _x) distance2D _destPos }, "DESCEND"] call BIS_fnc_sortBy;
        {
            _visited set [[_x] call _keyOf, true];
            _parent  set [[_x] call _keyOf, _cur];
            _stack pushBack _x;
        } forEach _nbrs;
    };

    if (!isNull _goal) then {
        private _r = _goal;
        private _guard = 0;
        while { !isNull _r && {_guard < CP_MAX_STEPS} } do {
            _chain = [getPosATL _r] + _chain;   // prepend: rebuild start -> goal order
            _r = _parent getOrDefault [[_r] call _keyOf, objNull];
            _guard = _guard + 1;
        };
    };
};

// Stitch: start stub, the road chain, end stub. No chain (off-network or the walk hit its cap) -> one
// deviated off-road run the whole way.
private _route = [_startPos];
if (_chain isEqualTo []) then {
    _route append ([_startPos, _destPos] call _fnc_offroad);
} else {
    _route append ([_startPos, _chain select 0] call _fnc_offroad);
    _route append _chain;
    _route append ([_chain select (count _chain - 1), _destPos] call _fnc_offroad);
};
_route pushBack _destPos;

// Drop consecutive near-duplicates so setDriveOnPath never gets a zero-length hop; keep the exact dest last.
private _clean = [];
{ if (_clean isEqualTo [] || {(_x distance2D (_clean select (count _clean - 1))) > CP_DEDUP}) then { _clean pushBack _x } } forEach _route;
if ((_clean select (count _clean - 1)) distance2D _destPos > 0.1) then { _clean pushBack _destPos };
if (count _clean < 2) then { _clean = [_startPos, _destPos] };
_clean
