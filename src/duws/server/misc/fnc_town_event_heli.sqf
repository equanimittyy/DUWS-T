// Locality: server -- an ambient civilian helicopter that flies over the picked player and on, reaped
// once no player is near (docs/plans/town_events_plan.md). No rep gate. Needs a civilian airframe
// (civ_heli_array); a men-only faction with no vanilla fallback yields none and the event no-ops.
// Pilot a full civilian, so downing it costs reputation.
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

// Over the player, then out the far side and away -- an overflight, not a loiter.
private _exit = _anchor getPos [1400, random 360];
{
	private _wp = _grp addWaypoint [_x, 0];
	_wp setWaypointType "MOVE";
	_wp setWaypointBehaviour "CARELESS";
	_wp setWaypointCompletionRadius 60;
} forEach [_anchor, _exit];

// Onto the cleanup sweep. Flag the pilot too: a crash survivor out of the airframe is no longer
// crew for the vehicle sweep to take with it.
_heli setVariable ["DUWS_binMe", true];
_pilot setVariable ["DUWS_binMe", true];
