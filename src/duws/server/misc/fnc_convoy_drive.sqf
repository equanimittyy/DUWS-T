// Locality: server -- spawn once the group has its move waypoint (or a CYCLE loop). The whole convoy
// reliability engine, group-shape agnostic. Replaces the old native-column + forceFollowRoad approach.
//
// Arma's vehicle route CALCULATION was never reworked -- only path-following -- so followers left to path
// on their own cut corners cross-country into walls and wedge, at random, which no amount of stuck-nudging
// removed. This traces instead: the lead navigates its waypoints normally and every other hull replays the
// lead's own driven track via setDriveOnPath, so the only route a follower ever takes is one the lead has
// already proven drivable. Speed is regulated per follower off its gap to the hull ahead on that track, so
// the column neither rear-ends into a pile-up nor snaps apart on a curve.
//
// The driven hulls are read live from the group each tick, not captured up front, so a hull that joins
// mid-run is picked up and one that leaves is dropped with no caller bookkeeping: the deny-armour tank,
// once repaired, joins the convoy group and this loop starts driving it home in the same column; the HVT
// car, peeled into its own group on contact, falls out of its column's loop and is driven by its own.
//
// The move waypoint is read live too, so a caller that swaps the destination mid-run (drive in, then home)
// needs no restart. The front hull IS the A3 group leader (leadership is arbitrary here), so native
// navigation drives it (a MOVE completes, a CYCLE laps). Leadership is set once at spawn and left alone,
// re-picked only when the front dies: Arma then migrates it to an arbitrary survivor -- maybe a hull at
// the BACK, which would make every hull ahead trace the trail backward into a pile-up -- so the loop
// re-pins the frontmost survivor with selectLeader. Re-ranking every tick instead would jitter and churn
// the lead. Safe here only because one loop owns each group; nothing else contends for who leads.
//
// setDriveOnPath commits a driver to the track and ignores combat -- correct for a convoy whose job is to
// reach its goal (the fleeing HVT car, the escaping tank). Where the hulls must instead break and fight
// (the roving patrol), the caller sets DUWS_convoy_release on the group: path orders and speed caps drop
// and native combat AI takes the hulls back. DUWS_convoy_stop ends it the same way at teardown.
//
// A follower that sits jammed too long stops replaying the rigid trace (which it evidently cannot follow
// from where it is wedged) and navigates INDEPENDENTLY back to the hull ahead, best effort, staying in the
// group; it resumes the trace once it rejoins. No teleport and no physics impulse -- just native pathing
// re-run from a free position, which frees it where nudging a fixed line did not.
params ["_group"];

#define CV_TICK        1.5
#define CV_STEP        8       // lead must advance this far before a new breadcrumb is laid
#define CV_TRAIL       40      // keep only the last N crumbs (~320 m): longer than any column, short enough
                               // that a CYCLE patrol's looping track never snaps a follower onto an old lap
#define CV_STUCK_KMH   3       // at or below this, treat a hull as halted
#define CV_LEAD_RETRY  3       // ticks the lead sits halted before its move order is re-issued (native retry)
#define CV_RECOVER_AT  10      // ticks a follower sits jammed (~15 s) before it goes independent to rejoin
#define CV_REJOIN      25      // a recovering follower back within this of the hull ahead resumes the trace
#define CV_FINAL_HOP   120     // within this of the waypoint, drop the lead's road-lock for the off-road approach

// forceSpeed takes m/s. If an in-game check (a truck given `forceSpeed 8` rolls at ~29 km/h) proves it
// is km/h instead, set CV_KMH2FS to 1.0 so km/h values pass straight through.
#define CV_KMH2FS      (1.0 / 3.6)
#define KMH(x)         ((x) * CV_KMH2FS)

#define CV_CRUISE_KMH  40      // lead's free-running speed when the column is closed up
#define CV_CATCHUP_KMH 60      // fastest a follower may run to close a gap
#define CV_GAP_WANT    22      // desired along-track spacing to the hull ahead (m); matches layout slotting
#define CV_GAP_BAND    6       // deadband: within this of target, just match the hull ahead's speed -- no
                               // spacing trim, so the column stops hunting and the accordion damps out
