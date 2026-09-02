// Locality: server -- waypoint/behaviour orders need the group local to the caller
// (docs/info/architecture/arma_engine_gotchas.md); the protect_civ thread spawns this server-side.
//
// Bounding-overwatch withdrawal for the surviving foot groups when the assault breaks off: half cover
// while half fall back 100 m toward friendly ground at CARELESS, swapping roles each leapfrog. A group
// is binned once it clears 600 m of every player. A five-minute grace, or dropping below the two groups
// that cover each other, ends the leapfrog and marches the rest to the nearest zone.
//
// _groups is groups, not spawn tokens.
if (!isServer) exitWith {};
params ["_groups", "_center"];

#define BOUND_DIST  100
#define CLEAN_DIST  600
#define GRACE       300
#define BOUND_TIME  30    // s per leapfrog

private _fnAlive = { !isNull _this && { ({ alive _x } count units _this) > 0 } };

private _fnNearPlayer = {
    private _ps = call BIS_fnc_listPlayers;
    if (_ps isEqualTo []) exitWith { objNull };
    private _lead = leader _this;
    ([_ps, [], { _lead distance2D _x }, "ASCEND"] call BIS_fnc_sortBy) select 0
};

// WARCOM_zones_controled_by_OPFOR holds positions, not objects; fall straight out when it is empty.
private _fnZonePos = {
    private _lead = leader _this;
    private _held = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
    if (_held isNotEqualTo []) exitWith { ([_held, [], { _lead distance2D _x }, "ASCEND"] call BIS_fnc_sortBy) select 0 };
    _center getPos [CLEAN_DIST + 800, _center getDir (getPosATL _lead)]
};

// Bearings averaged as unit vectors so the blend wraps 360.
private _fnBlend = {
    params ["_a", "_wa", "_b", "_wb"];
    (_wa * sin _a + _wb * sin _b) atan2 (_wa * cos _a + _wb * cos _b)
};

private _fnClearWp = { for "_i" from ((count waypoints _this) - 1) to 0 step -1 do { deleteWaypoint [_this, _i] } };

// LIMITED so it holds the post, not wanders.
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
    // FULL on the waypoint too: no default can throttle the leg back.
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

// binAt now: past 600 m it is past the sweep keep-radius too, so it goes next pass.
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
