// Locality: server -- an ambient civilian convoy: 2-3 civilian cars driving town-to-town through the picked
// player's area, reaped once no player is near (docs/plans/town_events_plan.md). No rep gate. Same road-find
// and cleanup shell as fnc_town_event_car; the cars share one group and hold column on native formation AI
// rather than the scripted convoy engine -- light enough for ambient traffic. Drivers are full civilians, so
// running one down costs reputation.
if (!isServer) exitWith {};
params [["_townIndex", -1], ["_player", objNull]];
if (isNull _player) exitWith {};

private _pool = missionNamespace getVariable ["civ_veh_array", []];
if (_pool isEqualTo []) exitWith {};

private _anchor = getPos _player;
// A road out from the player, so the column is seen arriving rather than dropped on top of them.
private _roads = _anchor nearRoads 500;
private _far = _roads select { (_anchor distance _x) > 150 };
if !(_far isEqualTo []) then { _roads = _far };
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
		_driver joinSilent _grp;
		_veh limitSpeed 50;
		_veh setVariable ["DUWS_binMe", true];
		_driver setVariable ["DUWS_binMe", true];
	};
};
if (units _grp isEqualTo []) exitWith {};

_grp setBehaviour "CARELESS";
_grp setSpeedMode "LIMITED";
_grp setFormation "COLUMN";

// Through the player's spot to a destination town, then the column is a passing sight rather than parked;
// own town if the map has only the one. binMe reaps the cars once they are away and no player is near.
private _centres = (missionNamespace getVariable ["civ_locations", []]) apply { getPos _x };
private _own = _centres param [_townIndex, _anchor];
private _dest = if (count _centres > 1) then { selectRandom (_centres - [_own]) } else { _own };
{
	private _wp = _grp addWaypoint [_x, 0];
	_wp setWaypointType "MOVE";
	_wp setWaypointSpeed "LIMITED";
	_wp setWaypointBehaviour "CARELESS";
	_wp setWaypointCompletionRadius 30;
} forEach [_anchor, _dest];
