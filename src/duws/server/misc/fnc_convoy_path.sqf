// Locality: any (terrain queries only), but the caller (fnc_convoy_drive) is server-side. Pure geometry:
// no spawning, no unit orders.
//
// Build a drivable polyline from _startPos to _destPos for the convoy driver to hand to setDriveOnPath. We
// route it OURSELVES instead of letting Arma's native vehicle pathfinder choose the route: native route
// calculation is what wedges the convoy lead on open ground and at junctions. setDriveOnPath along a
// precomputed line does not -- it just drives the points.
//
//   On the road network: A* over connected road segments -- the SHORTEST road path (edge = real segment
//   length, heuristic = straight-line to the dest, which never overestimates, so A* is optimal). Shortest
//   matters here beyond speed: a wandering path doubles back near itself, and a follower's nearest-point
//   progress measure then snaps to the wrong arm and the spacing control thrashes. A greedy walk that
//   returned the first path found produced 30 km routes to a 4 km destination; A* does not.
//
//   Roads first, off-road minimal: both ends snap to the NEAREST road (a generous radius), the A* runs
//   on-road, and only the short stubs from the true start/dest to their nearest road are off-road. A leg is
//   driven off-road in full only when an end has no road anywhere near it. An off-road run is a straight
//   line resampled every CP_OFF_STEP and deviated sideways around water, rocks, trees and buildings.
//
// The result always starts exactly at _startPos and ends exactly at _destPos, so the lead reaches the real
// waypoint and its leg completes. Consecutive near-duplicate points are dropped so setDriveOnPath is not fed
// a zero-length segment.
//
// [_startPos, _destPos] -> [[x,y,z], ...]   // >= 2 points, start first, dest last
params ["_startPos", "_destPos"];

#define CP_ROAD_FIND  3000     // snap each end to its nearest road within this (m). Generous so we prefer the
                               // network and drive off-road only the unavoidable stub; only a truly roadless
                               // end (a remote island) falls through to a full off-road leg.
#define CP_MAX_STEPS  40000    // runaway backstop ONLY (a bug guard), NOT a route-length limit: the closed
                               // set already terminates A* when the reachable network is exhausted. Set past
                               // Altis's whole segment count, so a real route never hits it.
#define CP_YIELD      250      // yield to the scheduler every this many expansions, so even a whole-network
                               // search spreads across frames instead of hitching one. The caller (the convoy
                               // driver) holds the column meanwhile, so a long compute reads as a brief halt.
#define CP_OFF_STEP   25       // off-road: resample the straight run every this many metres
#define CP_OFF_PROBE  35       // off-road: lateral offset tried to skirt an obstacle
#define CP_OFF_WIDEN  4        // off-road: widening lateral probes each side before giving up on a point
#define CP_DEDUP      3        // drop a point within this (m) of the previous one

// A point is blocked for a ground vehicle if the sea or a large natural/built obstacle sits on it. These are
// what strand a hull off-road; the deviation below routes around them.
private _fnc_blocked = {
    params ["_p"];
    surfaceIsWater _p
    || { !((nearestTerrainObjects [_p, ["ROCK", "TREE", "SMALL TREE", "WALL", "BUILDING", "HOUSE"], 8]) isEqualTo []) }
};

