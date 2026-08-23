// Locality: server -- spawn once the group has its move waypoint (or a CYCLE loop). The whole convoy
// reliability engine, group-shape agnostic.
//
// Arma's vehicle route CALCULATION and its obstacle avoidance are both unreliable, so no follow method
// keeps a column intact on its own -- the engine wedges hulls on terrain at random. This engine therefore
// puts its weight on RECOVERY, not on a cleverer follow:
//
//   Lead: the front hull IS the A3 group leader, driven by native waypoints (a MOVE completes, a CYCLE
//   laps). Read live, so a mid-run destination swap (drive in, then home) needs no restart.
//
//   Followers: each REPLAYS the lead's crumb line with setDriveOnPath -- it drives the exact road the lead
//   drove, which is what makes a column. Driving each hull independently to the destination with doMove
//   instead let native pathing pick its own route per hull and scattered them, while the lead's pace governor
//   eased to a halt waiting for a column that never formed. The path runs to the lead's LIVE position, never a
//   fixed station a gap behind the hull ahead: the follower reaches a fixed end and idles at it, which stops
//   and starts the tail and reads as loose following. Spacing is held by forceSpeed -- on a setDriveOnPath
//   hull it is a real SETPOINT (the path drives, forceSpeed sets how fast along it), not the do-nothing
//   ceiling it is on a native-driven (doMove) hull. Spacing runs a proportional band around a target gap:
//   inside the band hold the hull ahead's pace, outside it run above/below in proportion to the error, so a
//   follower eases into and out of station instead of surging flat-out and then hard-stopping (an accordion).
//
//   Pace: the whole column cruises at the slowest hull's top speed (a slow tracked hull sets the pace; a fast
//   escort does not run off), below top for catch-up headroom and capped at a sane road pace (config maxSpeed
//   is the flat-out downhill figure, far too fast for a column). The lead eases toward a halt as the widest
//   inter-hull gap opens (CV_LAG_OK..CV_LAG_STOP), so the column always waits for its tail. This alone replaces
//   the old explicit regroup.
//
//   Recovery ladder for a hull the avoidance wedged (climbs only while it is meant to move but is not):
//     1. off-road detour     -- drop the replay path AND the road-lock for a few ticks and doMove the
//                               destination, so native pathing may route AROUND a real block off-road
//     2. per-hull reposition -- snap that one hull to its road station, un-flipped, when NO BLUFOR is
//                               within CV_TP_CLEAR to witness it
//     3. whole-column snap   -- the entire column deadlocked, again only out of sight
//
// Leadership is pinned to the frontmost hull and re-picked only when the front dies (Arma migrates it to an
// arbitrary survivor -- maybe a rear hull, which would trace the column backwards). One loop owns each group,
// so nothing else contends for who leads.
//
// The hulls are read live from the group each tick: a hull that joins mid-run (the repaired deny-armour tank)
// is picked up, one that leaves (the peeled HVT car) is dropped, with no caller bookkeeping. Where the hulls
// must break and fight instead of pressing on (the roving patrol), the caller sets DUWS_convoy_release on the
// group and native combat AI takes them back; DUWS_convoy_stop ends the loop the same way at teardown.
params ["_group"];

#define CV_TICK        1.5
#define CV_STEP        8       // lead must advance this far before a new breadcrumb is laid
#define CV_TRAIL       40      // keep only the last N crumbs (~320 m): longer than any column, short enough
                               // that a CYCLE patrol's looping track never snaps a follower onto an old lap
#define CV_STUCK_KMH   3       // at or below this, treat a hull as halted
#define CV_UNSTICK_AT  2       // ticks a hull sits wedged (confirm, ~3 s) before its road-lock drops to detour
#define CV_FREE_HOLD   5       // ticks (~7.5 s) the road-lock is held off so native pathing can route around
#define CV_REPOS_AT    6       // ticks a hull stays wedged (~9 s) before an out-of-sight per-hull reposition
#define CV_FINAL_HOP   120     // within this of the waypoint, drop the road-lock for the off-road approach
#define CV_TELEPORT_AT 20      // ticks (~30 s) the WHOLE column stays deadlocked before the out-of-sight snap
#define CV_TP_CLEAR    300     // no BLUFOR within this (m) or an out-of-sight reposition/snap is withheld

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
                               // reopen. A gentle ramp, NOT the old cliff (flat-out catch-up, then a sudden
                               // hard-stop) that surged the tail into a stop-start accordion.
