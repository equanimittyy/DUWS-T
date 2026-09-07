// Locality: server -- a vehicle-borne IED, rolled in the Hostile band (random_event_tables.hpp) so rep has
// already turned the town.
//
// An OPFOR driver in a civilian car: overtly hostile (friendly AI engages it), ramming the nearest player and,
// once inside its activation range, detonating a few seconds later wherever it has reached -- so a target juking
// it onto an obstacle cannot defuse it. An OPFOR-red world icon (fnc_random_event_ied_markers) marks it from
// range so the player reads the overt threat before it closes. Built here rather than via fnc_civ_spawnUnit,
// which would bolt on a recruit action and a flee-on-fire panic handler. Killing the driver only trades the
// run-in for a short dead-man cook-off.
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

// CARELESS/BLUE: drives the road run-in straight at the target, never peeling off to fight or flee (the
// scripted rush below handles the finish the AI won't). binMe reaps a torn-down run.
_grp setBehaviour "CARELESS";
_grp setCombatMode "BLUE";
_grp setSpeedMode "FULL";
_veh limitSpeed 200;
_veh setVariable ["DUWS_binMe", true];
_driver setVariable ["DUWS_binMe", true];

// Broadcast the car so each client draws an OPFOR-red icon over it (fnc_random_event_ied_markers), read
// further out than a roadside pile. Removed from the list on detonation or teardown.
missionNamespace setVariable ["DUWS_vbied_cars",
	(missionNamespace getVariable ["DUWS_vbied_cars", []]) + [_veh], true];

// RUSH: activation range -- inside it the car is armed and detonates for certain ARM_HOLD seconds later,
// wherever it has reached by then. No proximity fuze: the ram just drives the hull at the target for that
// window (the AI pathfinder brakes and steers around a man on foot and stops short, so the script takes the
// wheel). RAM_ACCEL: ram acceleration, capped at the hull's own maxSpeed. DEADMAN: cook-off when the driver is
// killed or the hull is immobilised (2-5 s), so shooting the driver buys distance, not a clean defuse. TIMEOUT
// reaps a car that reaches no one.
#define RUSH 30
#define ARM_HOLD 3
#define RAM_ACCEL 8
#define FUSE (0.1 + random 0.2)
#define DEADMAN (2 + random 3)
#define TIMEOUT 300

[_veh, _driver] spawn {
	params ["_veh", "_driver"];
	private _fuse = -1;
	private _deadline = time + TIMEOUT;
	private _lastMove = [0, 0, 0];
	private _armAt = -1;   // time the car entered RUSH and armed; -1 whenever it is outside RUSH
	// The hull's own top speed (config km/h -> m/s); the rush ramps up to but never past it.
	private _maxSpd = (getNumber (configFile >> "CfgVehicles" >> typeOf _veh >> "maxSpeed")) / 3.6;
	if (_maxSpd <= 0) then { _maxSpd = 30 };

	while { !isNull _veh && {time < _deadline} } do {
		// Driver down or the hull can't move: cook off where it sits.
		if (!alive _driver || {!canMove _veh}) exitWith { _fuse = DEADMAN };

		private _live = allPlayers select { alive _x };
		if (_live isEqualTo []) exitWith {};
		private _target = [_live, _veh] call BIS_fnc_nearestPosition;
		private _d = _veh distance _target;

		if (_d < RUSH) then {
			// Armed inside the activation range. Drive the hull at the target ourselves -- the AI won't ram a
			// man on foot (arma_engine_gotchas.md) -- ramping velocity at RAM_ACCEL up to maxSpeed, re-aimed each
			// tick. No proximity fuze: it rams for ARM_HOLD then blows wherever it reached, so a juking player
			// can make it miss but never defuse it.
			if (_armAt < 0) then { _armAt = time };
			if (time - _armAt > ARM_HOLD) exitWith { _fuse = FUSE };
			_driver disableAI "PATH";
			private _spd = ((vectorMagnitude (velocity _veh)) + RAM_ACCEL * 0.05) min _maxSpd;
			private _brg = _veh getDir _target;
			_veh setVelocity [(sin _brg) * _spd, (cos _brg) * _spd, (velocity _veh) select 2];
			sleep 0.05;
		} else {
			_armAt = -1;
			// Still far: hand it back to the AI to drive the roads in. Re-issue doMove only when the target has
			// moved, to spare the pathfinder a restart every tick.
			_driver enableAI "PATH";
			if ((getPos _target) distance _lastMove > 15) then {
				_lastMove = getPos _target;
				_driver doMove _lastMove;
			};
			sleep 0.5;
		};
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
