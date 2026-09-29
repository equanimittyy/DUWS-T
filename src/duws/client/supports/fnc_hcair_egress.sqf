// Locality: wherever the sortie group is local -- the caller's client at the end of station time
// (client/supports/fnc_hcair_sortie.sqf), the server once the caller has left
// (server/supports/fnc_hcair_recall.sqf). Blocks until the aircraft is clear, down, or out of grace.
params ["_group", "_vehicle", "_offmap", "_egressH"];

{ _x setCaptive true } forEach units _group;
_vehicle setCaptive true;
_group setBehaviour "CARELESS";
if (_egressH > 0) then { _vehicle flyInHeight _egressH };
while { count waypoints _group > 0 } do { deleteWaypoint [_group, 0] };
private _wpOut = _group addWaypoint [_offmap, 0];
_wpOut setWaypointType "MOVE";
_wpOut setWaypointSpeed "FULL";
_group setCurrentWaypoint _wpOut;
// Grace cap so a damaged or blocked aircraft that never clears the map still cleans up.
private _grace = time + 60;
waitUntil { sleep 3; !alive _vehicle || _vehicle distance _offmap < 800 || time > _grace };
