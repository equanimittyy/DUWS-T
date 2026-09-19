// Server-side: call once the group has waypoint(s) or a CYCLE loop. One control group in; native AI
// drives and fights it again on release or teardown.
// Native route calc wedges the lead at junctions, so the road is pre-routed (fnc_convoy_path) and every
// hull rides it via setDriveOnPath. Only each DRIVER gets disableAI "FSM" -- gunner/commander keep AI so
// the escort still fights -- and PATH/AUTOCOMBAT stay on: setDriveOnPath needs PATH, and the HVT-peel /
// deny-armour ambush tests read behaviour.
// Legs are self-managed (native waypoint completion isn't trusted); spacing holds via a forceSpeed band
// with a no-overtake clamp. Recovery escalates per wedged hull: pace governor -> path re-issue -> regroup
// -> teleport (seats by original _pos so a designed order, e.g. the HVT car's slot, survives). Leadership
// is pinned to the lowest FIXED position, not live progress, so a stalled lead can't hand off to a hull
// behind it.
// Hulls are read live: a joiner (repaired tank) is picked up, a leaver (peeled HVT car) dropped.
// DUWS_convoy_release/_stop hand every hull back to native AI.
params ["_group"];

// Flags this group as under scripted convoy control: without it, the OPFOR OP recon burst
// (DUWS_fnc_hardpointOPBurst) reveals BLUFOR map-wide, promoting the column out of SAFE and false-tripping
// a mission's under-attack test. Cleared at teardown, so a released group is fair game again.
_group setVariable ["DUWS_convoy_handled", true];

#define CV_TICK        0.5     // control period, kept short: forceSpeed is open-loop between ticks, and at
                               // ~1.5 s dead time approached the target gap and the tail oscillated.
#define CV_STUCK_KMH   3
#define CV_STUCK_MAX   30      // ticks (~15 s) the whole column may sit frozen before the teleport-snap fires;
                               // sized to let the softer path re-issue / regroup recovery run its course first.
#define CV_REGROUP_AT  10      // wedged ticks (~5 s) before the native-path regroup fires. Above CV_REISSUE so
                               // the cheap path re-commit gets first shot; well below CV_STUCK_MAX so the
                               // view-safe regroup is tried before the teleport.
#define CV_FORMED      15      // gap to the hull ahead within one slot + this (m) counts as "formed" during a
                               // regroup; all formed -> the column resumes.
#define CV_REISSUE     6       // wedged ticks (~3 s) before setDriveOnPath is re-committed, and retry cadence
                               // after: forceSpeed 0 (the bunching clamp) drops a hull onto native idle, where a
                               // later positive forceSpeed is only a ceiling and can't restart it. Gated on the
                               // wedge so a rolling hull is never re-issued.
#define CV_ARRIVE      25      // lead within this of the leg waypoint -> the leg is done, advance to the next
// Gap mode (a leg the road search could not connect): the lead pathfinds NATIVELY across it and followers
// replay its driven track (a crumb laid every CV_STEP, last CV_TRAIL kept). Native routing is trusted only
// here because the alternative is a blind straight line through whatever lies between the ends. The first
// successful crossing is cached (_gapCache) and replayed on later laps, so a CYCLE patrol proves each gap once.
#define CV_STEP        8       // lead must advance this far (m) before a new crumb is laid
#define CV_TRAIL       40      // crumbs kept (~320 m of track): longer than any column, short enough that a
                               // CYCLE patrol's looping track never snaps a follower onto a previous lap
#define CV_SNAP_SCAN   40      // teleport-snap: route points ahead of the lead scanned for a straight anchor
#define CV_SNAP_STRAIGHT 45    // teleport-snap: max heading change (deg) over the column span to count as
                               // straight; loose on purpose -- too tight sent the scan hunting for a
                               // near-perfect stretch, teleporting the column well past its actual spot.
#define CV_SNAP_AHEAD  60      // teleport-snap: cap (m) on how far ahead of the lead the anchor may sit, so the
                               // snap stays near the column instead of flinging it forward to a distant straight.

// forceSpeed takes m/s. If an in-game check (a truck given `forceSpeed 8` rolls at ~29 km/h) proves it
// is km/h instead, set CV_KMH2FS to 1.0 so km/h values pass straight through.
#define CV_KMH2FS      (1.0 / 3.6)
#define KMH(x)         ((x) * CV_KMH2FS)
#define CV_NOLIMIT     1e10    // limitSpeed reset ("no cap"): -1 does NOT reset (forces helis reverse); the
                               // default is 2*maxSpeed, so a value past any vehicle's top speed removes the cap

#define CV_CRUISE_FRAC 0.85    // convoy cruise = this fraction of the slowest hull's top speed, capped at
                               // CV_CRUISE_MAX. Below top on purpose: zero headroom (cruise == top) leaves
                               // small lags uncloseable and the column string-unstable.
