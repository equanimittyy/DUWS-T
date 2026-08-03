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

private _pos = [] call fnc_findSafeMissionPos;
if (_pos isEqualTo []) then {
	// The finder samples named map locations and comes back empty when every one of them is
	// too near a zone, a town or the HQ. A ring around the HQ is not sited as carefully, but a
	// forced mission that refuses to start teaches a tester nothing -- so it still has to clear
	// the same ground, which is what the retries are for.
	for "_i" from 1 to 20 do {
		private _ring = PosOfBLUHQ getPos [1500 + random 1500, random 360];
		if !([_ring, 400] call fnc_pos_claimed) exitWith { _pos = _ring };
	};
	["WARN", "MISSION", format ["debug force: no safe location, fell back to an HQ ring at %1", _pos]] call fnc_log;
};
if (_pos isEqualTo []) exitWith {
	["ERROR", "MISSION", "debug force: nowhere clear of every zone and town to put a mission"] call fnc_log;
};

missionNamespace setVariable [format ["mission_cooldown_%1", _type], 0, true];
Mission_available = true;
publicVariable "Mission_available";

private _name = [0] call fnc_random_name;
["INFO", "MISSION", format ["debug force: type=%1 name=%2 pos=%3", _type, _name, _pos]] call fnc_log;
[_pos, _name] spawn _thread;
