// Locality: server -- client/dialog/fnc_debug_mission_menu.sqf remoteExecs it to target 2.

// Forces one side-mission type to start now. The type's cooldown and the global mission lock are
// *cleared* rather than bypassed, so the thread still opens through fnc_mission_begin exactly as
// a player-requested mission does -- a debug path that skipped that gate would stop exercising
// the code the real one runs, which is the opposite of what a test tool is for.
//
// Index order is fnc_mission_begin's mission type, not the stratmap listing order.
params ["_type"];
if (!isServer) exitWith {};

private _defs = [
#include "..\..\shared\includes\mission_types.hpp"
];
if (_type < 0 || {_type >= count _defs}) exitWith {
	["ERROR", "MISSION", format ["debug force: no mission type %1", _type]] call fnc_log;
};

private _threadName = (_defs select _type) select 0;
private _thread = missionNamespace getVariable [_threadName, {}];
if (_thread isEqualTo {}) exitWith {
	["ERROR", "MISSION", format ["debug force: %1 is not registered", _threadName]] call fnc_log;
};

// Site it through the same function the strategic-map picker uses (fnc_mission_findSite): the type's
// finder run over the real frontline-weighted candidate search, so a forced mission lands only where a
// picked one could -- a town for intel, frontline ground for the rest -- rather than somewhere the
// thread then aborts out of. Anchored on HQ, since the force runs server-side with no requesting player,
// and offered as an easy (frontline-seam) mission. A finder that never accepts -- intel with no
// town-plus-enemy-zone in reach -- returns [] and the force fails cleanly.
private _pos = [_threadName, false, PosOfBLUHQ, []] call fnc_mission_findSite;
if (_pos isEqualTo []) exitWith {
	["ERROR", "MISSION", format ["debug force: %1 found no site its finder accepts", _threadName]] call fnc_log;
};

missionNamespace setVariable [format ["mission_cooldown_%1", _type], 0, true];
Mission_available = true;
publicVariable "Mission_available";

private _name = [0] call fnc_random_name;
["INFO", "MISSION", format ["debug force: type=%1 name=%2 pos=%3", _type, _name, _pos]] call fnc_log;
[_pos, _name] spawn _thread;