#define CV_CRUISE_MAX  45      // hard ceiling on convoy cruise (km/h): config maxSpeed is a flat-out downhill
                               // figure (wheeled hulls ~90-110), far above a sane convoy pace. A genuinely slow
                               // tracked hull (top below this) still sets its own slower pace.
#define CV_CATCHUP_GAIN 20     // catch-up ceiling = cruise + this (km/h), never past the hull's own top: a
                               // full-top catch-up overshoots station into the stop-start it's meant to damp.
#define CV_GAP_WANT    20      // target spacing to the hull ahead (m); tighter than the spawn slot (~22 m, see
                               // fnc_convoy_slots) so long escorts don't spawn bumper-to-bumper and explode.
#define CV_GAP_KP      1.5     // spacing gain: km/h added to cruise per metre the along-route gap exceeds
                               // CV_GAP_WANT -- a gentle ramp, not a hard snap to target spacing.
#define CV_GAP_KD      0.7     // damping gain: km/h per km/h of closing speed. Brakes overshoot while closing,
                               // and feeds the tail forward when the lead accelerates instead of reacting late.
#define CV_GAP_HARD    4       // straight-line: closer than this, hard-stop -- backstop against rear-ending
#define CV_LAG_OK      28      // widest inter-hull gap tolerated at full cruise (m); past it the lead eases.
                               // Kept close to CV_GAP_WANT: a wider tolerance let the lead hold full cruise
                               // while a follower fell to ~2x target spacing before reacting -- catch-up headroom is finite.
#define CV_LAG_STOP    70      // at or past this the lead halts until the column closes up. The CV_LAG_OK..this
                               // ramp is deliberately narrow (~40 m) so the lead sheds speed steeply, not slowly.
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
private _pos    = createHashMap;  // netId -> FIXED convoy position (0 = front); ordering never re-derives from live progress
private _nextPos = 0;             // next fixed position to hand out: spawn batch front-to-back, then the rear for a joiner
private _regroup     = false;     // Tier 3 state: while true the column halts and every hull re-forms behind the front hull
private _regroupLead = objNull;   // the hull the regroup forms up behind (frozen frontmost by progress); re-picked only if it dies
private _regroupTicks = 0;        // ticks the current regroup has run; gates the doMove re-issue to CV_REISSUE cadence
private _allStuck    = 0;         // consecutive ticks the WHOLE column is frozen -- drives the Tier 4 teleport
private _dumped = false;          // one-time level-4 dump of the waypoint list, so a stuck start is diagnosable
// A caller that pre-seats its column ON the route hands it via DUWS_convoy_route0: the driver reuses it for the
// first leg and skips the spawn-ordering snap. A caller that doesn't gets the one-time snap instead.
private _route0 = _group getVariable ["DUWS_convoy_route0", []];
private _needInitOrder = (_route0 isEqualTo []);

// A leg's route is a list of SEGMENTS from fnc_convoy_path, each [points, "road"|"gap"]: _segs holds them,
// _segIdx the current one, _segTarget its end. "road" drives the fixed polyline via setDriveOnPath; "gap"
// (unbridgeable by the road search) has the lead pathfind natively while followers replay its crumb trail.
// This lets off-road complement the route instead of replacing it -- every follower/spacing/recovery helper
// runs unchanged over whichever _route the current segment sets.
// _legOffroad gates gap branches; _pathed tracks a committed setDriveOnPath (cleared before doMove);
// _gapIssued is the gap analogue of _issued; _legTargetCached is the waypoint the segments were built for.
private _segs       = [];
private _segIdx     = 0;
private _segTarget  = [];
private _legTargetCached = [];
private _legOffroad = false;
private _crumbs   = [];
private _pathed   = createHashMap;   // netId -> a setDriveOnPath is committed (clear before a doMove)
private _gapIssued = createHashMap;  // netId -> last gap issue [startIdx, leadPos]
// _gapTrail accumulates the WHOLE crossing (uncapped, unlike the CV_TRAIL crumb window), committed to
// _gapCache only once the column clears the gap -- a dead-ended line is never cached. _gapReplay = this gap is
// being driven from a cached trail (setDriveOnPath, no native re-cross); _gapSetupKey guards the once-per-gap
// cache lookup. Cached crossings are never invalidated: a setDriveOnPath hull still rounds a wreck newly on
// the line via its own local avoidance, and Tier 4 blinks past any residual block anyway.
private _gapCache  = createHashMap;  // gapKey -> full proven crossing trail (ends at the road-entry point)
private _gapTrail  = [];
private _gapReplay = false;
private _gapStart  = [];             // current segment's fixed first point; with _segTarget it keys the gap cache
private _gapSetupKey = "";           // "" = no gap crossing set up yet this leg

