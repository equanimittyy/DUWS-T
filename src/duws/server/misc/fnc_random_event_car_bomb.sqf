// Locality: server -- a vehicle-borne IED, rolled in the Hostile band (random_event_tables.hpp) so rep has
// already turned the town (docs/plans/random_events_plan.md).
//
// Driver is built here, not via fnc_civ_spawnUnit, which would add a recruit action and a flee-on-fire
// panic handler. Side stays CIVILIAN so it blends and friendly AI holds fire -- the horn and the beeline
// are the only tells. isHostile marks intent per the plan; no killed handler is attached, so the death
// costs no reputation either way.
if (!isServer) exitWith {};
params [["_townIndex", -1], ["_player", objNull]];
if (isNull _player) exitWith {};

private _pool = missionNamespace getVariable ["civ_veh_array", []];
private _bodies = missionNamespace getVariable ["civ_array", []];
if (_pool isEqualTo [] || {_bodies isEqualTo []}) exitWith {};

// Out of sight where possible, so it drives into view rather than popping in beside the player.
private _roads = [getPos _player] call fnc_civ_pickHiddenRoad;
if (_roads isEqualTo []) exitWith {};

private _road = selectRandom _roads;
private _spawnPos = getPosATL _road;
private _veh = [selectRandom _pool, _spawnPos, [_spawnPos, getPos _player] call BIS_fnc_dirTo] call fnc_civ_spawnCar;

private _grp = createGroup [CIVILIAN, true];
private _driver = _grp createUnit [selectRandom _bodies, _spawnPos, [], 0, "NONE"];
if (isNull _driver) exitWith { deleteVehicle _veh };
_driver moveInDriver _veh;
_driver setVariable ["isHostile", true, true];
_driver setVariable ["Vcm_Disable", true];   // keep an AI mod from overriding the beeline
_driver allowFleeing 0;
removeAllActions _driver;
[_driver] remoteExec ["removeAllActions", 0];

// CARELESS drives straight at a doMove target, never stopping to fight or flee. binMe reaps a torn-down run.
_grp setBehaviour "CARELESS";
_grp setCombatMode "BLUE";
_grp setSpeedMode "FULL";
_veh limitSpeed 200;
_veh setVariable ["DUWS_binMe", true];
_driver setVariable ["DUWS_binMe", true];

// DEADMAN (driver killed / hull immobilised) vs FUSE (armed within ARM_RANGE): shooting the driver buys
// distance, not a clean defuse. TIMEOUT reaps a car that reaches no one.
#define ARM_RANGE 30
#define FUSE (1 + random 2)
#define DEADMAN (2 + random 3)
#define TIMEOUT 300

[_veh, _driver, _player] spawn {
	params ["_veh", "_driver", "_player"];
	private _target = _player;
	private _fuse = -1;
	private _deadline = time + TIMEOUT;

	while { !isNull _veh && {time < _deadline} } do {
		// Immobilised or driver down: cook off where it sits.
		if (!alive _driver || {!canMove _veh}) exitWith { _fuse = DEADMAN };

		// Re-pick a live target if the first died or left; teardown when no player remains.
		if (isNull _target || {!alive _target}) then {
			private _live = allPlayers select { alive _x };
			_target = if (_live isEqualTo []) then { objNull } else { [_live, _veh] call BIS_fnc_nearestPosition };
		};

		if (!isNull _target) then {
			_driver doMove (getPos _target);
			if (random 1 < 0.45) then { _driver action ["Horn", _veh] };
			if (_veh distance _target < ARM_RANGE) exitWith { _fuse = FUSE };
		};
		sleep 1;
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