#define CV_GAP_HARD    4       // straight-line: closer than this, hard-stop -- backstop against rear-ending
#define CV_LAG_OK      40      // widest inter-hull gap tolerated at full cruise (m); past it the lead eases
#define CV_LAG_STOP    100     // at or past this the lead eases to a halt until the column closes up

private _crumbs = [];             // the lead's driven track, oldest first: a coarse polyline of real ground
private _stuck  = createHashMap;  // netId -> consecutive halted ticks (per hull, lead included)
private _free   = createHashMap;  // netId -> ticks its road-lock stays off after a wedge, so it can detour
private _allStuck = 0;            // consecutive ticks the whole column is deadlocked (nothing moving)
private _issued = createHashMap;  // netId -> last replay key [startIdx, leadPos]; [] forces a fresh setDriveOnPath
private _pathed = createHashMap;  // netId -> is a setDriveOnPath currently committed (clear it before a doMove)
private _seen   = createHashMap;  // netId -> hull, every hull configured once (one-time setup + teardown reset)
private _topspd = createHashMap;  // netId -> config top speed (km/h), cached once: the convoy paces to the min

// Nearest crumb index to a position = the hull's progress along the track. -1 while the track is empty.
private _progressOf = {
    params ["_pos"];
    private _best = -1; private _bestD = 1e11;
    { private _d = _pos distance2D _x; if (_d < _bestD) then { _bestD = _d; _best = _forEachIndex } } forEach _crumbs;
    _best
};

// A STATION point: CV_GAP_WANT behind a hull along the crumb trail, plus the crumb index at or just older than
// it. Used to place a wedged hull back in formation on the road (the recovery reposition), NOT for normal
// driving. Returns [] when the trail is too short to reach the gap (caller uses a straight-line fallback).
private _stationBehind = {
    params ["_fromPos", "_fromIdx"];   // ahead hull's position and its crumb index (count _crumbs for the lead)
    private _prev = _fromPos;
    private _acc = 0;
    private _res = [];
    for "_i" from ((_fromIdx - 1) min (count _crumbs - 1)) to 0 step -1 do {
        private _c = _crumbs select _i;
        private _seg = _prev distance2D _c;
        if (_acc + _seg >= CV_GAP_WANT) exitWith {
            private _t = if (_seg > 0) then { (CV_GAP_WANT - _acc) / _seg } else { 0 };
            _res = [[(_prev select 0) + ((_c select 0) - (_prev select 0)) * _t,
                     (_prev select 1) + ((_c select 1) - (_prev select 1)) * _t, 0], _i];
        };
        _acc = _acc + _seg;
        _prev = _c;
    };
    _res
};

