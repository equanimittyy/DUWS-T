// Locality: server -- an ambient civilian car that drives up to and past the picked player, then on
// toward the town, reaped once no player is near (docs/plans/town_events_plan.md). No rep gate.
// Model from civ_veh_array; driver a full civilian, so running one down costs reputation.
if (!isServer) exitWith {};
params [["_townIndex", -1], ["_player", objNull]];
if (isNull _player) exitWith {};

private _pool = missionNamespace getVariable ["civ_veh_array", []];
if (_pool isEqualTo []) exitWith {};

private _anchor = getPos _player;
// A road out from the player, so the car is seen arriving rather than dropped on top of them.
private _roads = _anchor nearRoads 500;
private _far = _roads select { (_anchor distance _x) > 150 };
if !(_far isEqualTo []) then { _roads = _far };
if (_roads isEqualTo []) exitWith {};

private _road = selectRandom _roads;
private _spawnPos = getPosATL _road;
private _dir = [_road] call fnc_civ_roadDir;
private _veh = [selectRandom _pool, _spawnPos, _dir] call fnc_civ_spawnCar;

private _driver = [_townIndex, _spawnPos, selectRandom civ_array, false] call fnc_civ_spawnUnit;
if (isNull _driver) exitWith { deleteVehicle _veh };
_driver moveInDriver _veh;

private _grp = group _driver;
_grp setBehaviour "CARELESS";
_grp setSpeedMode "LIMITED";
_veh limitSpeed 50;

// Through the player's spot, then on to town: moves through rather than parking on them.
private _centres = (missionNamespace getVariable ["civ_locations", []]) apply { getPos _x };
private _townPos = _centres param [_townIndex, _anchor];
{
	private _wp = _grp addWaypoint [_x, 0];
	_wp setWaypointType "MOVE";
	_wp setWaypointSpeed "LIMITED";
	_wp setWaypointBehaviour "CARELESS";
	_wp setWaypointCompletionRadius 20;
} forEach [_anchor, _townPos];

// Onto the cleanup sweep. Flag the driver too: bailed on a panic he is no longer crew, so the
// vehicle sweep would not take him with the car.
_veh setVariable ["DUWS_binMe", true];
_driver setVariable ["DUWS_binMe", true];
