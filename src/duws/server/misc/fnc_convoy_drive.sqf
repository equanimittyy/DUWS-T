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
//   Followers: each REPLAYS the lead's crumb line with setDriveOnPath -- it drives the exact proven-drivable
//   ground the lead covered, never a native route the engine recomputes. doMove (a native route) is what makes
//   a hull stall on open ground -- "stuck on nothing" -- so it is used only in recovery, not for normal
//   following. The replay path ends at the STATION, a point a gap (CV_GAP_WANT) behind the hull ahead, so the
//   path and forceSpeed agree; ending it at the lead made the path brake into it while forceSpeed held the gap,
//   and the two fought. forceSpeed holds the actual gap by matching the hull ahead's speed.
//
//   Pace: the lead eases toward a halt as the widest inter-hull gap opens (CV_LAG_OK..CV_LAG_STOP), so the
//   column always waits for its tail. This alone replaces the old explicit regroup.
//
//   Recovery ladder for a hull the avoidance wedged (climbs only while it is meant to move but is not):
//     1. off-road detour     -- drop the replay path AND the road-lock for a few ticks and doMove (a fresh
//                               native route): the one place doMove earns its keep, getting AROUND a real
//                               block the replay cannot; then the replay resumes (lead or follower)
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

#define CV_CRUISE_KMH  40      // lead's free-running speed when the column is closed up
#define CV_CATCHUP_KMH 60      // fastest a follower may run to close a gap
#define CV_GAP_WANT    20      // desired along-track spacing to the hull ahead (m). Tighter than the spawn
                               // slot (fnc_convoy_layout, ~22 m): long escorts must not spawn bumper-to-
                               // bumper and explode, but the column closes to this once rolling.
#define CV_GAP_BAND    4       // deadband: within this of target, just match the hull ahead's speed -- no
                               // spacing trim, so the column stops hunting and the accordion damps out
#define CV_GAP_HARD    4       // closer than this: stop, a backstop against rear-ending on a transient
#define CV_GAP_KP      1       // gentle spacing trim (km/h per metre) outside the band; matching the hull
                               // ahead's speed, not this term, does the heavy lifting -- pure-P overshot
#define CV_LAG_OK      40      // widest inter-hull gap tolerated at full cruise (m)
#define CV_LAG_STOP    100     // at or past this the lead eases to a halt until the column closes up

