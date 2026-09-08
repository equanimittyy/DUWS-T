// Locality: server only -- server/supports/fnc_fob_server.sqf on build, fnc_redeployFOBUnits on
// rebuild. A FOB's garrison is campaign property, so spawning it on the rebuilding client
// would leave it simulated there and orphaned on disconnect.
#include "..\..\shared\includes\action_style.hpp"

if (!isServer) exitWith {};

params ["_centerPos", "_fob"];

// Marks the reguard in progress and is cleared at the end of this pass. fnc_redeployFOBUnits raises
// it before it charges and reads it to turn a second click away rather than pay it back; the build
// path (fnc_fob_server) raises it here on first guard.
_fob setVariable ["FOB_guard_busy", true];

// Reguard replaces the FOB's garrison wholesale, not adds to it: read off the FOB by roster, not passed
// in, so no stale copy of the scroll action re-adds groups that already died. Server-local.
private _fobKey = _fob getVariable ["DUWS_siteKey", ""];
if (_fobKey != "") then {
	{ deleteVehicle _x } forEach ([_fobKey, "infantry"] call fnc_site_roster);
	[_fobKey, "infantry"] call fnc_site_roster_clear;
};

_safe = [(_centerPos select 0)+10, (_centerPos select 1)+10];

_groupGuard = [[0,0], WEST, [blufor_SOLDIER_X, blufor_SOLDIER_X, blufor_SOLDIER_X, blufor_SOLDIER_X],[],[],blufor_ai_skill] call BIS_fnc_spawnGroup; 
_groupGuard deleteGroupWhenEmpty true;

sleep 10;

_HQguard1 = units _groupGuard select 0;
_HQguard2 = units _groupGuard select 1;
_HQguard3 = units _groupGuard select 2;
_HQguard4 = units _groupGuard select 3;

switch (VERSION_X) do {
	case "MODERN": {
		_HQguard1 setpos [(_centerPos select 0)-6.5, (_centerPos select 1)-1.6];
		_HQguard1 setdir 270;
		_HQguard2 setpos [(_centerPos select 0)-6.5, (_centerPos select 1)-4.7];
		_HQguard2 setdir 270;
		_HQguard3 setpos [(_centerPos select 0), (_centerPos select 1)-7.58];
		_HQguard3 setdir 180;
		_HQguard4 setpos [(_centerPos select 0), (_centerPos select 1)-9];
		_HQguard4 setdir 0;
	};
};

[_HQguard1,"STAND","FULL"] call BIS_fnc_ambientAnimCombat;
[_HQguard2,"STAND_IA","FULL"] call BIS_fnc_ambientAnimCombat;
[_HQguard3,"LEAN","FULL"] call BIS_fnc_ambientAnimCombat;
[_HQguard4,"STAND","FULL"] call BIS_fnc_ambientAnimCombat;

[_groupGuard, _centerPos] call bis_fnc_taskDefend;

// One group walking the hqpatrol posture, the same circuit the HQ walks round its towers. It is the
// FOB's only moving element now.
//
// 20 m, not 10: the fortification ring puts HESCO and turrets on the 9-10 m line, so a tighter
// circuit sits inside the wall and the patrol spends it pathing through the HESCO.
#define FOB_PATROL_RADIUS 20

// One squad walking the four corners as a circuit. Raised through the token spawner on the shared
// "squad" composition, so it draws from the faction roster and pool like any other team rather than
// a hand-scaled count of one guard type. The corners are its hqpatrol anchors; WHITE combat mode is
// the patrol's own, kept after the raise so a base patrol holds fire until it is fired on.
_groupPatrol = ["squad", _centerPos, FOB_PATROL_RADIUS, "hqpatrol", _safe, "blufor",
	[0, 90, 180, 270] apply { _centerPos getPos [FOB_PATROL_RADIUS, _x] }] call fnc_spawn_team;
_groupPatrol setCombatMode "WHITE";

// Filed under the site so the poller can freeze them. Registered late rather than at build time
// because a reguard raises a fresh pair, and the roster has to describe what is standing now.
if (_fobKey != "") then {
	private _roster = [_fobKey, "infantry"] call fnc_site_roster;
	{ _roster append (units _x) } forEach [_groupGuard, _groupPatrol];
};
_fob setVariable ["FOB_guard_busy", false];

// Redeploy is a button in the FOB's request menu now (fnc_command_fill), built per client when the
// menu opens, so nothing has to be broadcast or JIP-queued from here.


