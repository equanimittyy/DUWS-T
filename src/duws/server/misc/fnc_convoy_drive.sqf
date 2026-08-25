// Locality: server -- spawn once the group has its move waypoint(s) or a CYCLE loop. The whole convoy
// reliability engine, group-shape agnostic.
//
// Arma's native vehicle route CALCULATION is the unreliable half of convoy driving: it wedges the lead on
// open ground and at junctions with nothing in the way. Driving a KNOWN polyline with setDriveOnPath is the
// reliable half. So this engine routes the road ITSELF (fnc_convoy_path) and puts EVERY hull -- lead
// included -- on that fixed polyline with setDriveOnPath. Nothing is left to native routing.
//
// Group shape: the caller hands ONE group holding every hull, but a merged group fights the driver -- the
// subordinate AI drivers get formation/move orders from the group that override setDriveOnPath, and they
// stall. So the driver SPLITS each non-lead hull into its own single-hull group for the drive: each driver
// leads itself, so nothing competes with its path order. The lead stays in the caller's group, which remains
// the control handle (waypoints, flags, cv_lead, and a live leader for the caller's `behaviour (leader _grp)`
// tests). On release or teardown every hull is rejoined into that one group so native AI fights as a column,
// not a scatter of singletons (see the exit block).
//
//   Route: fnc_convoy_path walks the road graph from the lead's leg start to the leg's waypoint, returning a
//   drivable line (roads where they exist, a water/obstacle-deviated run off-network). It is recomputed only
//   when the leg changes, and cached so a CYCLE patrol reuses each lap's legs.
//
//   Legs are self-managed: we do NOT rely on native waypoint completion (we no longer native-drive the lead,
//   so it may not fire). We route to the current leg's waypoint, advance the leg index when the lead reaches
//   it, wrap on a CYCLE, pick up a waypoint appended mid-run (deny-armour's drive-in-then-home), and idle
//   when the index runs past the list (waiting for that appended waypoint).
//
//   Spacing (convoy-aware -- every hull tracks the one ahead): each hull drives its slice of the route from
//   its own position to the end. forceSpeed holds the gap -- a proportional band around a target spacing
//   (inside it match the hull ahead, outside run above or below in proportion to the error), with a
//   straight-line rear-end easing and a no-overtake clamp. The lead paces the column at the slowest hull's
//   top speed (capped to a sane road pace) and eases as the widest gap opens, so the column waits for its
//   tail. forceSpeed is FLOORED at a crawl (never 0) while driving: a forceSpeed 0 drops a hull off its
//   committed setDriveOnPath onto native idle, where a later positive forceSpeed is only a ceiling and cannot
//   restart it -- the crawl floor keeps every hull committed to its path. A deliberate hold (route computing,
//   no live waypoint) still uses forceSpeed 0, because it is always followed by a fresh path issue.
//
//   Recovery for a hull the engine still wedges (a dynamic obstacle, a bad segment), in two tiers:
//     - TIER 1 REGROUP (view-safe, tried first): the column halts and every hull independently re-routes back
//       to formation -- the lead holds, each follower (its own group) drives to its ordered slot behind it,
//       then the column resumes. A wedged lead nudges itself forward one route hop. They regroup, never blink.
//     - TIER 2 TELEPORT (fallback): only if Tier 1 cannot free the column (it stays frozen ~30 s) AND no
//       BLUFOR is within CV_TP_CLEAR to witness it -- realign the WHOLE convoy onto the breadcrumb, in trail
//       order along a straight-anchored stretch, and teleport it there. The out-of-sight guard keeps a
//       teleport out of the player's view; while witnessed, Tier 1 keeps trying until the column frees.
//
// Leadership is pinned to the frontmost hull (highest route progress) and re-picked only when the front dies
// (Arma migrates leadership to an arbitrary survivor -- maybe a rear hull, which would trace the column
// backwards); a re-picked lead is moved back into the control group. One loop owns each convoy. Hulls are
// read live from the control group AND the split follower groups: one joining the control group mid-run (the
// repaired tank) is picked up and split off, one leaving (the peeled HVT car) is dropped, with no caller
// bookkeeping. Where the hulls must break and fight (the roving patrol), the caller sets DUWS_convoy_release;
// DUWS_convoy_stop ends the loop the same way at teardown -- both rejoin and hand every hull to native AI.
params ["_group"];

#define CV_TICK        0.5     // control period. Kept short: forceSpeed is held open-loop between ticks, so a
                               // long period is dead time in the spacing loop -- at ~1.5 s the tail oscillated
                               // (dead time approached the target gap). 0.5 s keeps the loop responsive.
#define CV_STUCK_KMH   3       // at or below this, treat a hull as halted
#define CV_CRAWL       3       // forceSpeed floor (km/h) while driving: never 0, so a rear-end / no-overtake
                               // clamp cannot drop a hull off its committed setDriveOnPath onto native idle.
                               // Equal to CV_STUCK_KMH so a hull crawling at the floor is not read as "meant
                               // to move" by the wedge detector (that tests the pre-floor setpoint).
#define CV_RECOVER_AT  24      // ticks a hull sits wedged (~12 s) before Tier 1 recovery (regroup / lead nudge)
#define CV_FORMED      15      // a follower within this (m) of its slot counts as formed up during a regroup
#define CV_TELEPORT_AT 60      // ticks (~30 s) the WHOLE column stays frozen through Tier 1 before Tier 2 fires
#define CV_TP_CLEAR    300     // no BLUFOR within this (m) or the Tier 2 teleport is withheld (Tier 1 retries)
#define CV_ARRIVE      25      // lead within this of the leg waypoint -> the leg is done, advance to the next
// Gap mode (a leg the road search could not connect -- see the off-road branch): the lead pathfinds NATIVELY
// across the gap and the followers replay its driven track. A crumb is the lead's position, laid once it has
// advanced CV_STEP from the last, and only the last CV_TRAIL are kept. Native routing is trusted here -- and
// only here -- because the alternative on a roadless gap is a blind straight line through whatever water or
// terrain lies between the ends; native pathing routes around it and rejoins the road on its own.
#define CV_STEP        8       // lead must advance this far (m) before a new crumb is laid
#define CV_TRAIL       40      // crumbs kept (~320 m of track): longer than any column, short enough that a
                               // CYCLE patrol's looping track never snaps a follower onto a previous lap
