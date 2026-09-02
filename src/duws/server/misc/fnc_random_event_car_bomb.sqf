// Locality: server -- a vehicle-borne IED, rolled in the Hostile band (random_event_tables.hpp) so rep has
// already turned the town (docs/plans/random_events_plan.md).
//
// An OPFOR driver in a civilian car: overtly hostile (friendly AI engages it), beelining at the nearest
// player, horn blaring, until it detonates. Built here rather than via fnc_civ_spawnUnit, which would bolt
// on a recruit action and a flee-on-fire panic handler. Killing the driver only trades the run-in for a
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

private _grp = createGroup [EAST, true];
private _driver = _grp createUnit [selectRandom _bodies, _spawnPos, [], 0, "NONE"];
if (isNull _driver) exitWith { deleteVehicle _veh };
_driver moveInDriver _veh;
_driver setVariable ["Vcm_Disable", true];   // keep an AI mod from overriding the beeline
_driver allowFleeing 0;

// CARELESS/BLUE: drives straight at a doMove target, never stopping to fight or flee. binMe reaps a
// torn-down run.
_grp setBehaviour "CARELESS";
_grp setCombatMode "BLUE";
_grp setSpeedMode "FULL";
_veh limitSpeed 200;
_veh setVariable ["DUWS_binMe", true];
_driver setVariable ["DUWS_binMe", true];

// FUSE: run-in delay once armed within ARM_RANGE (1-3 s). DEADMAN: cook-off when the driver is killed or
// the hull is immobilised (2-5 s), so shooting the driver buys distance, not a clean defuse. TIMEOUT reaps
// a car that reaches no one.
#define ARM_RANGE 30
#define FUSE (1 + random 2)
#define DEADMAN (2 + random 3)
#define TIMEOUT 300

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

		// Re-issue doMove only when the target has moved, to spare the pathfinder a restart every tick.
		if ((getPos _target) distance _lastMove > 15) then {
			_lastMove = getPos _target;
			_driver doMove _lastMove;
		};
		if (random 1 < 0.3) then { [_driver, ["Horn", _veh]] remoteExec ["action", 0] };

		// Armed on the hull's distance, not the seated driver's.
		if (_veh distance _target < ARM_RANGE) exitWith { _fuse = FUSE };
		sleep 0.5;
	};

	// No fuse: timed out or ran dry of targets.
	if (_fuse < 0) exitWith {
		if (!isNull _driver) then { deleteVehicle _driver };
		if (!isNull _veh) then { deleteVehicle _veh };
	};

	sleep _fuse;
	if (!isNull _veh) then {
		// Spawned above the hull and shoved down: a shell created at rest never fuzes (arma_engine_gotchas.md).
		private _p = getPosATL _veh;
		private _bomb = createVehicle ["Sh_82mm_AMOS", [_p select 0, _p select 1, (_p select 2) + 0.5], [], 0, "CAN_COLLIDE"];
		_bomb setVelocity [0, 0, -30];
	};
};
