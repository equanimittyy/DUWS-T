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
// needs no restart. The lead is always the frontmost driven hull: the group leader drives the front under
// native navigation (a MOVE completes, a CYCLE laps), and because Arma migrates leadership on a death to
// any survivor -- including a hull at the BACK, which would make every hull ahead trace the trail backward
// into a pile-up -- the loop keeps leadership on the frontmost hull with selectLeader. That is safe here
// only because one loop owns each group; nothing else contends for who leads.
//
// setDriveOnPath commits a driver to the track and ignores combat -- correct for a convoy whose job is to
// reach its goal (the fleeing HVT car, the escaping tank). Where the hulls must instead break and fight
// (the roving patrol), the caller sets DUWS_convoy_release on the group: path orders and speed caps drop
// and native combat AI takes the hulls back. DUWS_convoy_stop ends it the same way at teardown.
params ["_group"];

#define CV_TICK        1.5
#define CV_STEP        8       // lead must advance this far before a new breadcrumb is laid
#define CV_TRAIL       40      // keep only the last N crumbs (~320 m): longer than any column, short enough
                               // that a CYCLE patrol's looping track never snaps a follower onto an old lap
#define CV_STUCK_KMH   3       // at or below this, treat a hull as halted
#define CV_KICK_AT     1       // ticks halted before the lead's move is re-issued
#define CV_SHOVE_AT    3       // ticks halted before the reverse impulse
#define CV_FINAL_HOP   120     // within this of the waypoint, drop the lead's road-lock for the off-road approach
#define CV_MIN_SEP     12      // closer than this to the hull ahead: crawl (values under ~10 m make the AI swerve)
#define CV_MID_SEP     25
#define CV_MAX_SEP     40      // further than this: full catch-up
#define CV_BREAK       90      // a follower this far back stalls the lead until the column closes up

private _crumbs = [];             // the lead's driven track, oldest first: a coarse polyline of real ground
private _stuck  = createHashMap;  // netId -> consecutive halted ticks
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

            // Progress of every live hull along the trail (nearest crumb index), for the lead choice and for
            // follower spacing. Capture the hull before the call: _progressOf runs its own forEach, so relying
            // on _x surviving across the call is the nested-forEach clobber trap.
            private _prog = createHashMap;
            private _front = objNull; private _bestP = -2;
            { private _v = _x; private _p = [getPosATL _v] call _progressOf; _prog set [netId _v, _p]; if (_p > _bestP) then { _bestP = _p; _front = _v } } forEach _live;

            // Keep the group leader on the frontmost hull, so native waypoints drive the front (a MOVE
            // completes, a CYCLE laps) and the traced column can never reverse. Arma migrates leadership on a
            // death to any survivor -- a hull at the BACK, or a crewman shot out onto foot -- and a rear leader
            // would make every hull ahead trace the trail backward into a pile-up. Correct it with
            // selectLeader (safe now one loop owns the group). Hysteresis -- keep the current leader unless it
            // has fallen well behind the front or is no longer a live hull -- stops per-tick churn when the
            // front vehicles are bunched and their nearest-crumb ranking jitters.
            if (!isNull _front) then {
                private _leaderHull = vehicle (leader _group);
                private _leaderOk = (_leaderHull in _live) && {(_prog getOrDefault [netId _leaderHull, -99]) >= (_bestP - 3)};
                if (!_leaderOk) then { _group selectLeader (driver _front) };
            };
            private _lead = vehicle (leader _group);
            if (!(_lead in _live)) then { _lead = _front };   // leadership still on foot this frame: drive the front hull

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
                // can still cross open ground to an off-road objective. The lead is the group leader, so its
                // waypoints drive it; nudge a jam by re-issuing the move, then a reverse impulse to rock the
                // hull off the geometry it caught on.
                private _leadNear = (_lead distance2D _wpPos) < CV_FINAL_HOP;
                _lead forceFollowRoad (!_leadNear);
                _lead forceSpeed -1;
                if (!_leadNear && {speed _lead < CV_STUCK_KMH}) then {
                    private _n = (_stuck getOrDefault [_leadId, 0]) + 1;
                    _stuck set [_leadId, _n];
                    if (_n == CV_KICK_AT || {_n == CV_SHOVE_AT}) then { _lead doMove _wpPos };
                    if (_n >= CV_SHOVE_AT) then { _lead setVelocityModelSpace [0, -3.5, 0]; _stuck set [_leadId, 0] };
                } else {
                    _stuck set [_leadId, 0];
                };

                // Followers: trace the lead's track and hold station off the hull ahead.
                private _liveFollowers = _live select { _x != _lead };
                private _leadProg = count _crumbs;   // the lead is ahead of every crumb; _prog is built above

                private _maxGap = 0;
                {
                    private _me   = _x;
                    private _meId = netId _me;
                    private _myProg = _prog get _meId;

                    // The hull ahead: least progress strictly greater than mine, else the lead.
                    private _ahead = _lead;
                    private _aheadProg = _leadProg;
                    {
                        if (_x != _me) then {
                            private _p = _prog get (netId _x);
                            if (_p > _myProg && {_p < _aheadProg}) then { _aheadProg = _p; _ahead = _x };
                        };
                    } forEach _liveFollowers;

                    private _gap = _me distance _ahead;
                    if (_gap > _maxGap) then { _maxGap = _gap };

                    // Until the track has a couple of crumbs the followers just aim at the destination; once it
                    // does, replay the lead's line from just behind this hull to the live head. Re-issue only
                    // when the slice changed, so a parked column is not re-ordered every tick.
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

                    // Hold station: crawl when tucked up on the hull ahead, open the throttle to close a gap.
                    private _fs = switch (true) do {
                        case (_gap < CV_MIN_SEP): { 5 };
                        case (_gap < CV_MID_SEP): { 20 };
                        case (_gap < CV_MAX_SEP): { 40 };
                        default { 60 };
                    };
                    _me forceSpeed _fs;

                    // A follower gone dead-slow while it still owes distance to the hull ahead is jammed: rock
                    // it off the snag and force a fresh trace next tick.
                    if (speed _me < CV_STUCK_KMH && {_gap > CV_MIN_SEP}) then {
                        private _n = (_stuck getOrDefault [_meId, 0]) + 1;
                        _stuck set [_meId, _n];
                        if (_n >= CV_SHOVE_AT) then {
                            _me setVelocityModelSpace [0, -3.5, 0];
                            _issued set [_meId, []];
                            _stuck set [_meId, 0];
                        };
                    } else {
                        _stuck set [_meId, 0];
                    };
                } forEach _liveFollowers;

                // Stall the lead while the tail is dropping off the back, so the column closes up instead of
                // snapping. Cleared back to free drive as soon as it does.
                if (_maxGap > CV_BREAK) then { _lead forceSpeed 8 };
            };
        };
    };
    sleep CV_TICK;
};

// Teardown, or hand-off to combat on release: drop every path order and speed cap on every hull this loop
// ever configured, so native AI drives them.
{ _x setDriveOnPath []; _x forceSpeed -1; _x forceFollowRoad false } forEach (values _seen);
