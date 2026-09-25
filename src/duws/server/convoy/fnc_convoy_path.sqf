// Locality: server. Reads the road graph fnc_convoy_graph builds at boot.
//
// Builds a drivable polyline from _startPos to _destPos for setDriveOnPath, routed ourselves since native
// vehicle pathfinding wedges the lead at junctions and on open ground. A* over connected road segments
// (edge = segment length, heuristic = straight-line, so optimal) after snapping both ends to their nearest
// road; only the stubs to the road are off-road. Shortest matters beyond speed -- a doubled-back path makes
// a follower's nearest-point progress snap to the wrong arm and thrash the spacing (a greedy walk once
// produced 30 km routes to a 4 km dest).
//
// Returns SEGMENTS tagged "road" or "gap" (a gap is a disconnected stretch the driver crosses natively),
// joined end-to-start from _startPos to _destPos.
// [_startPos, _destPos, _extra] -> [[[x,y,z], ...], "road"|"gap"], ...]   // >= 1 segment, each >= 2 points
// _extra: [] for length only, or [code, arg], [arg, from, to, length] call code adding a cost >= 0 to each road step,
// which keeps the straight-line heuristic admissible.
params ["_startPos", "_destPos", ["_extra", []]];
private _priced = _extra isNotEqualTo [];

#define CP_ROAD_FIND  3000     // snap each end to its nearest road within this (m). Generous so we prefer the
                               // network and drive off-road only the unavoidable stub; only a truly roadless
                               // end (a remote island) falls through to a full off-road leg.
#define CP_MAX_STEPS  40000    // runaway backstop ONLY (a bug guard), NOT a route-length limit: set past
                               // Altis's whole segment count. CP_STALL below is the ordinary terminator for an
                               // unreachable dest; this only catches a search that somehow neither reaches the
                               // goal nor plateaus.
#define CP_STALL      2500     // A* fast-bail: give up after this many pops with no closer approach to the dest.
                               // An unreachable dest (components no fnc_convoy_graph bridge could join) otherwise
                               // pops the ENTIRE reachable network before the open set empties -- tens of
                               // thousands of nodes, a long stall that hangs the convoy spawn gated behind this
                               // route. A reachable dest keeps pulling its closest approach in as A* homes toward
                               // it, so only a genuinely stuck search plateaus and trips this; the leg then falls
                               // through to off-road exactly as an exhausted search would. Far above the fruitless
                               // streak a legitimate detour (around a bay) ever runs, so a reachable route is never
                               // cut short.
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

// Snap each end onto the network at its NEAREST road, as a graph node (-1 = none). Widen the query only as needed --
// a point on/near a road resolves at 60 m (cheap); a remote one escalates, and only a truly roadless end returns -1.
// nearRoads is nearest-first, so `select 0` is the closest, and a 3 km list is never built for a point already on a
// road. The key is fnc_convoy_graph's.
private _fnc_nearestNode = {
    params ["_pos"];
    private _r = objNull;
    { if (isNull _r) then { private _rs = _pos nearRoads _x; if !(_rs isEqualTo []) then { _r = _rs select 0 } } } forEach [60, 250, 1000, CP_ROAD_FIND];
    if (isNull _r) exitWith { -1 };
    private _p = getPosATL _r;
    DUWS_convoy_roadIdx getOrDefault [[round (_p select 0), round (_p select 1)], -1]
};
private _startNode = [_startPos] call _fnc_nearestNode;
private _destNode  = [_destPos]  call _fnc_nearestNode;
private _rpos = DUWS_convoy_roadPos;

