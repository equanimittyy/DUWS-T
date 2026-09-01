// Locality: server -- an ambient civilian convoy: 2-3 civilian cars driving a looping town-to-town circuit
// through the picked player's area, reaped once no player is near (docs/plans/town_events_plan.md). No rep gate. Same road-find
// and cleanup shell as fnc_town_event_car; the cars share one group and hold column on native formation AI
// rather than the scripted convoy engine -- light enough for ambient traffic. Drivers are full civilians, so
// running one down costs reputation.
if (!isServer) exitWith {};
params [["_townIndex", -1], ["_player", objNull]];
if (isNull _player) exitWith {};

private _pool = missionNamespace getVariable ["civ_veh_array", []];
if (_pool isEqualTo []) exitWith {};

// Roads out of the player's sight where possible, so the column stands up unseen and drives into view.
private _roads = [getPos _player] call fnc_civ_pickHiddenRoad;
if (_roads isEqualTo []) exitWith {};

private _road = selectRandom _roads;
private _start = getPosATL _road;
private _dir = [_road] call fnc_civ_roadDir;

private _grp = createGroup [CIVILIAN, true];
private _count = 2 + floor random 2;
// Seated in a line back along the road behind the lead so they do not spawn stacked; fnc_convoy_fit steps
// each clear of a wall or an already-spawned car before createVehicle, which is what stops a tight spawn
// detonating. Native COLUMN pulls the line back onto the road once they roll, so a point that lands off the
// verge on a bend straightens out rather than needing an exact road seat.
for "_i" from 0 to (_count - 1) do {
	private _class = selectRandom _pool;
	private _pos = [_start getPos [_i * 8, _dir + 180], _class] call fnc_convoy_fit;
	private _veh = [_class, _pos, _dir] call fnc_civ_spawnCar;
	private _driver = [_townIndex, _pos, selectRandom civ_array, false] call fnc_civ_spawnUnit;
	if (isNull _driver) then {
		deleteVehicle _veh;
	} else {
		_driver moveInDriver _veh;
		// Into the one group so native formation trails them behind the lead; each driver's own
		// (auto-delete) group empties and goes.
		[_driver] joinSilent _grp;
		_veh limitSpeed 50;
		_veh setVariable ["DUWS_binMe", true];
		_driver setVariable ["DUWS_binMe", true];
	};
};
if (units _grp isEqualTo []) exitWith {};

_grp setBehaviour "CARELESS";
_grp setSpeedMode "LIMITED";
_grp setFormation "COLUMN";

// A looping town-to-town circuit so the column keeps rolling until the cleanup sweep reaps it, rather
// than parking at one destination. binMe reaps the cars once they are away and no player is near. Fewer
// than five towns on the map shortens the loop to what exists.
private _centres = (missionNamespace getVariable ["civ_locations", []]) apply { getPos _x };
private _route = (_centres call BIS_fnc_arrayShuffle) select [0, 5 min count _centres];
[_grp, _route, 50] call fnc_civ_loopRoute;