private _crumbs = [];             // the lead's driven track, oldest first: a coarse polyline of real ground
private _stuck  = createHashMap;  // netId -> consecutive halted ticks (per hull, lead included)
private _free   = createHashMap;  // netId -> ticks its road-lock stays off after a wedge, so it can detour
private _allStuck = 0;            // consecutive ticks the whole column is deadlocked (nothing moving)
private _issued = createHashMap;  // netId -> last replay key [startIdx, stationIdx, leadPos]; [] forces re-issue
private _pathed = createHashMap;  // netId -> is a setDriveOnPath currently committed (clear it before a doMove)
private _seen   = createHashMap;  // netId -> hull, every hull configured once (one-time setup + teardown reset)

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

                    // Drive by REPLAYING the lead's proven-drivable crumb line with setDriveOnPath, not doMove:
                    // a native route the engine recomputes each tick stalls the hull on open ground ("stuck on
                    // nothing"), and when a player is close the out-of-sight recovery cannot free it. The replay
                    // path ends at the STATION -- a point CV_GAP_WANT behind the hull ahead -- so the path and the
                    // speed controller agree, instead of the path braking into the lead while forceSpeed holds the
                    // gap. While an off-road unstick window is open (_free), leave the path alone: the recovery
                    // doMove detour owns the hull until the window closes, then the replay resumes. The road-lock
                    // rides the same gate -- on-road for the haul, off in the final hop or during a detour window.
                    private _ff = _free getOrDefault [_meId, 0];
                    if (_ff > 0) then {
                        _free set [_meId, _ff - 1];
                    } else {
                        _me forceFollowRoad (!_leadNear);
                        private _st = [_aheadPos, _aheadProg] call _stationBehind;
                        // Before the first crumbs, off the trail, or a trail too short for a full gap: aim straight
                        // at the lead. The destination lies beyond it, so aiming past the lead would drive the hull
                        // through the column.
                        if (count _crumbs < 2 || {_myProg < 0} || {_st isEqualTo []}) then {
                            if (_pathed getOrDefault [_meId, false]) then { _me setDriveOnPath []; _pathed set [_meId, false] };
                            _me doMove (getPosATL _lead);
                            _issued set [_meId, []];
                        } else {
                            _st params ["_stPos", "_stIdx"];
                            // Slice forward from the crumb just AHEAD of this hull (never one behind -- a passed
                            // point makes setDriveOnPath brake and reverse to reach it) to the station crumb, then
                            // the exact station point.
                            private _startIdx = _myProg + 1;
                            private _slice = if (_startIdx <= _stIdx) then { _crumbs select [_startIdx, _stIdx - _startIdx + 1] } else { [] };
                            // Re-issue when the slice or station shifted, or the lead advanced >= CV_STEP. Keying on
                            // indices alone goes stale on a FULL trail: count pins at CV_TRAIL (push + deleteAt 0
                            // each tick) while the crumb contents shift down an index, so a hull whose indices hold
                            // steady would keep driving a path of OLD positions, reach its stale end, and stop.
                            private _iss = _issued getOrDefault [_meId, []];
                            if (
                                _iss isEqualTo []
                                || {(_iss select 0) != _startIdx}
                                || {(_iss select 1) != _stIdx}
                                || {(_lead distance2D (_iss select 2)) >= CV_STEP}
                            ) then {
                                _me setDriveOnPath (_slice + [_stPos]);
                                _issued set [_meId, [_startIdx, _stIdx, getPosATL _lead]];
                                _pathed set [_meId, true];
                            };
                        };
                    };

                    // Hold station by MATCHING the hull ahead's speed with a gentle spacing trim outside a
                    // deadband -- velocity-matching, not position-only control, so the coarse tick does not set
                    // the column oscillating. Inside the band: match. Too close: stop on a minimum gap.
                    private _aheadSpd = speed _ahead;   // km/h; forceSpeed converts via KMH()
                    private _err = _gap - CV_GAP_WANT;
                    private _fs = switch (true) do {
                        case (_gap < CV_GAP_HARD):      { 0 };
                        case (abs _err <= CV_GAP_BAND): { _aheadSpd };
                        default                         { _aheadSpd + _err * CV_GAP_KP };
                    };
                    _fs = _fs max 0 min CV_CATCHUP_KMH;
                    // Never outrun the hull ahead when tucked inside the gap, but only while it is rolling: a
                    // spurious speed~0 (turn, arrival micro-stop) must not pin the follower dead.
                    if ((_me distance2D _ahead) < CV_GAP_WANT && {_aheadSpd > CV_STUCK_KMH}) then { _fs = _fs min _aheadSpd };
                    _me forceSpeed KMH(_fs);

                    // Per-hull recovery, since obstacle avoidance cannot be trusted to free a wedge. The counter
                    // climbs only while the hull is meant to move (_fs above the halt threshold) but is not, so a
                    // legitimate halt (the column stopped) never counts. After a short confirm: off-road permission
                    // plus a fresh doMove (detour). If it stays wedged and no BLUFOR is close enough to witness it,
                    // snap that one hull onto its station slot, un-flipped and facing up-column.
                    if (speed _me < CV_STUCK_KMH && {_fs > CV_STUCK_KMH}) then {
                        private _n = (_stuck getOrDefault [_meId, 0]) + 1;
                        _stuck set [_meId, _n];
                        if (_n == CV_UNSTICK_AT) then {
                            _free set [_meId, CV_FREE_HOLD];
                            _me forceFollowRoad false;
                            if (_pathed getOrDefault [_meId, false]) then { _me setDriveOnPath []; _pathed set [_meId, false] };
                            _me doMove _aheadPos;   // fresh native route around the block; _free gates the replay off meanwhile
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

                // Lead speed governs the column pace: full cruise closed up, easing to a halt as the widest
                // inter-hull gap opens past CV_LAG_OK, so the column always waits for its tail. This is what
                // replaces the old explicit regroup -- the lead simply holds while stragglers close, and the
                // recovery ladder frees any hull the avoidance actually wedged.
                private _factor = ((CV_LAG_STOP - _maxGap) / (CV_LAG_STOP - CV_LAG_OK)) max 0 min 1;
                _lead forceSpeed KMH(CV_CRUISE_KMH * _factor);

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
                    ["DEBUG", "CONVOY", format ["grp=%1 lead=%2 leadSpd=%3 factor=%4 maxGap=%5 followers(id,gap,spd,stuck,free)=%6",
                        _group, netId _lead, round (speed _lead), (round (_factor * 100)) / 100, round _maxGap, _dbg]] call fnc_log;
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
// ever configured, so native AI drives them.
{ _x setDriveOnPath []; _x forceSpeed -1; _x forceFollowRoad false } forEach (values _seen);
