// Locality: server -- a vehicle-borne IED, rolled in the Hostile band (random_event_tables.hpp) so rep has
// already turned the town.
//
// An OPFOR driver in a civilian car: overtly hostile (friendly AI engages it), ramming the nearest player and
// detonating on contact, an OPFOR-red world icon (fnc_random_event_ied_markers) marking it from range so
// the player reads the overt threat before it closes. Built here rather than via fnc_civ_spawnUnit, which would bolt
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

// CARELESS/BLUE: drives straight at a doMove target, never stopping to fight or flee. binMe reaps a
// torn-down run.
_grp setBehaviour "CARELESS";
_grp setCombatMode "BLUE";
_grp setSpeedMode "FULL";
_veh limitSpeed 200;
_veh setVariable ["DUWS_binMe", true];
_driver setVariable ["DUWS_binMe", true];

// Broadcast the car so each client draws an OPFOR-red icon over it (fnc_random_event_ied_markers), read
// further out than a roadside pile. Removed from the list on detonation or teardown; the honk was unreliable.
missionNamespace setVariable ["DUWS_vbied_cars",
	(missionNamespace getVariable ["DUWS_vbied_cars", []]) + [_veh], true];

// ARM_RANGE: contact distance -- it rams the target and blows near-instant (FUSE), not at a standoff. DEADMAN:
// cook-off when the driver is killed or the hull is immobilised (2-5 s), so shooting the driver buys distance,
// not a clean defuse. TIMEOUT reaps a car that reaches no one.
#define ARM_RANGE 7
#define FUSE (0.1 + random 0.2)
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

		// Ram: detonate on contact (ARM_RANGE, the hull reaching the target), not at a standoff. Poll fast
		// while closing so the arm window is not jumped at ramming speed.
		private _d = _veh distance _target;
		if (_d < ARM_RANGE) exitWith { _fuse = FUSE };
		sleep ([0.5, 0.05] select (_d < 80));
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
		// Spawned above the hull and shoved down: a shell created at rest never fuzes (arma_engine_gotchas.md).
		// 155mm, the artillery-support shell (supports_radio_modern.hpp), up from the 82mm mortar.
		private _p = getPosATL _veh;
		private _bomb = createVehicle ["Sh_155mm_AMOS", [_p select 0, _p select 1, (_p select 2) + 0.5], [], 0, "CAN_COLLIDE"];
		_bomb setVelocity [0, 0, -30];
		_veh setDamage 1;   // car cooks off itself, not just shredded by the shell
	};
};