#define CV_SNAP_SCAN   40      // teleport-snap: route points ahead of the lead scanned for a straight anchor
#define CV_SNAP_STRAIGHT 45    // teleport-snap: max total heading change (deg) over the column span for an anchor
                               // to count as straight enough -- loose on purpose, just keeps the realign off a
                               // hard bend. Too tight sent the scan hunting far ahead for a near-perfect stretch,
                               // teleporting the column well forward of where it actually was.
#define CV_SNAP_AHEAD  60      // teleport-snap: cap (m) on how far ahead of the lead the anchor may sit, so the
                               // snap realigns the column near where it is instead of flinging it forward to a
                               // distant straight. In metres (not point count): route point spacing varies.

// forceSpeed takes m/s. If an in-game check (a truck given `forceSpeed 8` rolls at ~29 km/h) proves it
// is km/h instead, set CV_KMH2FS to 1.0 so km/h values pass straight through.
#define CV_KMH2FS      (1.0 / 3.6)
#define KMH(x)         ((x) * CV_KMH2FS)
#define CV_NOLIMIT     1e10    // limitSpeed reset ("no cap"): -1 does NOT reset (forces helis reverse); the
                               // default is 2*maxSpeed, so a value past any vehicle's top speed removes the cap

#define CV_CRUISE_FRAC 0.85    // convoy cruise = this fraction of the slowest hull's config top speed, then
                               // capped at CV_CRUISE_MAX. Below top on purpose: the difference is the headroom a
                               // lagging follower spends to close a gap. Zero headroom (cruise == top) leaves
                               // small lags uncloseable and the column string-unstable.
#define CV_CRUISE_MAX  45      // hard ceiling on convoy cruise (km/h). Config maxSpeed is the flat-out downhill
                               // figure (wheeled hulls ~90-110), far above a sane road-convoy pace, so an
                               // all-wheeled column paced to it would zoom and drag the followers along. A
                               // genuinely slow tracked hull (top below this) still sets its own slower pace.
#define CV_CATCHUP_GAIN 20     // catch-up ceiling = cruise + this (km/h), never past the hull's own top: a
                               // lagging follower runs a little above cruise to close, not flat out -- full-top
                               // catch-up overshoots station into the same stop-start it is meant to damp.
#define CV_GAP_WANT    20      // target spacing to the hull ahead (m). Tighter than the spawn slot (~22 m, see
                               // fnc_convoy_slots): long escorts must not spawn bumper-to-bumper and explode,
                               // but the column closes to this once rolling.
#define CV_GAP_KP      1.5     // spacing gain: km/h added to the cruise setpoint per metre the along-route gap
                               // exceeds CV_GAP_WANT (negative when closer than target). A gentle ramp around
                               // cruise, clamped to [0, catch-up].
#define CV_GAP_KD      0.7     // damping gain: km/h per km/h of closing speed (aheadSpd - mySpd). Brakes an
                               // overshoot while closing; when the lead accelerates it feeds the tail forward
                               // with it, instead of reacting a tick late once the gap has already opened.
#define CV_GAP_HARD    4       // straight-line: closer than this, ease to the crawl floor -- backstop against
                               // rear-ending (a floor, not a full stop, so the hull holds its path)
#define CV_LAG_OK      28      // widest inter-hull gap tolerated at full cruise (m); past it the lead eases. Kept
                               // close to CV_GAP_WANT (only ~8 m of slack): a wider tolerance let the lead hold
                               // full cruise while a follower fell to ~2x target spacing, so the lead outran a
                               // lagging tail before reacting -- the followers' catch-up headroom is finite.
#define CV_LAG_STOP    70      // at or past this the lead eases to the crawl floor until the column closes up. The
                               // CV_LAG_OK..this ramp is deliberately narrow (~40 m) so the lead sheds speed
                               // steeply once the column stretches, rather than drifting on at near-cruise.
#define CV_REROUTE     30      // leg waypoint drifted this far from the route's end -> recompute the route

private _route  = [];             // the current leg's drivable polyline (from fnc_convoy_path), start..dest
private _cum    = [0];            // cumulative arc length along _route: _cum#i = metres from _route#0 to #i
private _cache  = createHashMap;  // rounded [legStart,target] key -> a computed route (CYCLE laps reuse legs)
private _legIdx = 0;              // self-managed current waypoint index (we do not trust native completion)
private _legStart = [];           // where the current leg is routed FROM (lead spawn pos, then each anchor)
private _stuck  = createHashMap;  // netId -> consecutive wedged ticks (per hull, lead included); drives recovery
private _issued = createHashMap;  // netId -> last slice start index handed to setDriveOnPath (-999 = force)
private _seen   = createHashMap;  // netId -> hull, every hull configured once (one-time setup + teardown reset)
private _topspd = createHashMap;  // netId -> config top speed (km/h), cached once: the convoy paces to the min
private _dumped = false;          // one-time level-4 dump of the waypoint list, so a stuck start is diagnosable
private _regroup  = false;        // Tier 1 state: while true the lead holds and every follower reforms on its slot
private _allStuck = 0;            // consecutive ticks the WHOLE column is frozen (nothing moving) -- Tier 2 trigger
// Split-group bookkeeping: each non-lead hull is driven in its own single-hull group so the merged-group AI
// cannot override its setDriveOnPath. _followers maps a hull's netId to that group; the lead is NOT in here
// (it stays in the caller's control group). Stale entries (a hull that died or peeled away, its group already
// auto-deleted) read back grpNull and are skipped everywhere.
private _followers = createHashMap;
// A caller that pre-seats its column ON the route hands that route in DUWS_convoy_route0: the driver reuses it
// for the first leg (no recompute). All current callers seat via fnc_convoy_slots, so the column is born in
// trail order on the route and needs no spawn-time ordering snap.
private _route0 = _group getVariable ["DUWS_convoy_route0", []];

