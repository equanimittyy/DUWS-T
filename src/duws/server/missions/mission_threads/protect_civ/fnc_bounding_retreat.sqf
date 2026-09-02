// Locality: server -- addWaypoint, setBehaviour and setPos are ignored unless the group is local to the
// machine issuing them (docs/info/architecture/arma_engine_gotchas.md); the protect_civ thread runs
// server-side and spawns this.
//
// Bounding-overwatch withdrawal for the infantry left standing when the assault breaks off. Each leapfrog
// splits the survivors in two: one half holds and overwatches where it stands (AWARE, so it covers), the
// other half falls back 100 m -- away from the nearest player, biased toward the nearest enemy zone, at
// CARELESS so it runs rather than turns to fight. The two halves swap roles each leapfrog, so everyone
// works rearward. A group is flagged for the map sweep the moment it clears 600 m of every player.
//
// A five-minute grace caps the dance. Past it -- or the instant fewer than two groups are left, since a
// lone group has no one to cover it -- the survivors drop the leapfrog and simply march AWARE to the
// nearest enemy zone, still swept as each clears 600 m.
//
// The array is groups (the surviving foot groups the caller claimed), not spawn tokens.
if (!isServer) exitWith {};
params ["_groups", "_center"];

#define BOUND_DIST  100
#define CLEAN_DIST  600
#define GRACE       300
#define BOUND_TIME  30    // seconds a leapfrog runs before the halves swap

private _fnAlive = { !isNull _this && { ({ alive _x } count units _this) > 0 } };

private _fnNearPlayer = {
    private _ps = call BIS_fnc_listPlayers;
    if (_ps isEqualTo []) exitWith { objNull };
    private _lead = leader _this;
    ([_ps, [], { _lead distance2D _x }, "ASCEND"] call BIS_fnc_sortBy) select 0
};

// Fallback bearing when the side holds no zone. WARCOM_zones_controled_by_OPFOR is positions, not objects.
private _fnZonePos = {
    private _lead = leader _this;
    private _held = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
    if (_held isNotEqualTo []) exitWith { ([_held, [], { _lead distance2D _x }, "ASCEND"] call BIS_fnc_sortBy) select 0 };
    _center getPos [CLEAN_DIST + 800, _center getDir (getPosATL _lead)]
};

// Weighted mean of two compass bearings via their unit vectors, so the blend wraps 360 cleanly.
private _fnBlend = {
    params ["_a", "_wa", "_b", "_wb"];
    (_wa * sin _a + _wb * sin _b) atan2 (_wa * cos _a + _wb * cos _b)
};

private _fnClearWp = { for "_i" from ((count waypoints _this) - 1) to 0 step -1 do { deleteWaypoint [_this, _i] } };

// LIMITED so a repositioning to fire stays near the post rather than becoming a move of its own.
private _fnSentry = {
    _this call _fnClearWp;
    _this setBehaviour "AWARE"; _this setCombatMode "YELLOW"; _this setSpeedMode "LIMITED";
    (_this addWaypoint [getPosATL (leader _this), 0]) setWaypointType "HOLD";
};

private _fnBound = {
    private _here = getPosATL (leader _this);
    private _np = _this call _fnNearPlayer;
    private _awayBrg = if (isNull _np) then { _center getDir _here } else { (getPosATL _np) getDir _here };
    private _zoneBrg = _here getDir (_this call _fnZonePos);
    private _brg = [_awayBrg, 1, _zoneBrg, 0.6] call _fnBlend;
    private _raw = _here getPos [BOUND_DIST, _brg];
    private _safe = [_raw, 0, 60, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
    if (_safe isEqualTo []) then { _safe = _raw };
    _this call _fnClearWp;
    _this setBehaviour "CARELESS"; _this setCombatMode "BLUE"; _this setSpeedMode "FULL";
    // Speed forced on the waypoint too, so no waypoint default can throttle a bounding leg back.
    private _wp = _this addWaypoint [_safe, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "FULL";
};

private _fnMarch = {
    private _dest = _this call _fnZonePos;
    private _safe = [_dest, 0, 80, 8, 0, 0.5, 0] call BIS_fnc_findSafePos;
    if (_safe isEqualTo []) then { _safe = _dest };
    _this call _fnClearWp;
    _this setBehaviour "AWARE"; _this setCombatMode "YELLOW"; _this setSpeedMode "FULL";
    (_this addWaypoint [_safe, 0]) setWaypointType "MOVE";
};

// binAt now, not now+lifetime: past the 600 m ring it is also past the sweep's keep-radius, so it goes next pass.
private _fnBin = { { _x setVariable ["DUWS_binMe", true]; _x setVariable ["DUWS_binAt", time] } forEach units _this };

private _fnClearOfPlayers = {
    private _np = _this call _fnNearPlayer;
    (isNull _np) || { (leader _this) distance2D (getPosATL _np) >= CLEAN_DIST }
};

private _active = _groups select { _x call _fnAlive };
private _deadline = time + GRACE;
private _phase = 0;
private _marching = false;

while { _active isNotEqualTo [] } do {
    { if ((_x call _fnAlive) && { _x call _fnClearOfPlayers }) then { _x call _fnBin } } forEach _active;
    _active = _active select { (_x call _fnAlive) && { !(_x call _fnClearOfPlayers) } };
    if (_active isEqualTo []) exitWith {};

    if (!_marching && { time >= _deadline || { count _active < 2 } }) then {
        _marching = true;
        { _x call _fnMarch } forEach _active;
    };

    if (_marching) then {
        uiSleep 5;
    } else {
        {
            private _role = [_fnSentry, _fnBound] select (((_forEachIndex + _phase) mod 2) == 0);
            _x call _role;
        } forEach _active;
        _phase = _phase + 1;
        private _next = time + BOUND_TIME;
        waitUntil { uiSleep 2; time >= _next };
    };
};