// DEBUG (silent unless duws_log_level is raised to 4): a per-tick line for the column and a line per recovery
// event, so an RPT alone shows which hull lags -- its gap, speed, stuck count -- and which tier fired, without
// a live repro. The level guard skips the format cost when off.
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
    // the road to block the column, and clear any path order the hull inherited from a previous loop (a
    // peeled car) so it does not keep tracing the old loop's track instead of its new waypoint.
    {
        private _id = netId _x;
        if (isNull (_seen getOrDefault [_id, objNull])) then {
            _seen set [_id, _x];
            _x setUnloadInCombat [false, false];
            _x allowCrewInImmobile true;
            _x setDriveOnPath [];
            _x forceSpeed -1;
            _x limitSpeed CV_NOLIMIT;
            private _t = getNumber (configOf _x >> "maxSpeed");
            _topspd set [_id, if (_t > 0) then { _t } else { 60 }];
        };
    } forEach _hulls;

    if ((_hulls findIf { alive _x && canMove _x }) < 0) then {
        _running = false;   // nothing left that can drive (patrol wiped, or the mission tore the group down)
    } else {
        private _wpPos = waypointPosition [_group, currentWaypoint _group];

        // A group with no live move waypoint reports [0,0,0]; driving toward it would send the column to the
        // map origin, so idle this tick until a real destination exists.
        if (_wpPos isNotEqualTo [0, 0, 0]) then {
            private _live = _hulls select { alive _x && {canMove _x} && {alive (driver _x)} };

            // Convoy cruise = the slowest live hull's config top speed (a slow tracked hull sets the pace, a
            // fast escort does not run off), taken below top by CV_CRUISE_FRAC for catch-up headroom and capped
            // at CV_CRUISE_MAX so an all-wheeled column does not zoom at the absurd config-max figure. Catch-up
            // is cruise + a small gain, never past the hull's own top. Recomputed live so a hull joining/leaving
            // reshapes the pace.
            private _topMin = 1e9;
            { _topMin = _topMin min (_topspd getOrDefault [netId _x, 60]) } forEach _live;
            if (_topMin >= 1e9) then { _topMin = 60 };
            private _cruise  = (_topMin * CV_CRUISE_FRAC) min CV_CRUISE_MAX;
            private _catchup = (_cruise + CV_CATCHUP_GAIN) min _topMin;

            // Progress of every live hull along the trail (nearest crumb index): follower spacing, and
            // picking a replacement front if the current one dies. Capture the hull before the call --
            // _progressOf runs its own forEach, so relying on _x surviving across it is the nested-forEach
            // clobber trap.
            private _prog = createHashMap;
            { private _v = _x; _prog set [netId _v, [getPosATL _v] call _progressOf] } forEach _live;

            // The front vehicle IS the A3 group leader -- leadership is arbitrary here, so we pin it to the
            // front rather than track a separate lead. Re-pick only when the current front stops being a live
            // driving hull (it died, or its driver was shot out onto foot); Arma will have migrated leadership
            // to an arbitrary survivor -- maybe a REAR hull, which would make every hull ahead trace the trail
            // backwards -- so we choose the frontmost ourselves. With crumbs that is the highest trail
            // progress; before the first crumbs (spawn) it is the hull nearest the destination, since the
            // column is strung along the road toward it. Between deaths nothing re-picks: no per-tick churn.
            private _lead = _group getVariable ["cv_lead", objNull];
            if (isNull _lead || {!(_lead in _live)}) then {
                private _front = objNull;
                if (count _crumbs >= 2) then {
                    private _bestP = -2;
                    { private _p = _prog getOrDefault [netId _x, -1]; if (_p > _bestP) then { _bestP = _p; _front = _x } } forEach _live;
                } else {
                    private _bestD = 1e11;
                    { private _d = _x distance2D _wpPos; if (_d < _bestD) then { _bestD = _d; _front = _x } } forEach _live;
                };
                _lead = _front;
                _group setVariable ["cv_lead", _lead];
            };
            // Keep the A3 leader pinned to our front so native waypoints drive it; selectLeader only fires
            // when Arma has drifted leadership (right after a death), so it is idempotent otherwise.
            if (!isNull _lead && {leader _group != driver _lead}) then { _group selectLeader (driver _lead) };

            if (!isNull _lead && {alive _lead}) then {
                private _leadId = netId _lead;
                private _liveFollowers = _live select { _x != _lead };

                // Lay a breadcrumb once the lead has advanced far enough, so the track is a coarse driven
                // polyline of proven-drivable ground -- not a per-tick spray of points. It defines the on-road
                // station each follower holds and the slot a recovery repositions to. Capped to the last stretch.
                if (_crumbs isEqualTo [] || {(_lead distance2D (_crumbs select (count _crumbs - 1))) >= CV_STEP}) then {
                    _crumbs pushBack (getPosATL _lead);
                    if (count _crumbs > CV_TRAIL) then { _crumbs deleteAt 0 };
                };

                private _leadNear = (_lead distance2D _wpPos) < CV_FINAL_HOP;
                private _leadProg = count _crumbs;   // the lead is ahead of every crumb

                // Road-lock the lead for the long haul (native route calc still picks the road; forceFollowRoad
                // only forbids leaving it, where the AI's obstacle handling is worst); drop it in the final hop
                // for an off-road objective, and while an unstick window holds so a wedged lead may detour.
                private _lf = _free getOrDefault [_leadId, 0];
                if (_lf > 0) then { _free set [_leadId, _lf - 1] } else { _lead forceFollowRoad (!_leadNear) };

                private _maxGap = 0;
                private _dbg = [];   // per-follower [id, gap, speed, stuck, free] this tick, emitted at level 4
                {
                    private _me    = _x;
                    private _meId  = netId _me;
                    private _mePos = getPosATL _me;
                    private _myProg = _prog get _meId;

                    // The hull directly ahead: least trail progress strictly greater than mine, else the lead.
                    private _ahead = _lead;
                    private _aheadProg = _leadProg;
                    {
                        if (_x != _me) then {
                            private _p = _prog get (netId _x);
                            if (_p > _myProg && {_p < _aheadProg}) then { _aheadProg = _p; _ahead = _x };
                        };
                    } forEach _liveFollowers;
                    private _aheadPos = getPosATL _ahead;

                    // Along-track gap (crumb-index difference x step), not straight-line: on a bend the hull
                    // ahead is nearer as-the-crow-flies than along the road, which would false-trigger braking.
                    private _gap = if (_myProg < 0) then { CV_GAP_WANT } else { ((_aheadProg - _myProg) * CV_STEP) max 0 };
                    if (_gap > _maxGap) then { _maxGap = _gap };

                    // Follow the lead's proven-drivable line by REPLAYING its crumbs with setDriveOnPath: the
                    // followers trace the exact road the lead drove, which is what makes a column. doMove to the
                    // destination instead let each hull pathfind its own way and scattered them while the lead's
                    // pace governor eased to a halt waiting for a column that never formed. The path runs from the
                    // crumb just ahead of this hull through every forward crumb to the lead's LIVE position, ending
                    // at the moving lead -- NOT a fixed station a gap behind the hull ahead, which the follower
                    // reaches and idles at (the stop-start that read as loose following). Re-issue only when the
                    // slice shifts or the lead has advanced >= CV_STEP. Road-lock rides the _free gate: on for the
                    // haul, off in the final hop or while an unstick window holds, when the detour owns the hull.
                    private _ff = _free getOrDefault [_meId, 0];
                    if (_ff > 0) then {
                        _free set [_meId, _ff - 1];
                    } else {
                        _me forceFollowRoad (!_leadNear);
                        if (count _crumbs < 2 || {_myProg < 0}) then {
                            if (_pathed getOrDefault [_meId, false]) then { _me setDriveOnPath []; _pathed set [_meId, false] };
                            _me doMove (getPosATL _lead);   // no trail yet (spawn): aim at the lead directly
                            _issued set [_meId, []];
                        } else {
                            private _startIdx = _myProg + 1;
                            private _slice = if (_startIdx <= (count _crumbs - 1)) then { _crumbs select [_startIdx] } else { [] };
                            private _leadLive = getPosATL _lead;
                            private _iss = _issued getOrDefault [_meId, []];
                            if (
                                _iss isEqualTo []
                                || {(_iss select 0) != _startIdx}
                                || {(_lead distance2D (_iss select 1)) >= CV_STEP}
                            ) then {
                                _me setDriveOnPath (_slice + [_leadLive]);
                                _issued set [_meId, [_startIdx, _leadLive]];
                                _pathed set [_meId, true];
                            };
                        };
                    };

                    // Hold the gap with forceSpeed. On a setDriveOnPath hull forceSpeed is a real SETPOINT -- the
                    // path drives, forceSpeed sets how fast along it -- so it both closes a gap and holds one; the
                    // "ceiling that cannot make a stalled hull go" failure is the NATIVE-driven (doMove) case, not
                    // this. A proportional band around CV_GAP_WANT: inside +/-CV_GAP_DEAD hold the hull ahead's
                    // pace (station); outside, run above/below it in proportion to the spacing error, so a follower
                    // eases into and out of station instead of the old flat-out-then-hard-stop that surged the tail
                    // into an accordion. The band and rear-end guard use the straight-line distance (the real
                    // spacing and collision measure); the gross catch-up override keys on the along-track gap
                    // instead, since a bend puts the hull ahead nearer as-the-crow-flies than along the road and
                    // would false-brake a genuinely-lagging tail. Bounded by the convoy cruise/catch-up. m/s -> KMH().
                    private _d        = _me distance2D _ahead;
                    private _aheadSpd = speed _ahead;   // km/h
                    private _err      = _d - CV_GAP_WANT;
                    private _fs = switch (true) do {
                        case (_d < CV_GAP_HARD):        { 0 };                                        // rear-end backstop
                        case (_gap > CV_LAG_OK):        { _catchup };                                 // far behind (bend-safe): close it
                        case (abs _err <= CV_GAP_DEAD): { _aheadSpd min _cruise };                    // in the band: hold station
                        default                         { (_aheadSpd + CV_GAP_KP * _err) max 0 min _catchup };
                    };
                    _me forceSpeed KMH(_fs);

                    // Per-hull recovery, since obstacle avoidance cannot be trusted to free a wedge. The counter
                    // climbs only while the hull is meant to move (_fs above the halt threshold) but is not, so a
                    // legitimate halt (tucked behind a stopped hull -> _fs low) never counts. After a short confirm:
                    // drop the replay path and the road-lock and doMove the destination, so native pathing may route
                    // off-road around the block; the _free window keeps the replay off meanwhile. If it stays wedged
                    // and no BLUFOR is close enough to witness it, snap that one hull onto its station slot.
                    if (speed _me < CV_STUCK_KMH && {_fs > CV_STUCK_KMH}) then {
                        private _n = (_stuck getOrDefault [_meId, 0]) + 1;
                        _stuck set [_meId, _n];
                        if (_n == CV_UNSTICK_AT) then {
                            _free set [_meId, CV_FREE_HOLD];
                            _me forceFollowRoad false;
                            if (_pathed getOrDefault [_meId, false]) then { _me setDriveOnPath []; _pathed set [_meId, false] };
                            _me doMove _wpPos;
                            _issued set [_meId, []];
                            if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["unstick %1: off-road detour (stuck %2)", netId _me, _n]] call fnc_log };
                        };
                        if (
                            _n >= CV_REPOS_AT
                            && {(allUnits findIf { side _x == west && {alive _x} && {_x distance2D _mePos < CV_TP_CLEAR} }) < 0}
                        ) then {
                            // Reposition target: the station a gap behind the hull ahead, on the crumb trail; a
                            // short trail falls back to a straight line a gap back from the ahead hull.
                            private _stRes = [_aheadPos, _aheadProg] call _stationBehind;
                            private _slot = if (_stRes isEqualTo []) then { _aheadPos getPos [CV_GAP_WANT, (getDir _ahead) + 180] } else { _stRes select 0 };
                            if (surfaceIsWater _slot) then { _slot = [_slot, 0, 30, 6, 0, 0.5, 0] call BIS_fnc_findSafePos };
                            private _face = [_slot, _aheadPos] call BIS_fnc_dirTo;
                            _me setVectorDirAndUp [[sin _face, cos _face, 0], [0, 0, 1]];
                            _me setPosATL _slot;
                            _me setVelocity [0, 0, 0];
                            _me setDriveOnPath [];
                            _pathed set [_meId, false];
                            _stuck set [_meId, 0];
                            _free set [_meId, 0];
                            _issued set [_meId, []];
                            if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["reposition %1 to station (was stuck %2)", netId _me, _n]] call fnc_log };
                        };
                    } else {
                        _stuck set [_meId, 0];
                    };

                    if (duws_log_level >= 4) then {
                        _dbg pushBack [netId _me, round _gap, round (speed _me), _stuck getOrDefault [_meId, 0], _free getOrDefault [_meId, 0]];
                    };
                } forEach _liveFollowers;

                // Lead speed governs the column pace: it runs at the convoy cruise (the slowest hull's top speed,
                // less the catch-up headroom) closed up, easing toward a halt as the widest inter-hull gap opens
                // past CV_LAG_OK, so the column always waits for its tail. This replaces the old explicit regroup
                // -- the lead simply holds while stragglers close, and the recovery ladder frees a wedged hull. A
                // lead with no followers is a lone hull with no column to hold, so it runs uncapped at native top.
                private _factor = ((CV_LAG_STOP - _maxGap) / (CV_LAG_STOP - CV_LAG_OK)) max 0 min 1;
                if (_liveFollowers isEqualTo []) then { _lead forceSpeed -1 } else { _lead forceSpeed KMH(_cruise * _factor) };

                // Lead unstick: the same off-road-permission tier as a follower. The lead is never repositioned
                // alone (it anchors the column); a lead wedge that off-road cannot clear stalls the whole column,
                // which the last-resort snap then frees. Only while it is meant to move and on the long haul.
                if (_factor > 0 && {!_leadNear} && {speed _lead < CV_STUCK_KMH}) then {
                    private _n = (_stuck getOrDefault [_leadId, 0]) + 1;
                    _stuck set [_leadId, _n];
                    if (_n >= CV_UNSTICK_AT) then {
                        _free set [_leadId, CV_FREE_HOLD];
                        _lead forceFollowRoad false;
                        _lead doMove _wpPos;
                        _stuck set [_leadId, 0];
                        if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["lead unstick %1: off-road detour", netId _lead]] call fnc_log };
                    };
                } else {
                    _stuck set [_leadId, 0];
                };

                if (duws_log_level >= 4) then {
                    ["DEBUG", "CONVOY", format ["grp=%1 lead=%2 leadSpd=%3 cruise=%4 factor=%5 maxGap=%6 followers(id,gap,spd,stuck,free)=%7",
                        _group, netId _lead, round (speed _lead), round _cruise, (round (_factor * 100)) / 100, round _maxGap, _dbg]] call fnc_log;
                };

                // LAST RESORT: the whole column has sat deadlocked for CV_TELEPORT_AT ticks -- off-road permission
                // and per-hull reposition both failed (or BLUFOR was too close to allow the per-hull snap). With
                // NO BLUFOR within CV_TP_CLEAR (so a player never witnesses it) and only on the long haul (never
                // the legitimately-slow final hop), snap every hull into a clean column on drivable ground a short
                // hop ahead toward the destination, facing it, and resume. A tick counts as deadlocked only when
                // nothing is moving at all.
                private _leadPos = getPosATL _lead;
                if ((_lead distance2D _wpPos) >= CV_FINAL_HOP && {(_live findIf { speed _x >= CV_STUCK_KMH }) < 0}) then {
                    _allStuck = _allStuck + 1;
                } else {
                    _allStuck = 0;
                };
                if (
                    _allStuck >= CV_TELEPORT_AT
                    && {(allUnits findIf { side _x == west && {alive _x} && {_x distance2D _leadPos < CV_TP_CLEAR} }) < 0}
                ) then {
                    if (duws_log_level >= 4) then { ["DEBUG", "CONVOY", format ["WHOLE-COLUMN SNAP grp=%1 (deadlocked %2 ticks)", _group, _allStuck]] call fnc_log };
                    private _dirDest = _leadPos getDir _wpPos;
                    private _aim = _leadPos getPos [40, _dirDest];   // clear of whatever the column ground against
                    private _roads = _aim nearRoads 60;
                    private _anchor = if !(_roads isEqualTo []) then { getPosATL (_roads select 0) }
                        else { [_aim, 0, 40, 6, 0, 0.5, 0] call BIS_fnc_findSafePos };

                    // Front-to-back in trail order (frontmost = highest progress) with the lead at the head, so
                    // the snapped column keeps its running order and does not have to re-sort on resume.
                    private _ordered = [_liveFollowers, [], { _prog getOrDefault [netId _x, -1] }, "DESCEND"] call BIS_fnc_sortBy;
                    {
                        private _slot = _anchor getPos [_forEachIndex * CV_GAP_WANT, _dirDest + 180];
                        if (surfaceIsWater _slot) then { _slot = [_slot, 0, 30, 6, 0, 0.5, 0] call BIS_fnc_findSafePos };
                        // setVectorDirAndUp levels any flipped hull (rolled onto its side/roof in a collision,
                        // a common wedge) and faces it at the destination in one call -- setPos alone keeps the roll.
                        _x setVectorDirAndUp [[sin _dirDest, cos _dirDest, 0], [0, 0, 1]];
                        _x setPosATL _slot;
                        _x setVelocity [0, 0, 0];
                        _x setDriveOnPath [];
                        _x forceSpeed -1;
                        _x limitSpeed CV_NOLIMIT;
                        _x forceFollowRoad false;
                    } forEach ([_lead] + _ordered);

                    // Fresh start: drop the fought trail and every per-hull order/counter; the lead is already the
                    // head of the snapped column, so cv_lead stands. Native nav takes it from the next tick.
                    _crumbs = [];
                    _allStuck = 0;
                    { private _id = netId _x; _issued set [_id, []]; _pathed set [_id, false]; _stuck set [_id, 0]; _free set [_id, 0] } forEach _live;
                    _lead doMove _wpPos;
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
