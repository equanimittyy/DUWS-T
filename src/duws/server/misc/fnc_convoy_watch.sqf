// Locality: server -- spawn it once the group has its move waypoint. The stuck watchdog: the reliability
// engine, and group-shape agnostic. Arma's vehicle route calculation was never fixed (see
// fnc_convoy_setup), so no amount of tuning removes every stall -- this catches the residual ones.
//
// Each tick it reads the group's *current* waypoint live, so a caller that swaps the destination mid-run
// (drive in, then drive home) needs no restart. Within CV_FINAL_HOP of that waypoint it drops
// forceFollowRoad so a road-locked driver can still cross open ground to an off-road objective, and
// restores it once back on the long haul. A vehicle gone dead-slow with road still to cover is nudged:
// first the move is re-issued (kick the pathfinder), then a short reverse impulse rocks a hull off the
// geometry it caught on. No setPos unstick -- teleporting drops vehicles into terrain and reads worse
// than the stall it fixes.
//
// Stops when the caller sets DUWS_convoy_stop on the group (mission teardown), the group is gone, or no
// watched vehicle can move any more.
params ["_group", "_vehicles"];

#define CV_TICK       4
#define CV_STUCK_KMH  3       // at or below this, treat the vehicle as halted
#define CV_KICK_AT    1       // ticks halted before the move is re-issued
#define CV_SHOVE_AT   3       // ticks halted before the reverse impulse
#define CV_FINAL_HOP  120     // within this of the waypoint, drop road-lock for the off-road approach

private _stuck = createHashMap;
while {
    !isNull _group
    && {!(_group getVariable ["DUWS_convoy_stop", false])}
    && {(_vehicles findIf { alive _x && canMove _x }) >= 0}
} do {
    private _wpPos = waypointPosition [_group, currentWaypoint _group];
    // A group with no live move waypoint reports [0,0,0]; nudging toward it would drive the column to the
    // map origin, so skip the tick until a real destination exists.
    if (_wpPos isNotEqualTo [0, 0, 0]) then {
        {
            if (alive _x && {canMove _x} && {alive (driver _x)}) then {
                private _id = netId _x;
                private _near = (_x distance2D _wpPos) < CV_FINAL_HOP;
                _x forceFollowRoad (!_near);
                if (!_near && {speed _x < CV_STUCK_KMH}) then {
                    private _n = (_stuck getOrDefault [_id, 0]) + 1;
                    _stuck set [_id, _n];
                    if (_n == CV_KICK_AT || {_n == CV_SHOVE_AT}) then { _x doMove _wpPos };
                    if (_n >= CV_SHOVE_AT) then {
                        _x setVelocityModelSpace [0, -3.5, 0];   // rock backward off the snag, then re-kick next tick
                        _stuck set [_id, 0];
                    };
                } else {
                    _stuck set [_id, 0];
                };
            };
        } forEach _vehicles;
    };
    sleep CV_TICK;
};