// Load segment _i of _segs -> [points, isGap, endPoint, cumulativeArcLengths, startPoint]. The caller assigns
// these to _route / _legOffroad / _segTarget / _cum / _gapStart; _segTarget and _gapStart are captured here
// because a gap segment overwrites _route with its crumb trail, so its ends cannot be re-read off _route later.
// startPoint keys the gap-trail cache (with endPoint) and must be the segment's fixed first point, not a crumb.
private _fnc_segAt = {
    params ["_theSegs", "_i"];
    private _seg  = _theSegs select _i;
    private _pts  = _seg select 0;
    private _cm   = [0];
    for "_k" from 1 to (count _pts - 1) do { _cm pushBack ((_cm select (_k - 1)) + ((_pts select (_k - 1)) distance2D (_pts select _k))) };
    [_pts, (_seg select 1) == "gap", _pts select (count _pts - 1), _cm, _pts select 0]
};

// Gap-trail cache key: the gap's fixed endpoints bucketed to 5 m (matching the road-route cache). Deterministic
// from fnc_convoy_path, so a CYCLE lap re-crossing the same gap resolves to the same key and reuses the trail.
private _fnc_gapKey = {
    params ["_a", "_b"];
    format ["%1_%2_%3_%4",
        round ((_a select 0) / 5), round ((_a select 1) / 5),
        round ((_b select 0) / 5), round ((_b select 1) / 5)]
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

// Pick a snap anchor on a relatively straight stretch, so realigning the column doesn't lay it across a harsh
// bend (hulls sit crossways off the road). Scans forward from _from for the first index whose window (back
// over _backLen, one point forward) turns less than CV_SNAP_STRAIGHT degrees total; falls back to the
// straightest index found. Indices clamped to the route interior.
private _fnc_straightAnchor = {
    params ["_from", "_backLen"];
    private _n = count _route;
    if (_n < 3) exitWith { (_from max 0) min ((_n - 1) max 0) };
    private _lo = (_from max 1) min (_n - 2);
    private _hi = (_from + CV_SNAP_SCAN) min (_n - 2);
    private _bestI = _lo;
    private _bestTurn = 1e9;
    for "_i" from _lo to _hi do {
        // Stop scanning once the anchor would sit more than CV_SNAP_AHEAD past the lead (keep the best found so far).
        // Measured from the lead's own index (_from - 2, since _from starts the search 2 points ahead) so the cap
        // is a true distance-ahead-of-lead regardless of route point spacing.
        if (_i > _lo && {((_cum select _i) - (_cum select ((_from - 2) max 0))) > CV_SNAP_AHEAD}) exitWith {};
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

// Teleport a wedged hull onto a clean spot: reject one fouled by another vehicle/static and back off along the
// column axis until clear (the station sits on our own route, so it almost always is); level a flipped hull,
// face it down-route, kill momentum, and drop its path order for a fresh issue.
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
    if (surfaceIsWater _p) then { _p = [_p, 30, 0, 6, 0.5] call fnc_safe_pos };
    _veh setVectorDirAndUp [[sin _faceDir, cos _faceDir, 0], [0, 0, 1]];
    _veh setPosATL _p;
    _veh setVelocity [0, 0, 0];
    _veh setDriveOnPath [];
};

// Seed the first leg from a caller-supplied segmented route (see DUWS_convoy_route0 above): the hulls already
// sit on it, so drive it as-is instead of recomputing from the leader's position and re-ordering the column.
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
    _gapStart   = _seg select 4;
    _crumbs = [];
    _gapSetupKey = ""; _gapTrail = []; _gapReplay = false;
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
    // Driven hulls = every crewed vehicle whose driver is in this group, taken live so a joiner/leaver is
    // followed without the caller tracking a list. Each hull is added once (only its driver adds it), so the
    // array is already distinct.
    private _hulls = [];
    { if (vehicle _x != _x && {driver (vehicle _x) == _x}) then { _hulls pushBack (vehicle _x) } } forEach units _group;

    // One-time config as a hull first appears: keep a bumped/immobilised crew aboard rather than dumped onto the
    // road (blocking the column); clear any inherited path order/road-lock (a peeled car); cache its config top
    // speed. forceFollowRoad stays FALSE throughout -- our route already includes off-road stubs, and a
    // road-lock would forbid driving them.
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
            // Only the driver's FSM is disabled -- gunner/commander keep AI and fight (see the header).
            (driver _x) disableAI "FSM";
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
        // Skip a placeholder waypoint: Arma gives every group an implicit waypoint 0 whose position reads
        // [0,0,0], and a wrapped/advanced index can land on an empty slot -- step past any [0,0,0] so the
        // column never sits waiting on the map origin.
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
            // (Re)build the leg's segmented route when the leg changed or the waypoint drifted from what the
            // segments were built for. Cached by rounded [legStart,waypoint] (5 m buckets) so a CYCLE patrol
            // reuses each lap's legs.
            if (_segs isNotEqualTo [] && {_wpTarget distance2D _legTargetCached > CV_REROUTE}) then { _segs = [] };
            if (_segs isEqualTo []) then {
                private _key = format ["%1_%2_%3_%4",
                    round ((_legStart select 0) / 5), round ((_legStart select 1) / 5),
                    round ((_wpTarget select 0) / 5), round ((_wpTarget select 1) / 5)];
                _segs = _cache getOrDefault [_key, []];
                if (_segs isEqualTo []) then {
                    // Hold the column while a fresh route computes: fnc_convoy_path yields across frames on a
                    // long search, so this forceSpeed 0 keeps hulls put meanwhile; a fast (single-frame) compute
                    // is overwritten by the real speed later this tick.
                    { _x forceSpeed 0 } forEach _live;
                    _segs = [_legStart, _wpTarget] call fnc_convoy_path;
                    _cache set [_key, _segs];
                };
                _legTargetCached = _wpTarget;
                _segIdx = 0;
                private _seg = [_segs, _segIdx] call _fnc_segAt;
                _route = _seg select 0; _legOffroad = _seg select 1; _segTarget = _seg select 2; _cum = _seg select 3; _gapStart = _seg select 4;
                _crumbs = [];
                _gapSetupKey = ""; _gapTrail = [];
                { _issued set [netId _x, -999]; _gapIssued set [netId _x, []] } forEach _live;   // fresh issue onto the new segment
                if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["route grp=%1 leg=%2 segs=%3 seg0=%4 pts=%5", _group, _legIdx, count _segs, ["road", "gap"] select _legOffroad, count _route]] call fnc_log };
            };

            // Convoy cruise = the slowest live hull's top speed (a fast escort doesn't run off); recomputed live
            // each tick so a hull joining or leaving reshapes the pace.
            private _topMin = 1e9;
            { _topMin = _topMin min (_topspd getOrDefault [netId _x, 60]) } forEach _live;
            if (_topMin >= 1e9) then { _topMin = 60 };
            private _cruise  = (_topMin * CV_CRUISE_FRAC) min CV_CRUISE_MAX;
            private _catchup = (_cruise + CV_CATCHUP_GAIN) min _topMin;

            // Rebuild _route from the lead's crumb trail BEFORE progress/spacing, so every helper below runs over
            // the crumbs exactly as it does over a road route. Lead here is last tick's (refined below once
            // crumbs exist). Lay a crumb once advanced CV_STEP, cap the trail, rebuild _cum; on the first gap
            // tick the trail is one point and followers aim straight at the lead until it lengthens -- the
            // intended stagger.
            if (_legOffroad && {count _live > 0}) then {
                // Once per gap entry, resolve the cache: a hit replays the proven trail (whole column rides it via
                // setDriveOnPath, no native re-cross); a miss crosses natively and accumulates a fresh trail to
                // cache on success.
                private _key = [_gapStart, _segTarget] call _fnc_gapKey;
                if (_key != _gapSetupKey) then {
                    _gapSetupKey = _key;
                    private _cached = _gapCache getOrDefault [_key, []];
                    _gapReplay = _cached isNotEqualTo [];
                    _gapTrail = [];
                    _crumbs = if (_gapReplay) then { +_cached } else { [] };
                    if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["gap %1 grp=%2 (%3, pts=%4)", _key, _group, ["native cross", "replay cached"] select _gapReplay, count _crumbs]] call fnc_log };
                };
                if (!_gapReplay) then {
                    // Native crossing: the lead lays the trail. Feed the CV_TRAIL follow-window (_crumbs, for the
                    // followers) AND the uncapped _gapTrail that is cached once the gap is cleared.
                    private _gl = _group getVariable ["cv_lead", objNull];
                    if (isNull _gl || {!(_gl in _live)}) then { _gl = _live select 0 };
                    private _glp = getPosATL _gl;
                    if (_crumbs isEqualTo [] || {(_glp distance2D (_crumbs select (count _crumbs - 1))) >= CV_STEP}) then {
                        _crumbs pushBack _glp;
                        _gapTrail pushBack _glp;
                        if (count _crumbs > CV_TRAIL) then { _crumbs deleteAt 0 };
                    };
                };
                _route = _crumbs;
                _cum = [0];
                for "_i" from 1 to (count _route - 1) do { _cum pushBack ((_cum select (_i - 1)) + ((_route select (_i - 1)) distance2D (_route select _i))) };
            };

            // Progress of every live hull along the route. Capture the hull before the call -- _progressOf runs
            // its own forEach, so relying on _x surviving across it is the nested-forEach clobber trap.
            private _prog = createHashMap;
            { private _v = _x; _prog set [netId _v, [getPosATL _v] call _progressOf] } forEach _live;

            // Fixed convoy position per hull (0 = front), assigned once, never re-derived from live progress: a
            // stalled or reversing hull keeps its slot instead of being reordered, and the teleport realign seats
            // everyone by this order rather than scrambled progress. The spawn batch all appears the first tick,
            // ordered by how the caller seated it (front = highest progress); a later joiner (the repaired deny
            // tank) takes the next rear slot.
            private _unassigned = _live select { isNil { _pos get (netId _x) } };
            if (_unassigned isNotEqualTo []) then {
                { _pos set [netId _x, _nextPos]; _nextPos = _nextPos + 1 } forEach
                    ([_unassigned, [], { _prog getOrDefault [netId _x, -1] }, "DESCEND"] call BIS_fnc_sortBy);
            };

            // Lead = the live hull with the lowest fixed position, not the frontmost by live progress: a stalled
            // or reversing lead must not hand its slot to a hull behind it (that hull would then drive a
            // backward route slice). Only the front hull's death advances the lead. cv_lead is read externally
            // (HVT's tracking marker).
            private _lead = objNull; private _bestPos = 1e9;
            { private _p = _pos getOrDefault [netId _x, 1e9]; if (_p < _bestPos) then { _bestPos = _p; _lead = _x } } forEach _live;
            if (isNull _lead) then { _lead = _live select 0 };
            _group setVariable ["cv_lead", _lead];
            if (!isNull _lead && {leader _group != driver _lead}) then { _group selectLeader (driver _lead) };

            if (!isNull _lead && {alive _lead}) then {
                private _leadId = netId _lead;
                private _liveFollowers = _live select { _x != _lead };
                private _leadProg = _prog getOrDefault [_leadId, -1];

                // TIER 3 REGROUP (native-path, view-safe): a follower wedged past CV_REGROUP_AT tripped _regroup
                // -- Tier 2's path re-issue couldn't free it. The column halts and every other hull native-
                // pathfinds up to close the gap on the hull ahead, re-forming behind the frozen front hull in
                // arrival order (renumbered on success). Native pathing -- dropped for normal driving -- is
                // trusted here only as a recovery nudge: it rounds a dynamic block a re-committed setDriveOnPath
                // cannot. Failure to close up escalates to the Tier 4 teleport, which seats by the ORIGINAL _pos
                // so the designed order (e.g. the HVT car's slot) survives.
                if (_regroup) then {
                    if (isNull _regroupLead || {!(_regroupLead in _live)}) then {
                        private _f = objNull; private _bp = -2;
                        { private _p = _prog getOrDefault [netId _x, -1]; if (_p > _bp) then { _bp = _p; _f = _x } } forEach _live;
                        _regroupLead = _f;
                    };
                    if (isNull _regroupLead) then {
                        _regroup = false;
                    } else {
                        // Front hull holds: clear its path so forceSpeed 0 is a true halt (a doMove/path would fight it).
                        _regroupLead forceSpeed 0;
                        if (_pathed getOrDefault [netId _regroupLead, false]) then { _regroupLead setDriveOnPath []; _pathed set [netId _regroupLead, false] };
                        private _reformFollowers = _live select { _x != _regroupLead };
                        private _allFormed = true;
                        // Re-issue the doMove on CV_REISSUE cadence (~3 s), not every tick: re-pathing every 0.5 s
                        // never settles (each call restarts the search) and would thrash faster than the road
                        // re-issue this escalated from. forceSpeed still governs the approach every tick; the move
                        // order persists between re-issues.
                        private _reissueNow = (_regroupTicks mod CV_REISSUE) == 0;
                        {
                            private _me = _x; private _meId = netId _me;
                            private _myProg = _prog getOrDefault [_meId, -1];
                            // Hull ahead = least progress strictly greater than mine, else the frozen front hull.
                            private _ahead = _regroupLead;
                            private _aheadProg = _prog getOrDefault [netId _regroupLead, -1];
                            {
                                private _p = _prog getOrDefault [netId _x, -1];
                                if (_p > _myProg && {_p < _aheadProg}) then { _aheadProg = _p; _ahead = _x };
                            } forEach _reformFollowers;
                            // Drive to CV_GAP_WANT behind the hull ahead along the route (heading-fallback off it
                            // when the route runs out). Clear any path first so the doMove is not fought.
                            private _slot = [_aheadProg max 0, CV_GAP_WANT] call _stationBack;
                            if (_slot isEqualTo []) then { _slot = (getPosATL _ahead) getPos [CV_GAP_WANT, (getDir _ahead) + 180] };
                            if (_reissueNow) then {
                                if (_pathed getOrDefault [_meId, false]) then { _me setDriveOnPath []; _pathed set [_meId, false] };
                                _me doMove _slot;
                            };
                            private _off = _me distance2D _slot;
                            _me forceSpeed KMH((_off * 0.6) max 6 min _catchup);
                            private _gap = if (_myProg < 0 || {_aheadProg < 0}) then { 0 } else { ((_cum select _aheadProg) - (_cum select _myProg)) max 0 };
                            if (_gap > CV_GAP_WANT + CV_FORMED) then { _allFormed = false };
                        } forEach _reformFollowers;
                        _regroupTicks = _regroupTicks + 1;
                        if (_allFormed) then {
                            private _ordered = [_live, [], { _prog getOrDefault [netId _x, -1] }, "DESCEND"] call BIS_fnc_sortBy;
                            { _pos set [netId _x, _forEachIndex] } forEach _ordered;
                            { _issued set [netId _x, -999]; _gapIssued set [netId _x, []]; _pathed set [netId _x, false]; _stuck set [netId _x, 0] } forEach _live;
                            // The renumber may move the front hull; adopt it as lead now, not a tick late -- leg
                            // advance, the teleport trigger, cv_lead, and leader _group (feeding the HVT marker)
                            // all read _lead below this point.
                            _lead = _ordered select 0;
                            _leadProg = _prog getOrDefault [netId _lead, -1];
                            _group setVariable ["cv_lead", _lead];
                            if (leader _group != driver _lead) then { _group selectLeader (driver _lead) };
                            _regroup = false; _regroupLead = objNull;
                            if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["regroup complete grp=%1 neworder=%2", _group, _ordered]] call fnc_log };
                        };
                    };
                } else {
                    // Issue drive orders. Road leg: every hull -- lead included -- gets its slice of the fixed
                    // route via setDriveOnPath. Gap leg, first crossing: the lead pathfinds NATIVELY (doMove) to
                    // round terrain the road search couldn't, and followers replay its crumb trail to its live
                    // position. Gap leg, replay: _route is the cached proven trail, so every hull drives it with
                    // setDriveOnPath like a road leg, no native re-cross.
                    {
                        private _me = _x; private _meId = netId _me;
                        if (_legOffroad && {!_gapReplay} && {_me == _lead}) then {
                            // Native lead across the gap: clear any committed path first (setDriveOnPath and doMove
                            // fight), then aim at the segment end -- cheap to re-issue each tick, keeping it aimed
                            // as the leg updates. A replayed gap skips this: the lead falls to the road branch and
                            // drives the cached fixed line like any hull.
                            if (_pathed getOrDefault [_meId, false]) then { _me setDriveOnPath []; _pathed set [_meId, false] };
                            _me doMove _segTarget;
                        } else {
                            private _mp = _prog getOrDefault [_meId, -1];
                            private _startIdx = (_mp + 1) max 0;
                            if (_legOffroad && !_gapReplay) then {
                                // Follower on the crumb trail: drive from just ahead of it through to the lead's
                                // LIVE position, so it chases the moving lead, not a stale trail end. Re-issue only
                                // when the slice shifts or the trail grew by CV_STEP (not every tick -- that churns
                                // setDriveOnPath). Too few crumbs yet (gap entry): aim straight at the lead.
                                private _leadPos = getPosATL _lead;
                                private _iss = _gapIssued getOrDefault [_meId, []];
                                if (count _crumbs < 2 || {_mp < 0}) then {
                                    if (_pathed getOrDefault [_meId, false]) then { _me setDriveOnPath []; _pathed set [_meId, false] };
                                    _me doMove _leadPos;
                                    _gapIssued set [_meId, []];
                                } else {
                                    if (_iss isEqualTo [] || {(_iss select 0) != _startIdx} || {(_leadPos distance2D (_iss select 1)) >= CV_STEP}) then {
                                        private _slice = if (_startIdx <= (count _crumbs - 1)) then { _crumbs select [_startIdx] } else { [] };
                                        // setDriveOnPath alone (see the road branch): a doStop it can't clear would
                                        // freeze this hull.
                                        _me setDriveOnPath (_slice + [_leadPos]);
                                        _pathed set [_meId, true];
                                        _gapIssued set [_meId, [_startIdx, _leadPos]];
                                    };
                                };
                            } else {
                                // Road leg: issue the remaining route once; forward progress needs no re-issue (churns
                                // setDriveOnPath). Re-issue only when forced (leg change/recovery, -999), REGRESSED
                                // behind its issued start, or WEDGED (see CV_REISSUE for why forceSpeed 0 strands a
                                // hull off its path). Cadence-gated so a rolling hull is never re-issued.
                                private _last = _issued getOrDefault [_meId, -999];
                                private _stuckTicks = _stuck getOrDefault [_meId, 0];
                                private _wedged = speed _me < CV_STUCK_KMH && {_stuckTicks >= CV_REISSUE} && {(_stuckTicks mod CV_REISSUE) == 0};
                                if (_last == -999 || {_startIdx < _last} || _wedged) then {
                                    private _slice = if (_startIdx <= (count _route - 1)) then { _route select [_startIdx] } else { [_route select (count _route - 1)] };
                                    // setDriveOnPath alone -- no doStop first: the path order overrides formation on
                                    // its own, and a preceding doStop is NOT cleared by setDriveOnPath, so it froze
                                    // one hull per column until the recovery snap re-ran the same stop.
                                    _me setDriveOnPath _slice;
                                    _pathed set [_meId, true];
                                    _issued set [_meId, _startIdx];
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

                        // Hull directly ahead = the next LOWER fixed position that's live, else the lead. Fixed
                        // order holds the column shape even when a stall scrambles live progress; its progress
                        // feeds the along-route gap below.
                        private _myPos = _pos getOrDefault [_meId, 1e9];
                        private _ahead = _lead;
                        private _aheadPos = -1;
                        {
                            if (_x != _me) then {
                                private _p = _pos getOrDefault [netId _x, -1];
                                if (_p < _myPos && {_p > _aheadPos}) then { _aheadPos = _p; _ahead = _x };
                            };
                        } forEach _liveFollowers;
                        private _aheadProg = _prog getOrDefault [netId _ahead, -1];

                        // Along-route gap (real arc length via _cum), not straight-line: on a bend the hull
                        // ahead is nearer as-the-crow-flies than along the road, which would false-brake.
                        private _gap = if (_myProg < 0 || {_aheadProg < 0}) then { CV_GAP_WANT }
                            else { ((_cum select _aheadProg) - (_cum select _myProg)) max 0 };
                        if (_gap > _maxGap) then { _maxGap = _gap };

                        // Hold the gap with forceSpeed (a real setpoint on a setDriveOnPath hull), cruise-anchored:
                        // the setpoint is the shared convoy cruise (a GLOBAL reference) trimmed by spacing error and
                        // closing-speed damping -- matching the neighbour's own speed instead would amplify the
                        // lead's wobble rearward and leave the tail oscillating. Hard-stop and the no-overtake clamp
                        // use straight-line distance, not along-route: the along-route gap can't tell "just behind"
                        // from "just past" the hull ahead on the tick, so a fast closer could slip by.
                        private _d        = _me distance2D _ahead;
                        private _aheadSpd = speed _ahead;         // km/h
                        private _mySpd    = speed _me;            // km/h
                        private _errGap   = _gap - CV_GAP_WANT;   // along-route; positive = too far back
                        private _fs = (_cruise + CV_GAP_KP * _errGap + CV_GAP_KD * (_aheadSpd - _mySpd)) max 0 min _catchup;
                        if (_d < CV_GAP_HARD) then { _fs = 0 };                          // rear-end hard-stop
                        if (_d < CV_GAP_WANT) then { _fs = _fs min (_aheadSpd max 0) };  // never outrun the hull ahead
                        _me forceSpeed KMH(_fs);

                        // Wedge counter: a hull meant to move (_fs above halt threshold) but halted is stuck; counts
                        // up per tick, cleared on real movement so a legitimate halt never counts. Past CV_REISSUE
                        // the road branch re-commits the path (Tier 2); past CV_REGROUP_AT this follower trips the
                        // whole-column regroup (Tier 3), backstopped by Tier 4.
                        if (speed _me < CV_STUCK_KMH && {_fs > CV_STUCK_KMH}) then {
                            private _n = (_stuck getOrDefault [_meId, 0]) + 1;
                            _stuck set [_meId, _n];
                            if (_n >= CV_REGROUP_AT && {!_regroup}) then {
                                _regroup = true; _regroupTicks = 0;
                                if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["regroup triggered by %1 (stuck %2)", _meId, _n]] call fnc_log };
                            };
                        } else {
                            _stuck set [_meId, 0];
                        };

                        if (duws_log_level >= 4) then {
                            _dbg pushBack [_meId, round _gap, round (speed _me), _stuck getOrDefault [_meId, 0]];
                        };
                    } forEach _liveFollowers;

                    // Lead paces the column: convoy cruise closed up, easing to a halt as the widest gap opens past
                    // CV_LAG_OK, so the column always waits for its tail. A lone hull with no column to hold runs
                    // uncapped at its own top.
                    private _factor = ((CV_LAG_STOP - _maxGap) / (CV_LAG_STOP - CV_LAG_OK)) max 0 min 1;
                    if (_liveFollowers isEqualTo []) then { _lead forceSpeed -1 } else { _lead forceSpeed KMH(_cruise * _factor) };

                    // Lead wedge counter: same as followers', but a lead deliberately eased to a halt (factor 0) or
                    // arriving is NOT counted -- only a lead that should be rolling but isn't. A wedged lead nudges
                    // ITSELF forward (one native doMove hop rounds a dynamic block) rather than halting the column
                    // into a regroup; a lead the nudge can't free is caught by the teleport.
                    private _leadMoving = _factor > 0 && {(_lead distance2D _segTarget) > CV_ARRIVE};
                    if (_leadMoving && {speed _lead < CV_STUCK_KMH}) then {
                        private _n = (_stuck getOrDefault [_leadId, 0]) + 1;
                        _stuck set [_leadId, _n];
                        if (_n >= CV_REGROUP_AT) then {
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

                // Segment/leg advance: the lead reached the current segment's end. More segments left -> load the next
                // (road<->gap handoff happens here). No segments left -> the leg is done: advance the waypoint (wrap
                // on CYCLE), route the next leg from the anchor just reached, empty _segs so the block above
                // rebuilds it. Skipped during a regroup: the lead must not swap _route out from under a column
                // mid-reform.
                if (!_regroup && {(_lead distance2D _segTarget) < CV_ARRIVE}) then {
                    // If the segment cleared was a gap crossed NATIVELY (not a replay), the trail is now proven:
                    // cache it (ending at the rejoin point) so later laps replay it instead of re-pathfinding. Only
                    // on a clean arrival -- a regroup skips this block, so a line the column couldn't hold is never
                    // cached.
                    if (_legOffroad && {!_gapReplay} && {count _gapTrail >= 2}) then {
                        _gapCache set [_gapSetupKey, _gapTrail + [_segTarget]];
                        if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["gap cached %1 grp=%2 (pts=%3)", _gapSetupKey, _group, count _gapTrail + 1]] call fnc_log };
                    };
                    if (_segIdx < (count _segs - 1)) then {
                        _segIdx = _segIdx + 1;
                        private _seg = [_segs, _segIdx] call _fnc_segAt;
                        _route = _seg select 0; _legOffroad = _seg select 1; _segTarget = _seg select 2; _cum = _seg select 3; _gapStart = _seg select 4;
                        _crumbs = [];
                        _gapSetupKey = ""; _gapTrail = [];
                        { _issued set [netId _x, -999]; _gapIssued set [netId _x, []] } forEach _live;
                        if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["segment grp=%1 leg=%2 seg=%3/%4 mode=%5", _group, _legIdx, _segIdx, count _segs, ["road", "gap"] select _legOffroad]] call fnc_log };
                    } else {
                        _legStart = _wpTarget;
                        _legIdx = _legIdx + 1;
                        if (_legIdx < (count (waypoints _group)) && {(waypointType [_group, _legIdx]) == "CYCLE"}) then { _legIdx = 0 };
                        _segs = [];
                        _legOffroad = false;
                        _crumbs = [];
                        _gapSetupKey = ""; _gapTrail = [];
                    };
                };

                // TIER 4 RECOVERY / spawn ordering (one snap, two triggers): realign the WHOLE convoy onto the route
                // in FIXED-position order and teleport it there. Fires after CV_STUCK_MAX ticks frozen (Tier 3
                // couldn't free it) and once at spawn (callers seat hulls in a rough line, not already trailing the
                // route). Whole-column, unconditional -- a mangled column is worse than a blink; the anchor is a
                // loosely straight stretch (_fnc_straightAnchor) so realigning doesn't cross a bend. Hulls seat by
                // FIXED position, not live progress, so a failed regroup's original designed order (e.g. the HVT
                // car's slot) is restored. The frozen counter counts only while the lead isn't merely arriving.
                if ((_lead distance2D _segTarget) > CV_ARRIVE && {(_live findIf { speed _x >= CV_STUCK_KMH }) < 0}) then {
                    _allStuck = _allStuck + 1;
                } else {
                    _allStuck = 0;
                };
                if (_allStuck >= CV_STUCK_MAX || _needInitOrder) then {
                    private _colLen = (count _live) * CV_GAP_WANT;
                    private _anchorIdx = [(_leadProg max 0) + 2, _colLen] call _fnc_straightAnchor;
                    private _anchor = _route select _anchorIdx;
                    private _face = if (_anchorIdx >= 1) then { (_route select (_anchorIdx - 1)) getDir _anchor } else { getDir _lead };
                    private _ordered = [_live, [], { _pos getOrDefault [netId _x, 1e9] }, "ASCEND"] call BIS_fnc_sortBy;
                    if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["WHOLE-COLUMN SNAP grp=%1 (%2, anchor=%3)", _group, (if (_needInitOrder) then { "spawn order" } else { format ["frozen %1 ticks", _allStuck] }), _anchorIdx]] call fnc_log };
                    _needInitOrder = false;
                    {
                        private _slot = [_anchorIdx, _forEachIndex * CV_GAP_WANT] call _stationBack;
                        if (_slot isEqualTo []) then { _slot = _anchor getPos [_forEachIndex * CV_GAP_WANT, _face + 180] };
                        [_x, _slot, _face] call _snapHull;
                        _issued set [netId _x, -999];
                        _gapIssued set [netId _x, []];   // _snapHull cleared the path; force a fresh issue in either mode
                        _pathed set [netId _x, false];
                        _stuck  set [netId _x, 0];
                    } forEach _ordered;
                    // A cached gap trail is NOT dropped here either (see the gap-trail cache note above); the
                    // teleport seated everyone, so drop any regroup in flight and reset the frozen counter.
                    _regroup = false; _regroupLead = objNull; _allStuck = 0;
                };
            };
        };
    };
    sleep CV_TICK;
};

// Teardown, or hand-off to combat on release: release every hull this loop ever configured back to native AI.
// Behaviour is the caller's throughout (nothing restored here); a peeling HVT car takes the same release
// mid-run (fnc_convoy_release_hull), so both paths undo convoy control identically.
{ [_x] call fnc_convoy_release_hull } forEach (values _seen);
if (!isNull _group) then { _group setVariable ["DUWS_convoy_handled", nil] };
