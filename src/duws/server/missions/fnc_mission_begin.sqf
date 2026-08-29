// Opens every side-mission thread: the start gate, the gate stamp, and the mission lock.
// Returns false when the caller must abort -- exitWith/breakOut inside a called function cannot unwind
// the caller's scope, so the caller must exit itself. _requester is remoteExecutedOwner, sampled in the
// calling scope (0 means called locally, so a plain hint is the only machine to reach).
params ["_missionType", "_MissionPos", "_mission_name", ["_requester", 0]];
private _remaining = [] call fnc_mission_gate_left;
if (_remaining > 0) exitWith {
	// The in-game clock time the gate opens, formatted server-side: a plain "HH:MM" string,
	// language-independent, so the receiving machine only slots it into its own localised line.
	private _openTime = [] call fnc_mission_gate_time;
	// Localised on the receiving machine: the server's language is not the player's.
	if (_requester > 0) then {
		[_openTime, {
			hint format [localize "STR_DUWS_T_MISSION_COOLDOWN", _this];
		}] remoteExec ["spawn", _requester];
	} else {
		hint format [localize "STR_DUWS_T_MISSION_COOLDOWN", _openTime];
	};
	["DEBUG", "MISSION", format ["type=%1 refused, %2 in-game h until the gate opens",
		_missionType, _remaining]] call fnc_log;
	false
};
// Reward/name/deadline globals below aren't bound to the mission -- each start overwrites them, safe
// only while Mission_available gates a second start out. If one's already live, its reward gets clobbered.
if !(missionNamespace getVariable ["Mission_available", true]) then {
	["ERROR", "MISSION", format
		["Mission type=%1 starting while another is still live -- reward globals will be clobbered",
		_missionType]] call fnc_log;
};
// Stamp the gate at the start of every mission: the next one waits three in-game hours from here,
// measured on the campaign clock so a rest skips it. Broadcast so the readout and map agree.
DUWS_lastMissionStartDate = dateToNumber date;
publicVariable "DUWS_lastMissionStartDate";
// Holds off the next mission until this thread finishes; each thread clears it on exit.
Mission_available = false;
publicVariable "Mission_available";
// Which mission instance this is: fnc_mission_claim stamps it, fnc_mission_cleanup deletes by it.
// Server-local, and only this line moves it -- which is what lets the claim sites leave it
// implicit, since it cannot advance while Mission_available is false.
DUWS_mission_token = (missionNamespace getVariable ["DUWS_mission_token", 0]) + 1;
["INFO", "MISSION", format ["start type=%1 name=%2 pos=%3 token=%4",
	_missionType, _mission_name, _MissionPos, DUWS_mission_token]] call fnc_log;

// Reward and deadline for this type, read from the one table so a thread never restates them. Set
// here, on the single chokepoint every thread already calls first with its own index, so the threads
// carry no reward literals and no launcher argument has to thread the numbers through. DUWS_curReward
// / DUWS_curDeadlineAt hold for exactly this mission: nothing else runs while Mission_available is
// false, so a thread reads them any time before it ends.
private _missionDefs = [
#include "..\..\shared\includes\mission_types.hpp"
];
(_missionDefs select _missionType) params ["", "_mnameKey", "", "", "", "", "_mcp", "_map", "_mrep", "_mdl", "", "_mobj", ["_mnote", ""]];
DUWS_curReward = [_mcp, _map, _mrep];
// Name key, objective and optional note key for the briefing stats block -- same validity window as the
// reward and deadline above.
DUWS_curNameKey = _mnameKey;
DUWS_curObjective = _mobj;
DUWS_curNoteKey = _mnote;
_mdl params ["_dlMinH", "_dlMaxH"];
// Rolled once at the mission's start, in 5-minute steps of in-game time, so the enforced deadline
// sits behind the band the map advertised. The table's hours become steps here (x12: twelve 5-minute
// steps to the hour); fnc_time_deadline is the shared shape deadlines and timed triggers both use,
// and holds the deadline in in-game time.
DUWS_curDeadlineAt = [round (_dlMinH * 12), round (_dlMaxH * 12)] call fnc_time_deadline;

true
