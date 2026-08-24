// Locality: server -- spawn once the group has its move waypoint(s) or a CYCLE loop. The whole convoy
// reliability engine, group-shape agnostic.
//
// Arma's native vehicle route CALCULATION is the unreliable half of convoy driving: it wedges the lead on
// open ground and at junctions with nothing in the way. Driving a KNOWN polyline with setDriveOnPath is the
// reliable half. So this engine routes the road ITSELF (fnc_convoy_path) and puts EVERY hull -- lead
// included -- on that fixed polyline with setDriveOnPath. Nothing is left to native routing.
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
//   Spacing: every hull drives its slice of the route from its own position to the end. forceSpeed holds the
//   gap -- a proportional band around a target spacing (inside it match the hull ahead, outside run above or
//   below in proportion to the error), with a straight-line rear-end stop and a no-overtake clamp. The lead
//   paces the column at the slowest hull's top speed (capped to a sane road pace) and eases toward a halt as
//   the widest gap opens, so the column always waits for its tail.
//
//   Recovery for a hull the engine still wedges (a dynamic obstacle, a bad segment):
//     - out of the player's sight  -> teleport-snap it onto its route station, oriented, collision-checked
//     - in the player's sight      -> whole-column REGROUP: the lead halts and every follower drives
//                                     independently to its ordered slot behind the lead, then the column
//                                     resumes -- view-safe (they regroup, never blink)
//
// Leadership is pinned to the frontmost hull (highest route progress) and re-picked only when the front dies
// (Arma migrates leadership to an arbitrary survivor -- maybe a rear hull, which would trace the column
// backwards). One loop owns each group. Hulls are read live: one joining mid-run (the repaired tank) is
// picked up, one leaving (the peeled HVT car) is dropped, with no caller bookkeeping. Where the hulls must
// break and fight (the roving patrol), the caller sets DUWS_convoy_release; DUWS_convoy_stop ends the loop
// the same way at teardown -- both hand every hull back to native AI.
params ["_group"];

#define CV_TICK        1.5
#define CV_STUCK_KMH   3       // at or below this, treat a hull as halted
#define CV_RECOVER_AT  8       // ticks a hull sits wedged (~12 s) before recovery (snap out of sight / regroup in)
#define CV_FORMED      15      // a follower within this (m) of its slot counts as formed up during a regroup
#define CV_TELEPORT_AT 20      // ticks (~30 s) the WHOLE column stays deadlocked before the out-of-sight snap
#define CV_TP_CLEAR    300     // no BLUFOR within this (m) or an out-of-sight snap is withheld (regroup instead)
#define CV_ARRIVE      25      // lead within this of the leg waypoint -> the leg is done, advance to the next

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
#define CV_GAP_WANT    20      // target spacing to the hull ahead (m). Tighter than the spawn slot
                               // (fnc_convoy_layout, ~22 m): long escorts must not spawn bumper-to-bumper and
                               // explode, but the column closes to this once rolling.
#define CV_GAP_DEAD    5       // band half-width around CV_GAP_WANT: inside it a follower just matches the hull
                               // ahead (holds station); outside it the proportional term speeds up / slows down
#define CV_GAP_KP      1.5     // proportional gain, km/h per metre of spacing error, applied outside the band:
                               // farther than target -> run above the hull ahead to close, closer -> below it to
                               // reopen. A gentle ramp, NOT a cliff (flat-out catch-up then a hard-stop).
#define CV_GAP_HARD    4       // straight-line: closer than this, hard-stop -- backstop against rear-ending
#define CV_LAG_OK      40      // widest inter-hull gap tolerated at full cruise (m); past it the lead eases
#define CV_LAG_STOP    100     // at or past this the lead eases to a halt until the column closes up
#define CV_REROUTE     30      // leg waypoint drifted this far from the route's end -> recompute the route

