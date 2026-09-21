// Locality: server -- a hostile OPFOR car: stands up out of sight, drives past the picked player, then
// withdraws to the nearest OPFOR-held zone and idles. Rolled in the
// Hostile band; the runner holds it off a player inside BLUFOR territory.
if (!isServer) exitWith {};
params [["_townIndex", -1], ["_player", objNull]];
if (isNull _player) exitWith {};

if ((call DUWS_fnc_opforGroupCount) >= DUWS_zoneGroupCeiling) exitWith {};

private _class = ["car", "OPF"] call DUWS_fnc_tokenClass;
if (_class isEqualTo "") exitWith {};

// Out of sight where possible, so it drives into view rather than popping in beside the player.
private _roads = [getPos _player] call fnc_civ_pickHiddenRoad;
if (_roads isEqualTo []) exitWith {};
private _spawnPos = getPosATL (selectRandom _roads);

// posture none: no patrol circuit, so the drive-past waypoints below are its only orders.
private _grp = [_class, _spawnPos, 0, "none", _spawnPos, "opfor"] call fnc_spawn_vehicle;
if (isNull _grp) exitWith {};
private _veh = vehicle (units _grp select 0);

#define LIFETIME 900

// A point past the player on the car's line of approach, snapped to the nearest road so the leg stays on
// tarmac rather than cutting cross-country to it.
private _ppos = getPos _player;
private _past = _ppos getPos [300, _spawnPos getDir _ppos];
private _pastRoads = _past nearRoads 250;
if !(_pastRoads isEqualTo []) then {
	_past = getPosATL ([_pastRoads, [_past], {_input0 distance2D _x}, "ASCEND"] call BIS_fnc_sortBy select 0);
};

// fnc_spawn_vehicle seats every hull at heading 0, crosswise on the carriageway until the drive-past
// waypoint swings it round. Seat it on the road point facing that waypoint from the off.
_veh setDir ([_spawnPos, _past] call BIS_fnc_dirTo);
_veh setPosATL _spawnPos;

private _wp1 = _grp addWaypoint [_past, 0];
_wp1 setWaypointType "MOVE";
_wp1 setWaypointBehaviour "AWARE";
_wp1 setWaypointSpeed "LIMITED";

// Withdraw to the nearest OPFOR-held zone and hold there; the last waypoint completing leaves it idling.
if !(WARCOM_zones_controled_by_OPFOR isEqualTo []) then {
	private _zone = [WARCOM_zones_controled_by_OPFOR, [_past], {_input0 distance2D _x}, "ASCEND"] call BIS_fnc_sortBy select 0;
	private _wp2 = _grp addWaypoint [_zone, 30];
	_wp2 setWaypointType "MOVE";
	_wp2 setWaypointBehaviour "AWARE";
	_wp2 setWaypointSpeed "LIMITED";
};

_grp setBehaviour "AWARE";
_grp setSpeedMode "LIMITED";

_veh setVariable ["DUWS_binMe", true];
_veh setVariable ["DUWS_binAt", time + LIFETIME];
{
	_x setVariable ["DUWS_binMe", true];
	_x setVariable ["DUWS_binAt", time + LIFETIME];
} forEach units _grp;