// A leg's route is a list of SEGMENTS from fnc_convoy_path, each [points, "road"|"gap"]. The driver walks them
// in order: _segs holds the leg's segments, _segIdx the current one, _segTarget its end (the lead's goal until
// it hands off to the next segment). A "road" segment is driven on its fixed polyline with setDriveOnPath; a
// "gap" segment (the span the road search could not bridge) is driven with the lead pathfinding natively while
// the followers replay its crumb trail. So off-road complements the road route rather than replacing the leg,
// and every follower/spacing/recovery helper runs unchanged over whichever _route the current segment sets.
// _legOffroad = the current segment is a gap, and gates every gap branch; a road segment never touches the
// crumb machinery. _pathed tracks whether a hull holds a setDriveOnPath (cleared before a doMove); _gapIssued
// is the gap analogue of _issued (a fixed route re-issues on index change, a growing crumb trail as the lead
// advances). _legTargetCached is the waypoint the segments were built for, to spot a drifted waypoint.
private _segs       = [];
private _segIdx     = 0;
private _segTarget  = [];
private _legTargetCached = [];
private _legOffroad = false;
private _crumbs   = [];
private _pathed   = createHashMap;   // netId -> a setDriveOnPath is committed (clear before a doMove)
private _gapIssued = createHashMap;  // netId -> last gap issue [startIdx, leadPos]

// Load segment _i of _segs -> [points, isGap, endPoint, cumulativeArcLengths]. The caller assigns these to
// _route / _legOffroad / _segTarget / _cum; _segTarget is captured here because a gap segment overwrites
// _route with its crumb trail, so its end cannot be re-read off _route later.
private _fnc_segAt = {
    params ["_theSegs", "_i"];
    private _seg  = _theSegs select _i;
    private _pts  = _seg select 0;
    private _cm   = [0];
    for "_k" from 1 to (count _pts - 1) do { _cm pushBack ((_cm select (_k - 1)) + ((_pts select (_k - 1)) distance2D (_pts select _k))) };
    [_pts, (_seg select 1) == "gap", _pts select (count _pts - 1), _cm]
};

// Nearest route index to a position = the hull's progress along the route. -1 while the route is empty.
private _progressOf = {
    params ["_pos"];
    private _best = -1; private _bestD = 1e11;
    { private _d = _pos distance2D _x; if (_d < _bestD) then { _bestD = _d; _best = _forEachIndex } } forEach _route;
    _best
};

// A point _dist metres back along _route from index _fromIdx (a hull's station / regroup slot). Returns []
// when the route behind _fromIdx is shorter than _dist, so the caller can fall back to a heading offset.
private _stationBack = {
    params ["_fromIdx", "_dist"];
    private _res = [];
    if (_fromIdx >= 1 && {count _route >= 2}) then {
        private _prev = _route select (_fromIdx min (count _route - 1));
        private _acc = 0;
        for "_i" from ((_fromIdx - 1) min (count _route - 2)) to 0 step -1 do {
            private _c = _route select _i;
            private _seg = _prev distance2D _c;
            if (_acc + _seg >= _dist) exitWith {
                private _t = if (_seg > 0) then { (_dist - _acc) / _seg } else { 0 };
                _res = [(_prev select 0) + ((_c select 0) - (_prev select 0)) * _t,
                        (_prev select 1) + ((_c select 1) - (_prev select 1)) * _t, 0];
            };
            _acc = _acc + _seg;
            _prev = _c;
        };
    };
    _res
};

// Pick a snap anchor on a relatively straight stretch of the route, so realigning the column does not lay it
// across a harsh bend (hulls laid back from a corner sit crossways / off the road). Loose by design: scans
// forward from _from and returns the first index whose window -- back over the column length _backLen and one
// point forward -- turns less than CV_SNAP_STRAIGHT degrees in total; if the route stays curvy through the
// scan, returns the straightest index found. Indices clamped to the route interior.
private _fnc_straightAnchor = {
    params ["_from", "_backLen"];
    private _n = count _route;
    if (_n < 3) exitWith { (_from max 0) min ((_n - 1) max 0) };
    private _lo = (_from max 1) min (_n - 2);
    private _hi = (_from + CV_SNAP_SCAN) min (_n - 2);
    private _bestI = _lo;
    private _bestTurn = 1e9;
    for "_i" from _lo to _hi do {
        // Stop scanning once the anchor would sit more than CV_SNAP_AHEAD past where the lead is, so the snap
        // stays near the column instead of teleporting it forward to a distant straight; keep the best so far.
        // Measured from the lead's own index (_from - 2, since _from starts the search 2 points ahead), not the
        // search start, so the cap is a true distance-ahead-of-lead regardless of route point spacing.
        if (_i > _lo && {((_cum select _i) - (_cum select ((_from - 2) max 0))) > CV_SNAP_AHEAD}) exitWith {};
        // walk back from _i until _backLen of route is covered, then sum absolute heading change through _i+1
        private _acc = 0; private _k = _i;
        while { _k > 1 && {_acc < _backLen} } do {
            _acc = _acc + ((_route select _k) distance2D (_route select (_k - 1)));
            _k = _k - 1;
        };
        private _turn = 0;
        for "_j" from (_k + 1) to ((_i + 1) min (_n - 1)) do {
            private _a = (_route select (_j - 1)) getDir (_route select _j);
            private _b = (_route select _j) getDir (_route select ((_j + 1) min (_n - 1)));
            private _dd = abs (_b - _a);
            if (_dd > 180) then { _dd = 360 - _dd };
            _turn = _turn + _dd;
        };
        if (_turn < _bestTurn) then { _bestTurn = _turn; _bestI = _i };
        if (_turn <= CV_SNAP_STRAIGHT) exitWith {};
    };
    _bestI
};