private _route  = [];             // the current leg's drivable polyline (from fnc_convoy_path), start..dest
private _cum    = [0];            // cumulative arc length along _route: _cum#i = metres from _route#0 to #i
private _cache  = createHashMap;  // rounded [legStart,target] key -> a computed route (CYCLE laps reuse legs)
private _legIdx = 0;              // self-managed current waypoint index (we do not trust native completion)
private _legStart = [];           // where the current leg is routed FROM (lead spawn pos, then each anchor)
private _stuck  = createHashMap;  // netId -> consecutive halted ticks (per hull, lead included)
private _allStuck = 0;            // consecutive ticks the whole column is deadlocked (nothing moving)
private _issued = createHashMap;  // netId -> last slice start index handed to setDriveOnPath (-999 = force)
private _pathed = createHashMap;  // netId -> is a setDriveOnPath currently committed (clear before a doMove)
private _seen   = createHashMap;  // netId -> hull, every hull configured once (one-time setup + teardown reset)
private _topspd = createHashMap;  // netId -> config top speed (km/h), cached once: the convoy paces to the min
private _regroup = false;         // column-wide: while true the lead holds and all followers reform on slots
private _dumped = false;          // one-time level-4 dump of the waypoint list, so a stuck start is diagnosable

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
    // Driven hulls = every crewed vehicle whose driver is in this group, taken live so a hull joining or
    // leaving mid-run is followed without the caller tracking a list. Each hull is added once (only its
    // driver adds it), so the array is already distinct.
    private _hulls = [];
    { if (vehicle _x != _x && {driver (vehicle _x) == _x}) then { _hulls pushBack (vehicle _x) } } forEach units _group;

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
        private _target = if (_legIdx < _wpCount) then { waypointPosition [_group, _legIdx] } else { [0, 0, 0] };
        if (duws_log_level >= 4 && {!_dumped}) then {
            _dumped = true;
            ["DEBUG", "CONVOY", format ["waypoints grp=%1 wpCount=%2 legIdx=%3 target=%4", _group, _wpCount, _legIdx, _target]] call fnc_log;
        };

        // No live waypoint (index past the list, waiting on an appended one; or a group with none yet):
        // hold in place this tick rather than drive to the map origin.
        if (_target isEqualTo [0, 0, 0]) then {
            { _x forceSpeed 0 } forEach _live;
        } else {
            // Recompute the route only when the leg changed (route emptied on advance) or the waypoint drifted.
            // Cache by the rounded [legStart, target] (5 m buckets) so a CYCLE patrol reuses each lap's legs.
            if (_route isNotEqualTo [] && {(_route select (count _route - 1)) distance2D _target > CV_REROUTE}) then { _route = [] };
            if (_route isEqualTo []) then {
                private _key = format ["%1_%2_%3_%4",
                    round ((_legStart select 0) / 5), round ((_legStart select 1) / 5),
                    round ((_target   select 0) / 5), round ((_target   select 1) / 5)];
                private _cached = _cache getOrDefault [_key, []];
                if (_cached isEqualTo []) then {
                    // Hold the column while a fresh route computes. fnc_convoy_path yields across frames on a
                    // long search, so this forceSpeed 0 keeps the hulls put meanwhile; on a fast (single-frame)
                    // compute it is overwritten by the real speed later this tick, so the column never stops.
                    { _x forceSpeed 0 } forEach _live;
                    _cached = [_legStart, _target] call fnc_convoy_path;
                    _cache set [_key, _cached];
                };
                _route = _cached;
                _cum = [0];
                for "_i" from 1 to (count _route - 1) do {
                    _cum pushBack ((_cum select (_i - 1)) + ((_route select (_i - 1)) distance2D (_route select _i)));
                };
                { _issued set [netId _x, -999] } forEach _live;   // force a fresh path issue onto the new route
                if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["route grp=%1 leg=%2 pts=%3 len=%4", _group, _legIdx, count _route, round (_cum select (count _cum - 1))]] call fnc_log };
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
            if (!isNull _lead && {leader _group != driver _lead}) then { _group selectLeader (driver _lead) };

            if (!isNull _lead && {alive _lead}) then {
                private _leadId = netId _lead;
                private _liveFollowers = _live select { _x != _lead };
                private _leadProg = _prog getOrDefault [_leadId, -1];

                if (_regroup) then {
                    // IN-SIGHT REGROUP: the lead HALTS and holds while every follower drives independently to
                    // its ordered slot behind the lead along the route -- slot N = how many followers are
                    // further along than me, so the column keeps its order. Slots come off the route (they
                    // follow road curve); a route too short behind the lead falls back to the lead's heading
                    // (NOT the destination bearing, which lays the column crossways on a bend). Once all are
                    // within CV_FORMED of their slots the column resumes. View-safe: they regroup, never blink.
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
                        { _issued set [netId _x, -999]; _stuck set [netId _x, 0] } forEach _live;
                        _regroup = false;
                        if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["regroup complete grp=%1", _group]] call fnc_log };
                    };
                } else {
                    // Issue the route to EVERY hull (lead drives the whole remaining route; each follower from
                    // its own index). Slice starts one point ahead of the hull, forward-only, so setDriveOnPath
                    // never reverses it. Re-issue only when its start index changes (the route itself is fixed).
                    {
                        private _me = _x; private _meId = netId _me;
                        private _mp = _prog getOrDefault [_meId, -1];
                        private _startIdx = (_mp + 1) max 0;
                        private _slice = if (_startIdx <= (count _route - 1)) then { _route select [_startIdx] } else { [_route select (count _route - 1)] };
                        if ((_issued getOrDefault [_meId, -999]) != _startIdx) then {
                            _me setDriveOnPath _slice;
                            _issued set [_meId, _startIdx];
                            _pathed set [_meId, true];
                        };
                    } forEach _live;

                    private _maxGap = 0;
                    private _dbg = [];   // per-follower [id, gap, speed, stuck] this tick, emitted at level 4
                    {
                        private _me    = _x;
                        private _meId  = netId _me;
                        private _mePos = getPosATL _me;
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
                        private _aheadPos = getPosATL _ahead;

                        // Along-route gap (real arc length via _cum), not straight-line: on a bend the hull
                        // ahead is nearer as-the-crow-flies than along the road, which would false-brake.
                        private _gap = if (_myProg < 0 || {_aheadProg < 0}) then { CV_GAP_WANT }
                            else { ((_cum select _aheadProg) - (_cum select _myProg)) max 0 };
                        if (_gap > _maxGap) then { _maxGap = _gap };

                        // Hold the gap with forceSpeed (a real SETPOINT on a setDriveOnPath hull). Proportional
                        // band around CV_GAP_WANT on the straight-line distance: inside +/-CV_GAP_DEAD match the
                        // hull ahead's pace; outside, run above/below in proportion to the error. Far behind
                        // along-route -> flat catch-up (bend-safe). Rear-end hard-stop and a no-overtake clamp
                        // (the along-route gap cannot tell "just behind" from "just past" the hull ahead on the
                        // coarse tick, so a fast closer can slip by). forceSpeed is m/s -> KMH().
                        private _d        = _me distance2D _ahead;
                        private _aheadSpd = speed _ahead;   // km/h
                        private _err      = _d - CV_GAP_WANT;
                        private _fs = switch (true) do {
                            case (_d < CV_GAP_HARD):        { 0 };
                            case (_gap > CV_LAG_OK):        { _catchup };
                            case (abs _err <= CV_GAP_DEAD): { _aheadSpd min _cruise };
                            default                         { (_aheadSpd + CV_GAP_KP * _err) max 0 min _catchup };
                        };
                        if (_d < CV_GAP_WANT) then { _fs = _fs min (_aheadSpd max 0) };   // never outrun the hull ahead
                        _me forceSpeed KMH(_fs);

                        // Recovery: a hull meant to move (_fs above the halt threshold) but halted for
                        // CV_RECOVER_AT ticks is wedged. Out of the player's sight, teleport-snap it to its
                        // route station behind the hull ahead. In sight, trigger a whole-column regroup instead
                        // (view-safe). The counter clears on real movement, so a legitimate halt never counts.
                        if (speed _me < CV_STUCK_KMH && {_fs > CV_STUCK_KMH}) then {
                            private _n = (_stuck getOrDefault [_meId, 0]) + 1;
                            _stuck set [_meId, _n];
                            if (_n >= CV_RECOVER_AT) then {
                                private _witnessed = (allUnits findIf { side _x == west && {alive _x} && {_x distance2D _mePos < CV_TP_CLEAR} }) >= 0;
                                if (_witnessed) then {
                                    _regroup = true;
                                    if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["regroup triggered by %1 (stuck %2, witnessed)", _meId, _n]] call fnc_log };
                                } else {
                                    private _station = [_aheadProg, CV_GAP_WANT] call _stationBack;
                                    if (_station isEqualTo []) then { _station = _aheadPos getPos [CV_GAP_WANT, (getDir _ahead) + 180] };
                                    [_me, _station, _station getDir _aheadPos] call _snapHull;
                                    _pathed set [_meId, false];
                                    _issued set [_meId, -999];
                                    _stuck  set [_meId, 0];
                                    if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["snap %1 to station (was stuck %2)", _meId, _n]] call fnc_log };
                                };
                            };
                        } else {
                            _stuck set [_meId, 0];
                        };

                        if (duws_log_level >= 4) then {
                            _dbg pushBack [_meId, round _gap, round (speed _me), _stuck getOrDefault [_meId, 0]];
                        };
                    } forEach _liveFollowers;

                    // Lead paces the column: convoy cruise closed up, easing toward a halt as the widest gap
                    // opens past CV_LAG_OK, so the column always waits for its tail. A lone hull with no column
                    // to hold runs uncapped at its own native top.
                    private _factor = ((CV_LAG_STOP - _maxGap) / (CV_LAG_STOP - CV_LAG_OK)) max 0 min 1;
                    if (_liveFollowers isEqualTo []) then { _lead forceSpeed -1 } else { _lead forceSpeed KMH(_cruise * _factor) };

                    // Lead recovery: a lead meant to move (not deliberately halted for the tail, not arriving)
                    // but wedged. Out of sight, snap it forward onto a clean route point past the block; in
                    // sight, a short native doMove to a point ahead nudges it past -- view-safe, best effort.
                    private _leadMoving = _factor > 0 && {(_lead distance2D _target) > CV_ARRIVE};
                    if (_leadMoving && {speed _lead < CV_STUCK_KMH}) then {
                        private _n = (_stuck getOrDefault [_leadId, 0]) + 1;
                        _stuck set [_leadId, _n];
                        if (_n >= CV_RECOVER_AT) then {
                            private _aheadIdx = ((_leadProg max 0) + 3) min (count _route - 1);
                            private _pt = _route select _aheadIdx;
                            private _witnessed = (allUnits findIf { side _x == west && {alive _x} && {_x distance2D (getPosATL _lead) < CV_TP_CLEAR} }) >= 0;
                            if (_witnessed) then {
                                if (_pathed getOrDefault [_leadId, false]) then { _lead setDriveOnPath []; _pathed set [_leadId, false] };
                                _lead doMove _pt;
                            } else {
                                private _face = if (_aheadIdx >= 1) then { (_route select (_aheadIdx - 1)) getDir _pt } else { getDir _lead };
                                [_lead, _pt, _face] call _snapHull;
                                _pathed set [_leadId, false];
                                _issued set [_leadId, -999];
                            };
                            _stuck set [_leadId, 0];
                            if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["lead recover %1 (witnessed=%2)", _leadId, _witnessed]] call fnc_log };
                        };
                    } else {
                        _stuck set [_leadId, 0];
                    };

                    if (duws_log_level >= 4) then {
                        ["DEBUG", "CONVOY", format ["grp=%1 lead=%2 leadSpd=%3 cruise=%4 factor=%5 maxGap=%6 followers(id,gap,spd,stuck)=%7",
                            _group, _leadId, round (speed _lead), round _cruise, (round (_factor * 100)) / 100, round _maxGap, _dbg]] call fnc_log;
                    };

                    // Leg done: the lead reached the waypoint. Advance to the next; wrap to 0 on a CYCLE; the
                    // next leg routes from the anchor just reached. Emptying _route forces its recompute above.
                    if ((_lead distance2D _target) < CV_ARRIVE) then {
                        _legStart = _target;
                        _legIdx = _legIdx + 1;
                        if (_legIdx < (count (waypoints _group)) && {(waypointType [_group, _legIdx]) == "CYCLE"}) then { _legIdx = 0 };
                        _route = [];
                    };

                    // LAST RESORT: the whole column has sat deadlocked (nothing moving, lead included) for
                    // CV_TELEPORT_AT ticks and no BLUFOR is within CV_TP_CLEAR to witness it -- snap every hull
                    // onto the route ahead of the lead, in trail order, and resume. (A witnessed deadlock is
                    // handled by the regroup the follower recovery triggers instead.)
                    if ((_lead distance2D _target) > CV_ARRIVE && {(_live findIf { speed _x >= CV_STUCK_KMH }) < 0}) then {
                        _allStuck = _allStuck + 1;
                    } else {
                        _allStuck = 0;
                    };
                    if (
                        _allStuck >= CV_TELEPORT_AT
                        && {(allUnits findIf { side _x == west && {alive _x} && {_x distance2D (getPosATL _lead) < CV_TP_CLEAR} }) < 0}
                    ) then {
                        if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["WHOLE-COLUMN SNAP grp=%1 (deadlocked %2 ticks)", _group, _allStuck]] call fnc_log };
                        private _anchorIdx = ((_leadProg max 0) + 2) min (count _route - 1);
                        private _anchor = _route select _anchorIdx;
                        private _face = if (_anchorIdx >= 1) then { (_route select (_anchorIdx - 1)) getDir _anchor } else { getDir _lead };
                        private _ordered = [_liveFollowers, [], { _prog getOrDefault [netId _x, -1] }, "DESCEND"] call BIS_fnc_sortBy;
                        {
                            private _slot = [_anchorIdx, _forEachIndex * CV_GAP_WANT] call _stationBack;
                            if (_slot isEqualTo []) then { _slot = _anchor getPos [_forEachIndex * CV_GAP_WANT, _face + 180] };
                            [_x, _slot, _face] call _snapHull;
                            _issued set [netId _x, -999];
                            _stuck  set [netId _x, 0];
                        } forEach ([_lead] + _ordered);
                        _allStuck = 0;
                    };
                };
            };
        };
    };
    sleep CV_TICK;
};

// Teardown, or hand-off to combat on release: drop every path order and speed cap on every hull this loop
// ever configured, so native AI drives them. limitSpeed reset must be a large value, not -1 (which never
// resets and forces a helicopter into reverse); CV_NOLIMIT is past any ground vehicle's top speed.
{ _x setDriveOnPath []; _x forceSpeed -1; _x limitSpeed CV_NOLIMIT; _x forceFollowRoad false } forEach (values _seen);
