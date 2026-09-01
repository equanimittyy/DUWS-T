// Locality: server -- an ambient civilian car spawned on a road near the picked player, then looping
// town-to-town so it keeps driving until the cleanup sweep reaps it (docs/plans/random_events_plan.md).
// No rep gate. Model from civ_veh_array; driver a full civilian, so running one down costs reputation.
if (!isServer) exitWith {};
params [["_townIndex", -1], ["_player", objNull]];
if (isNull _player) exitWith {};

private _pool = missionNamespace getVariable ["civ_veh_array", []];
if (_pool isEqualTo []) exitWith {};

// Roads out of the player's sight where possible, so the car stands up unseen and drives into view.
private _roads = [getPos _player] call fnc_civ_pickHiddenRoad;
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

// A looping town-to-town circuit so the car keeps driving until the cleanup sweep reaps it, rather than
// parking at one destination and sitting idle for the rest of its lifetime; spawned near the player, so
// it is still seen setting off. Fewer than five towns on the map shortens the loop to what exists.
private _centres = (missionNamespace getVariable ["civ_locations", []]) apply { getPos _x };
private _route = (_centres call BIS_fnc_arrayShuffle) select [0, 5 min count _centres];
[_grp, _route, 50] call fnc_civ_loopRoute;

// Onto the cleanup sweep. Flag the driver too: bailed on a panic he is no longer crew, so the
// vehicle sweep would not take him with the car.
_veh setVariable ["DUWS_binMe", true];
_driver setVariable ["DUWS_binMe", true];