// A* over the road graph, only when BOTH ends reach the network.
private _chain = [];
// When A* fails to connect the ends (disconnected road components), _bestNode is the start-component road it
// got CLOSEST to the dest -- the point the convoy should leave the network to bridge the gap off-road. Its
// path back to the start road is _bridgeChain, rebuilt below. Both stay empty on a connected or roadless leg.
private _bestNode = -1;
private _bridgeChain = [];
if (_startNode >= 0 && {_destNode >= 0}) then {
    private _nbr    = DUWS_convoy_roadNbr;
    private _g      = createHashMap;   // node -> best known cost from the start road
    private _parent = createHashMap;   // node -> the node it was reached from (rebuilds the path)
    private _closed = createHashMap;   // node -> finalised (its shortest cost is settled)

    // The frontier: a binary min-heap on f = g + straight-line to the dest, in parallel arrays. A node whose cost
    // improves is pushed again, and its stale entries are dropped as closed when they surface.
    private _hf = [(_rpos select _startNode) distance2D _destPos];
    private _hn = [_startNode];
    private _fnc_push = {
        params ["_f", "_n"];
        private _i = count _hf;
        _hf pushBack _f;
        _hn pushBack _n;
        while {_i > 0} do {
            private _up = floor ((_i - 1) / 2);
            if ((_hf select _up) <= _f) exitWith {};
            _hf set [_i, _hf select _up];
            _hn set [_i, _hn select _up];
            _i = _up;
        };
        _hf set [_i, _f];
        _hn set [_i, _n];
    };
    private _fnc_pop = {
        private _top = _hn select 0;
        private _f = _hf deleteAt (count _hf - 1);
        private _n = _hn deleteAt (count _hn - 1);
        private _size = count _hf;
        if (_size > 0) then {
            private _i = 0;
            while {true} do {
                private _c = 2 * _i + 1;
                if (_c >= _size) exitWith {};
                if (_c + 1 < _size && {(_hf select (_c + 1)) < (_hf select _c)}) then { _c = _c + 1 };
                if ((_hf select _c) >= _f) exitWith {};
                _hf set [_i, _hf select _c];
                _hn set [_i, _hn select _c];
                _i = _c;
            };
            _hf set [_i, _f];
            _hn set [_i, _n];
        };
        _top
    };

    _g set [_startNode, 0];
    private _goal  = -1;
    private _steps = 0;
    // Closest any popped node has come to the dest, and how many pops since it last improved. A reachable
    // dest keeps pulling _bestH down; an unreachable one plateaus and bails at CP_STALL (see the define).
    private _bestH = 1e12;
    private _stall = 0;
    // An extra cost sends the search around what it prices, and a detour pops more nodes without closing on the dest.
    private _stallMax = [CP_STALL, CP_STALL * 4] select _priced;

    // The goal and the fast-bail exitWith leave only the expansion block; the loop condition then ends the search.
    while { count _hn > 0 && {_goal < 0} && {_stall < _stallMax} && {_steps < CP_MAX_STEPS} } do {
        private _cur = call _fnc_pop;
        if !(_closed getOrDefault [_cur, false]) then {
            _steps = _steps + 1;
            if (_steps mod CP_YIELD == 0 && {canSuspend}) then { sleep 0 };   // spread a long search across frames
            if (_cur == _destNode) exitWith { _goal = _cur };
            _closed set [_cur, true];

            private _curG   = _g get _cur;
            private _curPos = _rpos select _cur;
            private _h = _curPos distance2D _destPos;
            if (_h < _bestH) then { _bestH = _h; _bestNode = _cur; _stall = 0 } else { _stall = _stall + 1 };
            if (_stall >= _stallMax) exitWith {
                if (duws_log_level >= 4) then {
                    ["DEBUG", "CONVOY", format ["A* bail: closest %1 m after %2 pops, %3 with no gain -- dest unreachable, leg goes off-road",
                        round _bestH, _steps, _stall]] call fnc_log;
                };
            };
            {
                if !(_closed getOrDefault [_x, false]) then {
                    private _np = _rpos select _x;
                    private _len = _curPos distance2D _np;
                    private _tg = _curG + _len;
                    if (_priced) then { _tg = _tg + ([_extra select 1, _curPos, _np, _len] call (_extra select 0)) };
                    if (_tg < (_g getOrDefault [_x, 1e12])) then {
                        _g      set [_x, _tg];
                        _parent set [_x, _cur];
                        [_tg + (_np distance2D _destPos), _x] call _fnc_push;
                    };
                };
            } forEach (_nbr select _cur);
        };
    };

    // Points are copied out: every later search reads the graph's own arrays.
    if (_goal >= 0) then {
        private _r = _goal;
        private _guard = 0;
        while { _r >= 0 && {_guard < CP_MAX_STEPS} } do {
            _chain pushBack +(_rpos select _r);   // built goal -> start; reversed below (pushBack is O(1), a
            _r = _parent getOrDefault [_r, -1];   // prepend would be O(n^2) on a long path)
            _guard = _guard + 1;
        };
        reverse _chain;   // -> start .. goal order
    } else {
        // No through-path: rebuild the road run from the start road to _bestNode (the closest the search came
        // to the dest). That is the leg's road portion on the start side; the gap off it bridges to the dest
        // road. Same reverse-walk as the goal chain.
        if (_bestNode >= 0) then {
            private _r = _bestNode;
            private _guard = 0;
            while { _r >= 0 && {_guard < CP_MAX_STEPS} } do {
                _bridgeChain pushBack +(_rpos select _r);
                _r = _parent getOrDefault [_r, -1];
                _guard = _guard + 1;
            };
            reverse _bridgeChain;
        };
    };
};

