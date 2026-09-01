// Locality: server -- lays an endless MOVE route on a group: one waypoint per point in order, then a
// CYCLE anchored on the first so the group drives the circuit forever. The ambient town events (car,
// convoy, heli) share it so a spawned vehicle keeps moving instead of reaching a dead-end waypoint and
// sitting idle for the rest of its cleanup lifetime (fnc_repetitive_cleanup, DUWS_CleanupLifetime is
// ~15 min) -- an ambient car frozen at a town edge reads as broken. Speed and behaviour are the caller's
// group setup; only the route is laid here.
if (!isServer) exitWith {};
params ["_grp", "_points", ["_compRadius", 40]];
if (_points isEqualTo []) exitWith {};

{
	private _wp = _grp addWaypoint [_x, 0];
	_wp setWaypointType "MOVE";
	_wp setWaypointBehaviour "CARELESS";
	_wp setWaypointCompletionRadius _compRadius;
} forEach _points;

// CYCLE links back to the nearest earlier waypoint; placed on the first point so the whole circuit repeats.
private _cyc = _grp addWaypoint [_points select 0, 0];
_cyc setWaypointType "CYCLE";
_cyc setWaypointBehaviour "CARELESS";