// A straight run _a -> _b resampled every CP_OFF_STEP, each sample nudged laterally to the nearest clear
// offset when it lands on an obstacle. Returns the INTERMEDIATE points only (excludes _a and _b).
private _fnc_offroad = {
    params ["_a", "_b"];
    private _pts = [];
    private _dist = _a distance2D _b;
    if (_dist < CP_OFF_STEP) exitWith { _pts };
    private _steps = ceil (_dist / CP_OFF_STEP);
    private _dir = _a getDir _b;
    for "_i" from 1 to (_steps - 1) do {
        if (_i mod 40 == 0 && {canSuspend}) then { sleep 0 };   // a long off-road fallback also yields
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

// Snap each end onto the network at its NEAREST road. Widen the query only as needed -- a point on/near a
// road resolves at 60 m (cheap); a remote one escalates, and only a truly roadless end returns null. nearRoads
// is nearest-first, so `select 0` is the closest, and a 3 km list is never built for a point already on a road.
private _fnc_nearestRoad = {
    params ["_pos"];
    private _r = objNull;
    { if (isNull _r) then { private _rs = _pos nearRoads _x; if !(_rs isEqualTo []) then { _r = _rs select 0 } } } forEach [60, 250, 1000, CP_ROAD_FIND];
    _r
};
private _startRoad = [_startPos] call _fnc_nearestRoad;
private _destRoad  = [_destPos]  call _fnc_nearestRoad;

// A* over the road graph, only when BOTH ends reach the network. A key is the segment centre rounded to the
// metre -- unique per segment (they sit >1 m apart), and a valid hashmap key where the road object is not.
private _chain = [];
if !(isNull _startRoad || {isNull _destRoad}) then {
    private _keyOf = { params ["_r"]; private _p = getPosATL _r; format ["%1_%2", round (_p select 0), round (_p select 1)] };
    private _destKey = [_destRoad] call _keyOf;

    private _g      = createHashMap;   // roadKey -> best known cost from the start road
    private _parent = createHashMap;   // roadKey -> the road it was reached from (rebuilds the path)
    private _closed = createHashMap;   // roadKey -> finalised (its shortest cost is settled)
    private _open   = [_startRoad];     // frontier; min-f is picked by a lazy scan (no heap in SQF)
    _g set [[_startRoad] call _keyOf, 0];
    private _goal  = objNull;
    private _steps = 0;

    while { count _open > 0 && {isNull _goal} && {_steps < CP_MAX_STEPS} } do {
        _steps = _steps + 1;
        if (_steps mod CP_YIELD == 0 && {canSuspend}) then { sleep 0 };   // spread a long search across frames

        // Pick the open node with least f = g + heuristic (straight-line to the dest). Lazy scan: cheaper than
        // a hand-rolled heap at this frontier size, and it re-reads g so an improved cost is honoured.
        private _bestI = 0;
        private _bestF = 1e12;
        {
            private _f = (_g getOrDefault [[_x] call _keyOf, 1e12]) + ((getPosATL _x) distance2D _destPos);
            if (_f < _bestF) then { _bestF = _f; _bestI = _forEachIndex };
        } forEach _open;
        private _cur    = _open deleteAt _bestI;
        private _curKey = [_cur] call _keyOf;
        if (_curKey == _destKey) exitWith { _goal = _cur };
        _closed set [_curKey, true];

        private _curG   = _g getOrDefault [_curKey, 1e12];
        private _curPos = getPosATL _cur;
        {
            private _nk = [_x] call _keyOf;
            if !(_closed getOrDefault [_nk, false]) then {
                private _tg = _curG + (_curPos distance2D (getPosATL _x));
                if (_tg < (_g getOrDefault [_nk, 1e12])) then {
                    _g      set [_nk, _tg];
                    _parent set [_nk, _cur];
                    if !(_x in _open) then { _open pushBack _x };
                };
            };
        } forEach (roadsConnectedTo _cur);
    };

    if (!isNull _goal) then {
        private _r = _goal;
        private _guard = 0;
        while { !isNull _r && {_guard < CP_MAX_STEPS} } do {
            _chain pushBack (getPosATL _r);   // built goal -> start; reversed below (pushBack is O(1), a
            _r = _parent getOrDefault [[_r] call _keyOf, objNull];   // prepend would be O(n^2) on a long path)
            _guard = _guard + 1;
        };
        reverse _chain;   // -> start .. goal order
    };
};

// DEBUG (silent unless duws_log_level is 4): the route breakdown, so an RPT tells apart the two ways a convoy
// ends up crossing open field -- a full off-road fallback (chainPts=0: A* found no path, whole leg beelines) vs
// a road route with off-road only on the stubs (start/dest -> nearest road). startRoad/destRoad=false means an
// end is roadless; chainPts=0 with both true means the ends sit on disconnected road components. Compare the
// stub lengths and the straight-line distance to see how much of the leg is off the network and why.
if (duws_log_level >= 4) then {
    private _straight = _startPos distance2D _destPos;
    private _sStub = if (_chain isEqualTo []) then { _straight } else { _startPos distance2D (_chain select 0) };
    private _eStub = if (_chain isEqualTo []) then { 0 } else { (_chain select (count _chain - 1)) distance2D _destPos };
    ["DEBUG", "CONVOY", format ["path start=[%1,%2] dest=[%3,%4] straight=%5 chainPts=%6 startRoad=%7 destRoad=%8 startStub=%9 endStub=%10",
        round (_startPos select 0), round (_startPos select 1), round (_destPos select 0), round (_destPos select 1),
        round _straight, count _chain, !isNull _startRoad, !isNull _destRoad, round _sStub, round _eStub]] call fnc_log;
};

// Stitch: start stub, the road chain, end stub. No chain (a roadless end, or disconnected road components)
// -> one deviated off-road run the whole way.
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