// DEBUG (silent unless duws_log_level is 4): the route breakdown. chainPts>0 = a connected road route (one
// road segment). chainPts=0 with both roads true = disconnected components: a start-side road run to the exit
// (bridgePts long), a native gap across to the dest road, then the dest stub. A roadless end = one full gap.
if (duws_log_level >= 4) then {
    private _straight = _startPos distance2D _destPos;
    ["DEBUG", "CONVOY", format ["path start=[%1,%2] dest=[%3,%4] straight=%5 chainPts=%6 bridgePts=%7 startRoad=%8 destRoad=%9",
        round (_startPos select 0), round (_startPos select 1), round (_destPos select 0), round (_destPos select 1),
        round _straight, count _chain, count _bridgeChain, _startNode >= 0, _destNode >= 0]] call fnc_log;
};

// Clean a point run: drop consecutive near-duplicates (no zero-length setDriveOnPath hop) and guarantee it
// ends exactly at _end so a segment reaches its handoff point / the leg reaches its waypoint.
private _fnc_clean = {
    params ["_pts", "_end"];
    private _c = [];
    { if (_c isEqualTo [] || {(_x distance2D (_c select (count _c - 1))) > CP_DEDUP}) then { _c pushBack _x } } forEach _pts;
    if (_c isEqualTo [] || {(_c select (count _c - 1)) distance2D _end > 0.1}) then { _c pushBack _end };
    _c
};

// Build the segmented route: [points, mode] pairs, mode "road" (setDriveOnPath along the fixed polyline)
// or "gap" (the lead pathfinds it natively while the followers replay its track).
private _segs = [];
if (_chain isNotEqualTo []) then {
    // Connected: one road segment -- start stub, the road chain, end stub.
    private _r = [_startPos];
    _r append ([_startPos, _chain select 0] call _fnc_offroad);
    _r append _chain;
    _r append ([_chain select (count _chain - 1), _destPos] call _fnc_offroad);
    _segs = [[[_r, _destPos] call _fnc_clean, "road"]];
} else {
    if (_startNode >= 0 && {_destNode >= 0} && {_bridgeChain isNotEqualTo []}) then {
        // Disconnected, both ends on roads: road to the exit, a native gap across to the dest road, road out.
        private _exitPos     = _bridgeChain select (count _bridgeChain - 1);
        private _destRoadPos = +(_rpos select _destNode);
        private _r1 = [_startPos];
        _r1 append ([_startPos, _bridgeChain select 0] call _fnc_offroad);
        _r1 append _bridgeChain;                       // ends at the exit road (closest reached to the dest)
        private _r3 = [_destRoadPos];
        _r3 append ([_destRoadPos, _destPos] call _fnc_offroad);
        _segs = [
            [[_r1, _exitPos] call _fnc_clean, "road"],
            [[_exitPos, _destRoadPos], "gap"],         // native bridge: leave the network here, rejoin there
            [[_r3, _destPos] call _fnc_clean, "road"]
        ];
    } else {
        // A roadless end (or no exit found): the whole leg is one native gap.
        _segs = [[[_startPos, _destPos], "gap"]];
    };
};

// Drop any segment that collapsed to under two real points (e.g. start ~ exit), so the driver never gets a
// sub-2-point leg; if that empties the route, fall back to one native gap.
_segs = _segs select {
    private _p = _x select 0;
    count _p >= 2 && {((_p select 0) distance2D (_p select (count _p - 1))) > CP_DEDUP}
};
if (_segs isEqualTo []) then { _segs = [[[_startPos, _destPos], "gap"]] };
_segs