// Teleport a wedged hull onto a clean spot: reject one fouled by another vehicle or a static and back off
// along the column axis until clear (the station sits on our own road route, so it almost always is), level
// any flipped hull and face it down the route, kill its momentum, and drop its path order for a fresh issue.
private _snapHull = {
    params ["_veh", "_pos", "_faceDir"];
    private _p = _pos;
    if (
        {alive _x && {_x != _veh}} count (nearestObjects [_p, ["LandVehicle"], 6]) > 0
        || {!((nearestTerrainObjects [_p, ["WALL", "FENCE", "ROCK", "TREE", "BUILDING"], 6]) isEqualTo [])}
    ) then {
        for "_k" from 1 to 4 do {
            private _cand = _p getPos [6 * _k, _faceDir + 180];
            if (
                {alive _x && {_x != _veh}} count (nearestObjects [_cand, ["LandVehicle"], 6]) == 0
                && {(nearestTerrainObjects [_cand, ["WALL", "FENCE", "ROCK", "TREE", "BUILDING"], 6]) isEqualTo []}
            ) exitWith { _p = _cand };
        };
    };
    if (surfaceIsWater _p) then { _p = [_p, 0, 30, 6, 0, 0.5, 0] call BIS_fnc_findSafePos };
    _veh setVectorDirAndUp [[sin _faceDir, cos _faceDir, 0], [0, 0, 1]];
    _veh setPosATL _p;
    _veh setVelocity [0, 0, 0];
    _veh setDriveOnPath [];
};

// Seed the first leg from a caller-supplied segmented route (see DUWS_convoy_route0 above): the hulls already
// sit on it, so drive it as-is instead of recomputing from the leader's position.
if (_route0 isNotEqualTo []) then {
    _segs = _route0;
    _segIdx = 0;
    _legStart = ((_segs select 0) select 0) select 0;   // first point of the first segment = the spawn point
    private _lastSegPts = (_segs select (count _segs - 1)) select 0;
    _legTargetCached = _lastSegPts select (count _lastSegPts - 1);   // last point = the leg's waypoint
    private _seg = [_segs, 0] call _fnc_segAt;
    _route      = _seg select 0;
    _legOffroad = _seg select 1;
    _segTarget  = _seg select 2;
    _cum        = _seg select 3;
    _crumbs = [];
};

// DEBUG (silent unless duws_log_level is raised to 4): a per-tick column line and a line per recovery event,
// so an RPT alone shows which hull lags and which tier fired. The level guard skips the format cost when off.
if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["convoy_drive start grp=%1", _group]] call fnc_log };

