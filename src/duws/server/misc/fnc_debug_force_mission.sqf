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

// Run the type's own site-finder (fnc_<name>_site, default the accept-all generic) on each candidate,
// exactly as the strategic-map picker does, so a forced mission lands only where a picked one could --
// a town for intel, clear ground for the rest -- rather than spawning somewhere the thread then aborts
// out of. Candidates come from the same safe-location sampler, with an HQ ring as a backstop; a finder
// that never accepts (intel with no town-plus-enemy-zone in reach) fails the force cleanly.
private _finderName = (_threadName select [0, (count _threadName) - 8]) + "_site";
private _finder = missionNamespace getVariable [_finderName, fnc_site_generic];

private _pos = [];
private _tries = 0;
while { _pos isEqualTo [] && {_tries < 30} } do {
	_tries = _tries + 1;
	private _cand = [] call fnc_findSafeMissionPos;
	if (_cand isEqualTo []) then {
		private _ring = PosOfBLUHQ getPos [1500 + random 1500, random 360];
		if !([_ring, 400] call fnc_pos_claimed) then { _cand = _ring };
	};
	if !(_cand isEqualTo []) then {
		private _site = [_cand] call _finder;
		if !(_site isEqualTo []) then { _pos = _site select 0 };
	};
};
if (_pos isEqualTo []) exitWith {
	["ERROR", "MISSION", format ["debug force: %1 found no site its finder accepts in %2 tries", _threadName, _tries]] call fnc_log;
};

missionNamespace setVariable [format ["mission_cooldown_%1", _type], 0, true];
Mission_available = true;
publicVariable "Mission_available";

private _name = [0] call fnc_random_name;
["INFO", "MISSION", format ["debug force: type=%1 name=%2 pos=%3", _type, _name, _pos]] call fnc_log;
[_pos, _name] spawn _thread;
