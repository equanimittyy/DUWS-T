// Locality: server -- a vehicle-borne IED, rolled in the Hostile band (random_event_tables.hpp) so rep has
// already turned the town.
//
// An OPFOR driver in a civilian car beelines at the nearest player and detonates on a short fuse once it
// closes within ARM_RANGE -- overtly hostile, so friendly AI engages it and an OPFOR-red world icon
// (fnc_random_event_ied_markers) warns of it from range. Built here, not via fnc_civ_spawnUnit, which would
// bolt on a recruit action and a flee-on-fire panic handler; killing the driver only trades the run-in for a
// short dead-man cook-off.
if (!isServer) exitWith {};
params [["_townIndex", -1], ["_player", objNull]];
if (isNull _player) exitWith {};

private _pool = missionNamespace getVariable ["civ_veh_array", []];
private _bodies = missionNamespace getVariable ["civ_array", []];
if (_pool isEqualTo [] || {_bodies isEqualTo []}) exitWith {};

// Out of sight where possible, so it drives into view rather than popping in beside the player.
private _roads = [getPos _player] call fnc_civ_pickHiddenRoad;
if (_roads isEqualTo []) exitWith {};

private _spawnPos = getPosATL (selectRandom _roads);
private _veh = [selectRandom _pool, _spawnPos, [_spawnPos, getPos _player] call BIS_fnc_dirTo] call fnc_civ_spawnCar;
// Else the faction reskin (fnc_vehiclePostInit) redresses the driver as an OPFOR soldier.
_veh setVariable ["DUWS_keepCrewDress", true];

private _grp = createGroup [CIVILIAN, true];
private _driver = _grp createUnit [selectRandom _bodies, _spawnPos, [], 0, "NONE"];
if (isNull _driver) exitWith { deleteVehicle _veh };
// Civ body flipped to EAST by re-grouping, not by class: a createUnit straight into an EAST group reads
// Civilian in Zeus and won't fire (arma_engine_gotchas.md). Emptied civ group self-deletes.
[_driver] joinSilent (createGroup [EAST, true]);
_grp = group _driver;
_driver moveInDriver _veh;
_driver setVariable ["Vcm_Disable", true];   // keep an AI mod from overriding the beeline
_driver allowFleeing 0;

// CARELESS/BLUE/FULL: drives the run-in without stopping to fight or flee; the scripted rush handles the
// close-in ram the AI won't. binMe reaps a torn-down run.
_grp setBehaviour "CARELESS";
_grp setCombatMode "BLUE";
_grp setSpeedMode "FULL";
_veh limitSpeed 200;
_veh setVariable ["DUWS_binMe", true];
_driver setVariable ["DUWS_binMe", true];

// Broadcast the car so clients draw its OPFOR-red icon (fnc_random_event_ied_markers); pulled from the list
// on detonation or teardown.
missionNamespace setVariable ["DUWS_vbied_cars",
	(missionNamespace getVariable ["DUWS_vbied_cars", []]) + [_veh], true];

#define ARM_RANGE 20             // arms when the hull gets this close to the target
#define FUSE (1 + random 2)      // run-in delay from arming to the blast
#define DEADMAN (2 + random 3)   // driver-killed / hull-stuck cook-off: shooting the driver buys distance
#define TIMEOUT 300              // reap a car that reaches no one

[_veh, _driver] spawn {
	params ["_veh", "_driver"];
	private _fuse = -1;
	private _deadline = time + TIMEOUT;
	private _lastMove = [0, 0, 0];

	while { !isNull _veh && {time < _deadline} } do {
		// Driver down or the hull can't move: cook off where it sits.
		if (!alive _driver || {!canMove _veh}) exitWith { _fuse = DEADMAN };

		private _live = allPlayers select { alive _x };
		if (_live isEqualTo []) exitWith {};
		private _target = [_live, _veh] call BIS_fnc_nearestPosition;

		// Re-issue doMove only when the target moved -- a restart every tick thrashes the pathfinder.
		if ((getPos _target) distance _lastMove > 15) then {
			_lastMove = getPos _target;
			_driver doMove _lastMove;
		};

		// Armed on the hull's distance, not the seated driver's.
		if (_veh distance _target < ARM_RANGE) exitWith { _fuse = FUSE };
		sleep 0.5;
	};

	// No fuse: timed out or ran dry of targets.
	if (_fuse < 0) exitWith {
		missionNamespace setVariable ["DUWS_vbied_cars",
			(missionNamespace getVariable ["DUWS_vbied_cars", []]) - [_veh], true];
		if (!isNull _driver) then { deleteVehicle _driver };
		if (!isNull _veh) then { deleteVehicle _veh };
	};

	sleep _fuse;
	// Drop the icon the moment it commits to blowing, ahead of the wreck.
	missionNamespace setVariable ["DUWS_vbied_cars",
		(missionNamespace getVariable ["DUWS_vbied_cars", []]) - [_veh], true];
	if (!isNull _veh) then {
		// Spawned above the hull and shoved down: a munition created at rest never fuzes (arma_engine_gotchas.md).
		// Mk82, the laser-guided bomb support round, up from the 82mm mortar.
		private _p = getPosATL _veh;
		private _bomb = createVehicle ["Bo_Mk82", [_p select 0, _p select 1, (_p select 2) + 0.5], [], 0, "CAN_COLLIDE"];
		_bomb setVelocity [0, 0, -30];
		_veh setDamage 1;   // car cooks off itself, not just shredded by the bomb
	};
};
