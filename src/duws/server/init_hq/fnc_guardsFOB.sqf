// Locality: server only -- server/supports/fnc_fob_server.sqf on build, fnc_redeployFOBUnits on
// rebuild. A FOB's garrison is campaign property, so spawning it on the rebuilding client
// would leave it simulated there and orphaned on disconnect.
#include "..\..\shared\includes\action_style.hpp"

if (!isServer) exitWith {};

params ["_centerPos", "_fob"];

// One reguard at a time, for the same reason as fnc_fortifyFOB: the scroll action is on every
// machine, so two players can fire it at once. No refund arm any more -- fnc_redeployFOBUnits
// reads this flag before it charges, so a second caller is turned away rather than paid back.
if (_fob getVariable ["FOB_guard_busy", false]) exitWith {};
_fob setVariable ["FOB_guard_busy", true];

// Reguard replaces the previous garrison rather than adding to it. Read off the FOB rather
// than passed in, so no copy of the scroll action holds stale groups. Server-local.
{ { deleteVehicle _x } forEach units _x; } forEach (_fob getVariable ["FOB_guardGroups", []]);

_safe = [(_centerPos select 0)+10, (_centerPos select 1)+10];

_size = 500;

// Create the guards
_groupGuard = [[0,0], WEST, [blufor_SOLDIER_X, blufor_SOLDIER_X, blufor_SOLDIER_X, blufor_SOLDIER_X],[],[],blufor_ai_skill] call BIS_fnc_spawnGroup; 
_groupGuard deleteGroupWhenEmpty true;

sleep 10;

_HQguard1 = units _groupGuard select 0;
//_HQguard1 addEventHandler ["Fired",{(_this select 0) setVehicleAmmo 1}];
_HQguard2 = units _groupGuard select 1;
//_HQguard2 addEventHandler ["Fired",{(_this select 0) setVehicleAmmo 1}];
_HQguard3 = units _groupGuard select 2;
//_HQguard3 addEventHandler ["Fired",{(_this select 0) setVehicleAmmo 1}];
_HQguard4 = units _groupGuard select 3;
//_HQguard4 addEventHandler ["Fired",{(_this select 0) setVehicleAmmo 1}];

switch (VERSION_X) do {
	case "MODERN": {
		//_HQguard1 = _groupGuard createUnit [blufor_SOLDIER_X, _centerPos, [], 0, "FORM"];
		_HQguard1 setpos [(_centerPos select 0)-6.5, (_centerPos select 1)-1.6];
		_HQguard1 setdir 270;
		//_HQguard2 = _groupGuard createUnit [blufor_SOLDIER_X, _centerPos, [], 0, "FORM"];
		_HQguard2 setpos [(_centerPos select 0)-6.5, (_centerPos select 1)-4.7];
		_HQguard2 setdir 270;
		//_HQguard3 = _groupGuard createUnit [blufor_SOLDIER_TL_X, _centerPos, [], 0, "FORM"];
		_HQguard3 setpos [(_centerPos select 0), (_centerPos select 1)-7.58];
		_HQguard3 setdir 180;
		//_HQguard4 = _groupGuard createUnit [blufor_SOLDIER_LAT_X, _centerPos, [], 0, "FORM"];
		_HQguard4 setpos [(_centerPos select 0), (_centerPos select 1)-9];
		_HQguard4 setdir 0;
	};
};

[_HQguard1,"STAND","FULL"] call BIS_fnc_ambientAnimCombat;
[_HQguard2,"STAND_IA","FULL"] call BIS_fnc_ambientAnimCombat;
[_HQguard3,"LEAN","FULL"] call BIS_fnc_ambientAnimCombat;
[_HQguard4,"STAND","FULL"] call BIS_fnc_ambientAnimCombat;

[_groupGuard, _centerPos] call bis_fnc_taskDefend;

// Patrolling Guards
//
// One group walking a fixed circuit and cycling back to its first leg, the shape the HQ patrol
// uses (init_hq/fnc_placeHQUnits.sqf). It is the FOB's only moving element now.
//
// 20 m, not the 10 this used to walk: the fortification ring puts HESCO and turrets on the 9-10 m
// line, so the old corners sat inside the wall and the patrol spent its circuit pathing through it.
#define FOB_PATROL_RADIUS 20

// The same squad the HQ walks, drawn from the same pool: a FOB is a small base, not a different
// kind of thing, and the single soldier this used to send round was a circuit a two-man probe could
// walk straight through. The pool is set under an HQ_ prefix because that is where it is written
// (init_hq/fnc_BluHQinit.sqf), not because only the HQ may read it; defaulted, because a FOB built
// before that ran should still get a patrol rather than throw.
private _patrolTypes = missionNamespace getVariable ["HQ_redeploy_guardTypes", [blufor_SOLDIER_X]];
private _patrolUnits = [];
for "_i" from 1 to base_patrol_squad do { _patrolUnits pushBack (selectRandom _patrolTypes); };

_groupPatrol = [_safe, WEST, _patrolUnits,[],[],blufor_ai_skill] call BIS_fnc_spawnGroup;
_groupPatrol deleteGroupWhenEmpty true;
_groupPatrol setCombatMode "WHITE";

{
	private _wp = _groupPatrol addWaypoint [_centerPos getPos [FOB_PATROL_RADIUS, _x], 0];
	_wp setWaypointType "MOVE";
	_wp setWaypointBehaviour "SAFE";
	_wp setWaypointSpeed "LIMITED";
} forEach [0, 90, 180, 270];

// Back to the first leg. The cycle waypoint is what makes the circuit repeat; without it the
// group stops on the last corner and stands there.
_wp = _groupPatrol addWaypoint [_centerPos getPos [FOB_PATROL_RADIUS, 0], 0];
_wp setWaypointType "CYCLE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointSpeed "LIMITED";


_fob setVariable ["FOB_guardGroups", [_groupGuard, _groupPatrol]];
_fob setVariable ["FOB_guard_busy", false];

// Redeploy is a row in the FOB's request menu now (fnc_base_menu_fill), built per client when the
// menu opens, so nothing has to be broadcast or JIP-queued from here.


