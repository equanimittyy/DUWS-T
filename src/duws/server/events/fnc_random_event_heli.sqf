// Locality: server -- an ambient civilian helicopter that flies over the picked player, then loops a
// wandering circuit across the map until the cleanup sweep reaps it.
// No rep gate. Needs a civilian airframe (civ_heli_array); a men-only faction with no vanilla fallback
// yields none and the event no-ops. Pilot a full civilian, so downing it costs reputation.
if (!isServer) exitWith {};
params [["_townIndex", -1], ["_player", objNull]];
if (isNull _player) exitWith {};

private _pool = missionNamespace getVariable ["civ_heli_array", []];
if (_pool isEqualTo []) exitWith {
	["INFO", "CIV", "civ_heli event skipped: no civilian airframe for this faction"] call fnc_log;
};

#define CIV_HELI_ALT 120
private _anchor = getPos _player;
private _spawnPos = _anchor getPos [1400, random 360];
_spawnPos set [2, CIV_HELI_ALT];

// "FLY" spawns it airborne and moving rather than dropped on the deck; flyInHeight then holds the cruise.
private _heli = createVehicle [selectRandom _pool, _spawnPos, [], 0, "FLY"];
_heli setPosATL _spawnPos;
_heli flyInHeight CIV_HELI_ALT;

private _pilot = [_townIndex, _spawnPos, selectRandom civ_array, false] call fnc_civ_spawnUnit;
if (isNull _pilot) exitWith { deleteVehicle _heli };
_pilot moveInDriver _heli;

private _grp = group _pilot;
_grp setBehaviour "CARELESS";
_grp setCombatMode "BLUE";

// Over the player first, then a wandering circuit across the map so it keeps flying until the cleanup
// sweep reaps it, rather than leaving the area and idling. Points held off the map edges; not a circle.
private _ws = worldSize;
private _route = [[_anchor select 0, _anchor select 1, CIV_HELI_ALT]];
for "_i" from 1 to 4 do {
	_route pushBack [_ws * (0.1 + random 0.8), _ws * (0.1 + random 0.8), CIV_HELI_ALT];
};
[_grp, _route, 120] call fnc_civ_loopRoute;

// Onto the cleanup sweep. Flag the pilot too: a crash survivor out of the airframe is no longer
// crew for the vehicle sweep to take with it.
_heli setVariable ["DUWS_binMe", true];
_pilot setVariable ["DUWS_binMe", true];