private _running = true;
while {
    _running
    && {!isNull _group}
    && {!(_group getVariable ["DUWS_convoy_stop", false])}
    && {!(_group getVariable ["DUWS_convoy_release", false])}
} do {
    // Driven hulls, read LIVE from the control group (the lead, plus any hull just joined -- the repaired
    // tank) and from every split follower group. Each hull is added once (only its driver adds it), so the
    // list is already distinct across both sources.
    private _hulls = [];
    { private _v = vehicle _x; if (_v != _x && {driver _v == _x} && {!(_v in _hulls)}) then { _hulls pushBack _v } } forEach units _group;
    {
        private _g = _x;
        if (!isNull _g) then {
            { private _v = vehicle _x; if (_v != _x && {driver _v == _x} && {!(_v in _hulls)}) then { _hulls pushBack _v } } forEach units _g;
        };
    } forEach (values _followers);

    // One-time config as a hull first appears: keep a bumped/immobilised crew aboard rather than dumped onto
    // the road to block the column; clear any inherited path order/road-lock (a peeled car); cache its config
    // top speed. forceFollowRoad stays FALSE throughout -- our route already includes the off-road stubs, and
    // a road-lock would forbid driving them.
    {
        private _id = netId _x;
        if (isNull (_seen getOrDefault [_id, objNull])) then {
            _seen set [_id, _x];
            _x setUnloadInCombat [false, false];
            _x allowCrewInImmobile true;
            _x setDriveOnPath [];
            _x forceSpeed -1;
            _x limitSpeed CV_NOLIMIT;
            _x forceFollowRoad false;
            private _t = getNumber (configOf _x >> "maxSpeed");
            _topspd set [_id, if (_t > 0) then { _t } else { 60 }];
        };
    } forEach _hulls;

    if ((_hulls findIf { alive _x && canMove _x }) < 0) then {
        _running = false;   // nothing left that can drive (patrol wiped, or the mission tore the group down)
    } else {
        private _live = _hulls select { alive _x && {canMove _x} && {alive (driver _x)} };

        // Self-managed leg: route to the current waypoint. Bootstrap the leg's start at the group leader's
        // position; thereafter each leg starts at the anchor the previous one reached (set on advance).
        if (_legStart isEqualTo []) then { _legStart = getPosATL (vehicle (leader _group)) };
        private _wpCount = count (waypoints _group);
        // Skip a placeholder waypoint: Arma gives every group an implicit waypoint 0 at its start whose
        // waypointPosition reads [0,0,0], and a wrapped/advanced index can land on an empty slot. Step past
        // any [0,0,0] to the next real waypoint, so the column never sits waiting on the map origin.
        while { _legIdx < _wpCount && {(waypointPosition [_group, _legIdx]) isEqualTo [0, 0, 0]} } do { _legIdx = _legIdx + 1 };
        private _wpTarget = if (_legIdx < _wpCount) then { waypointPosition [_group, _legIdx] } else { [0, 0, 0] };
        if (duws_log_level >= 4 && {!_dumped}) then {
            _dumped = true;
            ["DEBUG", "CONVOY", format ["waypoints grp=%1 wpCount=%2 legIdx=%3 target=%4", _group, _wpCount, _legIdx, _wpTarget]] call fnc_log;
        };

        // No live waypoint (index past the list, waiting on an appended one; or a group with none yet):
        // hold in place this tick rather than drive to the map origin.
        if (_wpTarget isEqualTo [0, 0, 0]) then {
            { _x forceSpeed 0 } forEach _live;
        } else {
            // (Re)build the leg's segmented route when the leg changed (segments emptied on advance) or the
            // waypoint drifted from what the segments were built for. Cache by the rounded [legStart, waypoint]
            // (5 m buckets) so a CYCLE patrol reuses each lap's legs. A rebuild starts at segment 0.
            if (_segs isNotEqualTo [] && {_wpTarget distance2D _legTargetCached > CV_REROUTE}) then { _segs = [] };
            if (_segs isEqualTo []) then {
                private _key = format ["%1_%2_%3_%4",
                    round ((_legStart select 0) / 5), round ((_legStart select 1) / 5),
                    round ((_wpTarget select 0) / 5), round ((_wpTarget select 1) / 5)];
                _segs = _cache getOrDefault [_key, []];
                if (_segs isEqualTo []) then {
                    // Hold the column while a fresh route computes. fnc_convoy_path yields across frames on a
                    // long search, so this forceSpeed 0 keeps the hulls put meanwhile; on a fast (single-frame)
                    // compute it is overwritten by the real speed later this tick, so the column never stops.
                    { _x forceSpeed 0 } forEach _live;
                    _segs = [_legStart, _wpTarget] call fnc_convoy_path;
                    _cache set [_key, _segs];
                };
                _legTargetCached = _wpTarget;
                _segIdx = 0;
                private _seg = [_segs, _segIdx] call _fnc_segAt;
                _route = _seg select 0; _legOffroad = _seg select 1; _segTarget = _seg select 2; _cum = _seg select 3;
                _crumbs = [];
                { _issued set [netId _x, -999]; _gapIssued set [netId _x, []] } forEach _live;   // fresh issue onto the new segment
                if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["route grp=%1 leg=%2 segs=%3 seg0=%4 pts=%5", _group, _legIdx, count _segs, ["road", "gap"] select _legOffroad, count _route]] call fnc_log };
            };

            // Convoy cruise = the slowest live hull's config top speed (a slow tracked hull sets the pace, a
            // fast escort does not run off), below top by CV_CRUISE_FRAC for catch-up headroom and capped at
            // CV_CRUISE_MAX so an all-wheeled column does not zoom. Catch-up is cruise + a small gain, never
            // past the hull's own top. Recomputed live so a hull joining/leaving reshapes the pace.
            private _topMin = 1e9;
            { _topMin = _topMin min (_topspd getOrDefault [netId _x, 60]) } forEach _live;
            if (_topMin >= 1e9) then { _topMin = 60 };
            private _cruise  = (_topMin * CV_CRUISE_FRAC) min CV_CRUISE_MAX;
            private _catchup = (_cruise + CV_CATCHUP_GAIN) min _topMin;

            // Gap leg: rebuild _route from the lead's crumb trail BEFORE progress/spacing, so every helper below
            // (progress, gap, recovery) runs over the crumbs exactly as it does over a road route. The lead used
            // here is last tick's (the re-pick below refines it once crumbs exist); at gap entry that is the road
            // leg's frontmost hull, which is right. Lay a crumb once it has advanced CV_STEP, cap the trail, and
            // rebuild the arc-length table _cum. On the first gap tick the trail is one point; followers hold or
            // aim straight at the lead until it lengthens (see the issue branch), which is the intended stagger.
            if (_legOffroad && {count _live > 0}) then {
                private _gl = _group getVariable ["cv_lead", objNull];
                if (isNull _gl || {!(_gl in _live)}) then { _gl = _live select 0 };
                if (_crumbs isEqualTo [] || {((getPosATL _gl) distance2D (_crumbs select (count _crumbs - 1))) >= CV_STEP}) then {
                    _crumbs pushBack (getPosATL _gl);
                    if (count _crumbs > CV_TRAIL) then { _crumbs deleteAt 0 };
                };
                _route = _crumbs;
                _cum = [0];
                for "_i" from 1 to (count _route - 1) do { _cum pushBack ((_cum select (_i - 1)) + ((_route select (_i - 1)) distance2D (_route select _i))) };
            };

            // Progress of every live hull along the route. Capture the hull before the call -- _progressOf runs
            // its own forEach, so relying on _x surviving across it is the nested-forEach clobber trap.
            private _prog = createHashMap;
            { private _v = _x; _prog set [netId _v, [getPosATL _v] call _progressOf] } forEach _live;

            // Lead = the frontmost hull (highest route progress). Pin it rather than track a separate lead; the
            // A3 leader is arbitrary, and after a death Arma may migrate it to a REAR hull. Re-pick only when
            // the current lead stops being a live driving hull. Between deaths nothing re-picks: no churn.
            private _lead = _group getVariable ["cv_lead", objNull];
            if (isNull _lead || {!(_lead in _live)}) then {
                private _front = objNull; private _bestP = -2;
                { private _p = _prog getOrDefault [netId _x, -1]; if (_p > _bestP) then { _bestP = _p; _front = _x } } forEach _live;
                if (isNull _front) then { _front = _live select 0 };
                _lead = _front;
                _group setVariable ["cv_lead", _lead];
            };
            // The lead MUST live in the control group: it keeps _group non-empty (so it is not auto-deleted and
            // the caller's `leader _group` / `behaviour (leader _group)` tests stay valid). A lead re-picked
            // from a follower group after the old front died is moved back in, and its emptied group falls away.
            if (!isNull _lead && {group (driver _lead) != _group}) then {
                { [_x] joinSilent _group } forEach ((crew _lead) select { group _x != _group });
                _followers set [netId _lead, grpNull];
            };
            if (!isNull _lead && {leader _group != driver _lead}) then { _group selectLeader (driver _lead) };

            // Split every non-lead hull whose crew still sits in the control group into its own single-hull
            // group: this catches the initial followers (first tick, all in the control group) and any mid-run
            // joiner (the repaired tank the caller folds in). Move ONLY the crew that is in the control group --
            // cargo riders belong to other groups (deny-armour's crew and rifle team ride the trucks) and must
            // stay put, or their win-census / team logic breaks. Once split, a follower's crew is out of the
            // control group, so it is never re-split. A hull split THIS tick is collected in _freshSplit so
            // the issue block below can defer its first drive order one tick (see there).
            private _freshSplit = [];
            {
                private _h = _x;
                private _crewIn = (crew _h) select { group _x == _group };
                if (_h != _lead && {!(_crewIn isEqualTo [])}) then {
                    private _g = createGroup (side _group);
                    _crewIn joinSilent _g;
                    _g setBehaviour (behaviour (leader _group));
                    _g setCombatMode (combatMode _group);
                    _g setFormation "COLUMN";
                    _g setSpeedMode "FULL";       // forceSpeed governs pace; keep the group's own cap permissive
                    _g deleteGroupWhenEmpty true; // a follower killed/peeled empties its group -> it falls away
                    _followers set [netId _h, _g];
                    _freshSplit pushBack (netId _h);
                };
            } forEach _live;

            if (!isNull _lead && {alive _lead}) then {
                private _leadId = netId _lead;
                private _liveFollowers = _live select { _x != _lead };
                private _leadProg = _prog getOrDefault [_leadId, -1];

                if (_regroup) then {
                    // TIER 1 REGROUP (view-safe, tried first): the lead HALTS and holds while every follower --
                    // now its own group, so it drives to formation without the merged-group AI fighting it --
                    // independently re-routes to its ordered slot behind the lead along the route. Slot N = how
                    // many followers sit further along than me, so the column keeps its order. Slots come off the
                    // route (they follow the road's curve); too little route behind the lead falls back to the
                    // lead's heading (NOT the destination bearing, which lays the column crossways on a bend).
                    // Resume once all are within CV_FORMED. The lead is off its path here (setDriveOnPath
                    // cleared), so forceSpeed 0 is safe -- it re-acquires the breadcrumb on resume (issued -> -999).
                    _lead forceSpeed 0;
                    if (_pathed getOrDefault [_leadId, false]) then { _lead setDriveOnPath []; _pathed set [_leadId, false] };
                    private _leadIdx = _leadProg max 0;
                    private _allFormed = true;
                    {
                        private _me = _x; private _meId = netId _me;
                        private _myProg = _prog getOrDefault [_meId, -1];
                        private _slotN = ({ (_prog getOrDefault [netId _x, -1]) > _myProg } count _liveFollowers) + 1;
                        private _slot = [_leadIdx, _slotN * CV_GAP_WANT] call _stationBack;
                        if (_slot isEqualTo []) then { _slot = (getPosATL _lead) getPos [_slotN * CV_GAP_WANT, (getDir _lead) + 180] };
                        if (_pathed getOrDefault [_meId, false]) then { _me setDriveOnPath []; _pathed set [_meId, false] };
                        _me doMove _slot;
                        private _off = _me distance2D _slot;
                        _me forceSpeed KMH((_off * 0.6) max 6 min _catchup);
                        if (_off > CV_FORMED) then { _allFormed = false };
                    } forEach _liveFollowers;
                    if (_allFormed) then {
                        { _issued set [netId _x, -999]; _gapIssued set [netId _x, []]; _pathed set [netId _x, false]; _stuck set [netId _x, 0] } forEach _live;
                        _regroup = false;
                        if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["regroup complete grp=%1", _group]] call fnc_log };
                    };
                } else {
                    // Issue drive orders. Road leg: put every hull -- lead included -- on its slice of the fixed
                    // route with setDriveOnPath. Gap leg: the lead pathfinds NATIVELY to the target (doMove) so it
                    // rounds the water/terrain the road search could not, and the followers replay its crumb trail
                    // ending at its live position -- tracing the exact ground it proved drivable, in column.
                    {
                        private _me = _x; private _meId = netId _me;
                        // Freshly split into its own group this tick: defer the first drive order one tick. A
                        // setDriveOnPath issued the same frame the driver changed group is dropped as the new
                        // group's FSM initialises, so the hull sits idle on a path it never received; forceSpeed
                        // on an un-pathed hull is only a ceiling and cannot restart it, and the column then waits
                        // on the Tier 2 teleport ~30 s in. Deferring one tick lets the order land once the group
                        // has settled. The lead is never split, so it always issues at once.
                        if !(_meId in _freshSplit) then {
                        if (_legOffroad && {_me == _lead}) then {
                            // Native lead across the gap. Clear any committed path first (a setDriveOnPath and a
                            // doMove fight), then aim at the segment end (the road it rejoins); re-issued each tick
                            // is cheap for doMove, and keeps it aimed as the segment/leg updates.
                            if (_pathed getOrDefault [_meId, false]) then { _me setDriveOnPath []; _pathed set [_meId, false] };
                            _me doMove _segTarget;
                        } else {
                            private _mp = _prog getOrDefault [_meId, -1];
                            private _startIdx = (_mp + 1) max 0;
                            if (_legOffroad) then {
                                // Follower on the crumb trail: drive the crumbs from just ahead of it through to the
                                // lead's LIVE position, so it chases the moving lead, not a stale trail end. Re-issue
                                // only when the slice shifts or the lead advanced CV_STEP (the trail grew) -- not every
                                // tick (that churns setDriveOnPath). Too few crumbs yet (gap entry): aim at the lead.
                                private _leadPos = getPosATL _lead;
                                private _iss = _gapIssued getOrDefault [_meId, []];
                                if (count _crumbs < 2 || {_mp < 0}) then {
                                    if (_pathed getOrDefault [_meId, false]) then { _me setDriveOnPath []; _pathed set [_meId, false] };
                                    _me doMove _leadPos;
                                    _gapIssued set [_meId, []];
                                } else {
                                    if (_iss isEqualTo [] || {(_iss select 0) != _startIdx} || {(_leadPos distance2D (_iss select 1)) >= CV_STEP}) then {
                                        private _slice = if (_startIdx <= (count _crumbs - 1)) then { _crumbs select [_startIdx] } else { [] };
                                        // setDriveOnPath alone (see the road branch): a doStop it cannot clear would
                                        // freeze the follower on the crumb trail.
                                        _me setDriveOnPath (_slice + [_leadPos]);
                                        _pathed set [_meId, true];
                                        _gapIssued set [_meId, [_startIdx, _leadPos]];
                                    };
                                };
                            } else {
                                // Road leg: issue the remaining fixed route once; forward progress needs no re-issue
                                // (that churns setDriveOnPath and stutters). Re-issue only when forced (leg change /
                                // recovery, -999) or when the hull REGRESSED behind its issued start. A wedged hull
                                // is handled by the recovery ladder (Tier 1 regroup / Tier 2 teleport), not by a
                                // per-tick re-issue -- the crawl floor keeps it on its committed path meanwhile.
                                private _last = _issued getOrDefault [_meId, -999];
                                if (_last == -999 || {_startIdx < _last}) then {
                                    private _slice = if (_startIdx <= (count _route - 1)) then { _route select [_startIdx] } else { [_route select (count _route - 1)] };
                                    // setDriveOnPath alone -- no doStop first. The path order overrides the group's
                                    // formation on its own, so the hull needs no stop to break formation; and a preceding
                                    // doStop is NOT cleared by setDriveOnPath, so it froze one hull per column, halted on
                                    // the spot until the recovery snap re-ran the same stop.
                                    _me setDriveOnPath _slice;
                                    _pathed set [_meId, true];
                                    _issued set [_meId, _startIdx];
                                };
                            };
                        };
                        };
                    } forEach _live;

                    private _maxGap = 0;
                    private _dbg = [];   // per-follower [id, gap, speed, stuck] this tick, emitted at level 4
                    {
                        private _me    = _x;
                        private _meId  = netId _me;
                        private _myProg = _prog getOrDefault [_meId, -1];

                        // The hull directly ahead: least route progress strictly greater than mine, else the lead.
                        private _ahead = _lead;
                        private _aheadProg = _leadProg;
                        {
                            if (_x != _me) then {
                                private _p = _prog getOrDefault [netId _x, -1];
                                if (_p > _myProg && {_p < _aheadProg}) then { _aheadProg = _p; _ahead = _x };
                            };
                        } forEach _liveFollowers;

                        // Along-route gap (real arc length via _cum), not straight-line: on a bend the hull
                        // ahead is nearer as-the-crow-flies than along the road, which would false-brake.
                        private _gap = if (_myProg < 0 || {_aheadProg < 0}) then { CV_GAP_WANT }
                            else { ((_cum select _aheadProg) - (_cum select _myProg)) max 0 };
                        if (_gap > _maxGap) then { _maxGap = _gap };

                        // Hold the gap with forceSpeed (a real SETPOINT on a setDriveOnPath hull). Cruise-anchored
                        // car-following: the setpoint is the shared convoy cruise (a GLOBAL reference every hull
                        // targets -- unlike matching the neighbour's own speed, which amplifies the lead's wobble
                        // rearward and leaves the tail oscillating), trimmed by the along-route spacing error and
                        // damped by the relative velocity. Rear-end easing and a no-overtake clamp use straight-line
                        // distance (the along-route gap cannot tell "just behind" from "just past" the hull ahead
                        // on the tick, so a fast closer could slip by). The setpoint is FLOORED at CV_CRAWL before
                        // it is applied: never 0, so a clamp cannot drop the hull off its committed path. forceSpeed
                        // is m/s -> KMH().
                        private _d        = _me distance2D _ahead;
                        private _aheadSpd = speed _ahead;         // km/h
                        private _mySpd    = speed _me;            // km/h
                        private _errGap   = _gap - CV_GAP_WANT;   // along-route; positive = too far back
                        private _fs = (_cruise + CV_GAP_KP * _errGap + CV_GAP_KD * (_aheadSpd - _mySpd)) max 0 min _catchup;
                        if (_d < CV_GAP_HARD) then { _fs = 0 };                          // rear-end easing (floored below)
                        if (_d < CV_GAP_WANT) then { _fs = _fs min (_aheadSpd max 0) };  // never outrun the hull ahead
                        _me forceSpeed KMH(_fs max CV_CRAWL);

                        // Wedge counter -> Tier 1: a hull meant to move (its pre-floor setpoint is above the halt
                        // threshold) but halted for CV_RECOVER_AT ticks is wedged. Trigger a whole-column regroup
                        // (the block above); the column waits while every hull re-routes to formation, then resumes.
                        // Cleared on real movement so a legitimate halt or a floored crawl never counts.
                        if (speed _me < CV_STUCK_KMH && {_fs > CV_STUCK_KMH}) then {
                            private _n = (_stuck getOrDefault [_meId, 0]) + 1;
                            _stuck set [_meId, _n];
                            if (_n >= CV_RECOVER_AT && {!_regroup}) then {
                                _regroup = true;
                                if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["regroup triggered by %1 (stuck %2)", _meId, _n]] call fnc_log };
                            };
                        } else {
                            _stuck set [_meId, 0];
                        };

                        if (duws_log_level >= 4) then {
                            _dbg pushBack [_meId, round _gap, round (speed _me), _stuck getOrDefault [_meId, 0]];
                        };
                    } forEach _liveFollowers;

                    // Lead paces the column: convoy cruise closed up, easing toward the crawl floor as the widest
                    // gap opens past CV_LAG_OK, so the column always waits for its tail. Floored (never 0) so the
                    // lead never drops off its own path while pacing. A lone hull with no column to hold runs
                    // uncapped at its own native top.
                    private _factor = ((CV_LAG_STOP - _maxGap) / (CV_LAG_STOP - CV_LAG_OK)) max 0 min 1;
                    if (_liveFollowers isEqualTo []) then { _lead forceSpeed -1 } else { _lead forceSpeed KMH((_cruise * _factor) max CV_CRAWL) };

                    // Lead Tier 1 recovery: a lead meant to move (not deliberately eased for the tail, not
                    // arriving) but wedged nudges itself one route hop forward with a native doMove -- native
                    // pathing from a free spot rounds a dynamic block; view-safe, and it re-acquires the
                    // breadcrumb next tick (issued -> -999). A lead the nudge cannot free is caught by Tier 2.
                    private _leadMoving = _factor > 0 && {(_lead distance2D _segTarget) > CV_ARRIVE};
                    if (_leadMoving && {speed _lead < CV_STUCK_KMH}) then {
                        private _n = (_stuck getOrDefault [_leadId, 0]) + 1;
                        _stuck set [_leadId, _n];
                        if (_n >= CV_RECOVER_AT) then {
                            private _aheadIdx = ((_leadProg max 0) + 3) min (count _route - 1);
                            private _pt = _route select _aheadIdx;
                            if (_pathed getOrDefault [_leadId, false]) then { _lead setDriveOnPath []; _pathed set [_leadId, false] };
                            _lead doMove _pt;
                            _issued set [_leadId, -999];
                            _stuck set [_leadId, 0];
                            if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["lead re-route %1", _leadId]] call fnc_log };
                        };
                    } else {
                        _stuck set [_leadId, 0];
                    };

                    if (duws_log_level >= 4) then {
                        ["DEBUG", "CONVOY", format ["grp=%1 lead=%2 leadSpd=%3 cruise=%4 factor=%5 maxGap=%6 followers(id,gap,spd,stuck)=%7",
                            _group, _leadId, round (speed _lead), round _cruise, (round (_factor * 100)) / 100, round _maxGap, _dbg]] call fnc_log;
                    };
                };

                // Segment / leg advance: the lead reached the current segment's end. More segments left in this
                // leg -> load the next one; this is where a road<->gap handoff happens (gap crossed, resume road,
                // or road driven up to the gap edge). No segments left -> the leg is done: advance the waypoint
                // (wrap on a CYCLE), route the next leg from the anchor just reached, and empty _segs so the
                // block above rebuilds it.
                if ((_lead distance2D _segTarget) < CV_ARRIVE) then {
                    if (_segIdx < (count _segs - 1)) then {
                        _segIdx = _segIdx + 1;
                        private _seg = [_segs, _segIdx] call _fnc_segAt;
                        _route = _seg select 0; _legOffroad = _seg select 1; _segTarget = _seg select 2; _cum = _seg select 3;
                        _crumbs = [];
                        { _issued set [netId _x, -999]; _gapIssued set [netId _x, []] } forEach _live;
                        if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["segment grp=%1 leg=%2 seg=%3/%4 mode=%5", _group, _legIdx, _segIdx, count _segs, ["road", "gap"] select _legOffroad]] call fnc_log };
                    } else {
                        _legStart = _wpTarget;
                        _legIdx = _legIdx + 1;
                        if (_legIdx < (count (waypoints _group)) && {(waypointType [_group, _legIdx]) == "CYCLE"}) then { _legIdx = 0 };
                        _segs = [];
                        _legOffroad = false;
                        _crumbs = [];
                    };
                };

                // TIER 2 (fallback): the whole column has sat frozen -- nothing moving, lead included -- for
                // CV_TELEPORT_AT ticks that Tier 1 could not free, AND no BLUFOR is within CV_TP_CLEAR to see it.
                // Realign the WHOLE convoy onto the breadcrumb in trail order, on a straight-anchored stretch
                // (never across a hard bend), and teleport it there. Runs in the regroup state too, so a regroup
                // that stalls out of sight escalates here; withheld while witnessed so the column never blinks in
                // the player's view -- Tier 1 keeps trying until it frees or the player leaves.
                if ((_lead distance2D _segTarget) > CV_ARRIVE && {(_live findIf { speed _x >= CV_STUCK_KMH }) < 0}) then {
                    _allStuck = _allStuck + 1;
                } else {
                    _allStuck = 0;
                };
                if (
                    _allStuck >= CV_TELEPORT_AT
                    && {(allUnits findIf { side _x == west && {alive _x} && {_x distance2D (getPosATL _lead) < CV_TP_CLEAR} }) < 0}
                ) then {
                    private _colLen = ((count _liveFollowers) + 1) * CV_GAP_WANT;
                    private _anchorIdx = [(_leadProg max 0) + 2, _colLen] call _fnc_straightAnchor;
                    private _anchor = _route select _anchorIdx;
                    private _face = if (_anchorIdx >= 1) then { (_route select (_anchorIdx - 1)) getDir _anchor } else { getDir _lead };
                    private _ordered = [_liveFollowers, [], { _prog getOrDefault [netId _x, -1] }, "DESCEND"] call BIS_fnc_sortBy;
                    if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["WHOLE-COLUMN SNAP grp=%1 (frozen %2 ticks, anchor=%3)", _group, _allStuck, _anchorIdx]] call fnc_log };
                    {
                        private _slot = [_anchorIdx, _forEachIndex * CV_GAP_WANT] call _stationBack;
                        if (_slot isEqualTo []) then { _slot = _anchor getPos [_forEachIndex * CV_GAP_WANT, _face + 180] };
                        [_x, _slot, _face] call _snapHull;
                        _issued set [netId _x, -999];
                        _gapIssued set [netId _x, []];
                        _pathed set [netId _x, false];
                        _stuck  set [netId _x, 0];
                    } forEach ([_lead] + _ordered);
                    _allStuck = 0;
                    _regroup = false;
                };
            };
        };
    };
    sleep CV_TICK;
};

