// Locality: server -- an ambient civilian car that drives up to and past the picked player, then on
// toward the town, reaped once no player is near. No rep gate: it runs at any reputation
// (docs/plans/town_events_plan.md). Model from civ_veh_array (faction-detected), driver a full
// civilian (fnc_civ_spawnUnit), so running one down costs reputation as the resident traffic does.
if (!isServer) exitWith {};
params [["_townIndex", -1], ["_player", objNull]];
if (isNull _player) exitWith {};

private _pool = missionNamespace getVariable ["civ_veh_array", []];
if (_pool isEqualTo []) exitWith {};

private _anchor = getPos _player;
// A road out from the player so the car is seen arriving, not dropped on top of them; nearest road
// if none is that far.
private _roads = _anchor nearRoads 500;
private _far = _roads select { (_anchor distance _x) > 150 };
if !(_far isEqualTo []) then { _roads = _far };
if (_roads isEqualTo []) exitWith {};

private _road = selectRandom _roads;
private _spawnPos = getPosATL _road;
// Face along the road, from a connected node, so the car starts on the carriageway not across it.
private _dir = getDir _road;
private _cons = roadsConnectedTo _road;
if !(_cons isEqualTo []) then { _dir = [_spawnPos, getPosATL (_cons select 0)] call BIS_fnc_dirTo };

// "NONE" so the car sits on the carriageway rather than being bounced to the verge.
private _veh = createVehicle [selectRandom _pool, _spawnPos, [], 0, "NONE"];
// Vanilla civilian cars carry a default FirstAidKit -- strip cargo so a stolen one yields nothing.
clearItemCargoGlobal _veh;
clearMagazineCargoGlobal _veh;
clearWeaponCargoGlobal _veh;
clearBackpackCargoGlobal _veh;
_veh setDir _dir;
_veh setPosATL _spawnPos;

private _driver = [_townIndex, _spawnPos, selectRandom civ_array, false] call fnc_civ_spawnUnit;
if (isNull _driver) exitWith { deleteVehicle _veh };
_driver moveInDriver _veh;

private _grp = group _driver;
_grp setBehaviour "CARELESS";
_grp setSpeedMode "LIMITED";
_veh limitSpeed 50;

// Past the player, then on to town -- arrives and moves through rather than parking on them.
private _centres = (missionNamespace getVariable ["civ_locations", []]) apply { getPos _x };
private _townPos = _centres param [_townIndex, _anchor];
{
	private _wp = _grp addWaypoint [_x, 0];
	_wp setWaypointType "MOVE";
	_wp setWaypointSpeed "LIMITED";
	_wp setWaypointBehaviour "CARELESS";
	_wp setWaypointCompletionRadius 20;
} forEach [_anchor, _townPos];

// Onto the cleanup sweep, off any roster. Flag the driver too: a driver who bailed on a panic is no
// longer crew, so the vehicle sweep would not take him with the car.
_veh setVariable ["DUWS_binMe", true];
_driver setVariable ["DUWS_binMe", true];