#define CV_GAP_HARD    8       // closer than this: stop, a backstop against rear-ending on a transient
#define CV_GAP_KP      1       // gentle spacing trim (km/h per metre) outside the band; matching the hull
                               // ahead's speed, not this term, does the heavy lifting -- pure-P overshot
#define CV_LAG_OK      40      // widest inter-hull gap tolerated at full cruise (m)
#define CV_LAG_STOP    100     // at or past this the lead eases to a halt until the column closes up

private _crumbs = [];             // the lead's driven track, oldest first: a coarse polyline of real ground
private _stuck  = createHashMap;  // netId -> consecutive halted ticks
private _recover = createHashMap; // netId -> true while a follower is self-navigating back to the column
private _pathed = createHashMap;  // netId -> true while a hull holds a setDriveOnPath order
private _issued = createHashMap;  // netId -> [startIdx, crumbCount] last handed to setDriveOnPath (skip re-issue)
private _seen   = createHashMap;  // netId -> hull, every hull configured once (one-time setup + teardown reset)

// Nearest crumb index to a position = the hull's progress along the track. -1 while the track is empty.
private _progressOf = {
    params ["_pos"];
    private _best = -1; private _bestD = 1e11;
    { private _d = _pos distance2D _x; if (_d < _bestD) then { _bestD = _d; _best = _forEachIndex } } forEach _crumbs;
    _best
};

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
            // to an arbitrary survivor -- maybe a REAR hull, which would make the column trace its trail
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

                // A former follower now leading still carries a path order: clear it so it navigates freely.
                if (_pathed getOrDefault [_leadId, false]) then { _lead setDriveOnPath []; _pathed set [_leadId, false] };

                // Lay a breadcrumb once the lead has advanced far enough, so the track is a coarse driven
                // polyline rather than a per-tick spray of near-identical points. Capped to the last stretch.
                if (_crumbs isEqualTo [] || {(_lead distance2D (_crumbs select (count _crumbs - 1))) >= CV_STEP}) then {
                    _crumbs pushBack (getPosATL _lead);
                    if (count _crumbs > CV_TRAIL) then { _crumbs deleteAt 0 };
                };

                // Road-lock the lead for the long haul; drop it within the final hop so a road-locked driver
                // can still cross open ground to an off-road objective. Its speed and any stuck-nudge are set
                // after the follower pass, once the column's widest gap is known.
                private _leadNear = (_lead distance2D _wpPos) < CV_FINAL_HOP;
                _lead forceFollowRoad (!_leadNear);

                // Followers: trace the lead's track and hold station off the hull ahead.
                private _liveFollowers = _live select { _x != _lead };
                private _leadProg = count _crumbs;   // the lead is ahead of every crumb; _prog is built above

                private _maxGap = 0;
                {
                    private _me   = _x;
                    private _meId = netId _me;
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

                    // Along-track gap (crumb-index difference x step), not straight-line: on a bend the hull
                    // ahead is nearer as-the-crow-flies than along the road, which would false-trigger braking.
                    private _gap = if (_myProg < 0) then { CV_GAP_WANT } else { ((_aheadProg - _myProg) * CV_STEP) max 0 };
                    if (_gap > _maxGap) then { _maxGap = _gap };

                    // Recovery mode: a follower jammed for CV_RECOVER_AT ticks abandons the rigid trace (which
                    // it cannot follow from where it is wedged) and drives INDEPENDENTLY to the hull ahead --
                    // native pathing picks its own way out, best effort, while it stays in the group. It rejoins
                    // the trace once back within CV_REJOIN. The lead is already halting for it (its widening
                    // along-track gap drives _maxGap), so this is the leader-waits, follower-catches-up regroup.
                    if (_recover getOrDefault [_meId, false]) then {
                        if (_pathed getOrDefault [_meId, false]) then { _me setDriveOnPath []; _pathed set [_meId, false] };
                        _me doMove (getPosATL _ahead);
                        _me forceSpeed KMH(CV_CATCHUP_KMH);
                        if ((_me distance _ahead) < CV_REJOIN) then {
                            _recover set [_meId, false];
                            _issued set [_meId, []];   // force a fresh trace on the next normal tick
                            _stuck  set [_meId, 0];
                        };
                    } else {
                        // Normal mode: replay the lead's proven-drivable line. Until the track has a couple of
                        // crumbs, just aim at the destination. Re-issue only when the slice changed, so a parked
                        // column is not re-ordered every tick.
                        if (count _crumbs < 2 || {_myProg < 0}) then {
                            _me doMove _wpPos;
                        } else {
                            private _startIdx = (_myProg - 1) max 0;
                            private _sig = [_startIdx, count _crumbs];
                            if (!((_issued getOrDefault [_meId, []]) isEqualTo _sig)) then {
                                private _path = (_crumbs select [_startIdx]) + [getPosATL _lead];
                                _me setDriveOnPath _path;
                                _issued set [_meId, _sig];
                                _pathed set [_meId, true];
                            };
                        };

                        // Hold station by MATCHING the hull ahead's speed, with only a gentle spacing trim
                        // outside a deadband. Speed off the gap alone is position-only control: on the 1.5 s
                        // tick it overshoots and sets the column oscillating -- matching the predecessor's
                        // velocity damps it. Inside the band: just match. Too close: stop, holding a minimum gap.
                        private _aheadSpd = speed _ahead;   // km/h (`speed` and the CV_* speeds are km/h; forceSpeed converts)
                        private _err = _gap - CV_GAP_WANT;
                        private _fs = switch (true) do {
                            case (_gap < CV_GAP_HARD):      { 0 };
                            case (abs _err <= CV_GAP_BAND): { _aheadSpd };
                            default                         { _aheadSpd + _err * CV_GAP_KP };
                        };
                        _fs = _fs max 0 min CV_CATCHUP_KMH;
                        _me forceSpeed KMH(_fs);

                        // Jammed too long -> hand it to recovery. The counter accumulates while the follower is
                        // meant to be moving but is not, and clears only when it actually moves, so a brief snag
                        // is told apart from a genuine wedge.
                        if (speed _me < CV_STUCK_KMH && {_fs > CV_STUCK_KMH}) then {
                            private _n = (_stuck getOrDefault [_meId, 0]) + 1;
                            _stuck set [_meId, _n];
                            if (_n >= CV_RECOVER_AT) then { _recover set [_meId, true] };
                        } else {
                            _stuck set [_meId, 0];
                        };
                    };
                } forEach _liveFollowers;

                // Lead speed governs the whole column: full cruise while it is closed up, easing to a halt as
                // the widest inter-hull gap opens past CV_LAG_OK, so a lagging follower is never left behind.
                // If the lead itself jams, re-issue its move so native navigation retries a route -- only while
                // it is meant to be moving (not when deliberately halted waiting for the tail) and on the long
                // haul (the off-road final approach is legitimately slow).
                private _factor = ((CV_LAG_STOP - _maxGap) / (CV_LAG_STOP - CV_LAG_OK)) max 0 min 1;
                _lead forceSpeed KMH(CV_CRUISE_KMH * _factor);
                if (_factor > 0 && {!_leadNear} && {speed _lead < CV_STUCK_KMH}) then {
                    private _n = (_stuck getOrDefault [_leadId, 0]) + 1;
                    if (_n >= CV_LEAD_RETRY) then { _lead doMove _wpPos; _n = 0 };
                    _stuck set [_leadId, _n];
                } else {
                    _stuck set [_leadId, 0];
                };
            };
        };
    };
    sleep CV_TICK;
};

// Teardown, or hand-off to combat on release: drop every path order and speed cap on every hull this loop
// ever configured, so native AI drives them.
{ _x setDriveOnPath []; _x forceSpeed -1; _x forceFollowRoad false } forEach (values _seen);