// Exit -- teardown, or hand-off to combat on release. Rejoin every split follower into the control (lead)
// group so native AI fights as ONE column, not a scatter of singletons, then drop every path order and speed
// cap on every hull this loop ever configured so native AI drives them. On a combat release re-apply the
// group's current disposition (the caller sets COMBAT before releasing), which propagates it to the hulls
// just rejoined; on a teardown stop that is skipped (the mission is collecting the group anyway). limitSpeed
// reset must be a large value, not -1 (which never resets and forces a helicopter into reverse); CV_NOLIMIT
// is past any ground vehicle's top speed.
// Rejoin only into a control group that still exists: if the whole convoy died the group emptied and
// deleteGroupWhenEmpty (set by the callers) already reaped it, so there is nothing to rejoin into.
if (!isNull _group) then {
    {
        if (!isNull _x) then {
            (units _x) joinSilent _group;
            if (units _x isEqualTo []) then { deleteGroup _x };
        };
    } forEach (values _followers);
    if (_group getVariable ["DUWS_convoy_release", false] && {(units _group) isNotEqualTo []}) then {
        _group setBehaviour (behaviour (leader _group));
        _group setCombatMode (combatMode _group);
        _group setSpeedMode (speedMode _group);
    };
};
{ _x setDriveOnPath []; _x forceSpeed -1; _x limitSpeed CV_NOLIMIT; _x forceFollowRoad false } forEach (values _seen);
