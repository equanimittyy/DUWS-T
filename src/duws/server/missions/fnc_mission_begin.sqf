// Opens every side-mission thread: cooldown gate, cooldown stamp, and the mission lock.
// Returns false when the caller must abort -- the caller has to exit itself, because
// neither exitWith nor breakOut inside a called function can terminate its caller's scope.
// The 17 copies this replaces tried to, via `breakOut "main"` into a scope no thread
// declares, so a mission on cooldown unwound through an undefined scope name.
// _requester is remoteExecutedOwner read in the calling thread -- it must be sampled
// there, in the scope remoteExec actually entered. 0 means the thread was called
// locally, in which case a plain hint is the only machine there is to reach.
params ["_missionType", "_MissionPos", "_mission_name", ["_requester", 0]];
private _remaining = [_missionType] call fnc_mission_cooldown_left;
if (_remaining > 0) exitWith {
	// Floored both, and the units are minutes and seconds: the clock is fractional, so an
	// unfloored remainder reaches format at full precision and the hint reads "27 min 3.41 s".
	private _parts = [floor (_remaining / 60), floor (_remaining % 60)];
	// Localised on the receiving machine: the server's language is not the player's.
	if (_requester > 0) then {
		[_parts, {
			hint format [localize "STR_DUWS_T_MISSION_COOLDOWN", _this select 0, _this select 1];
		}] remoteExec ["spawn", _requester];
	} else {
		hint format [localize "STR_DUWS_T_MISSION_COOLDOWN", _parts select 0, _parts select 1];
	};
	["DEBUG", "MISSION", format ["type=%1 refused, %2 s of cooldown left",
		_missionType, round _remaining]] call fnc_log;
	false
};
missionNamespace setVariable [format ["mission_cooldown_%1", _missionType],
	time + mission_cooldown_seconds, true];
// Holds off the next mission until this thread finishes; each thread clears it on exit.
Mission_available = false;
publicVariable "Mission_available";
// Which mission instance this is: fnc_mission_claim stamps it, fnc_mission_cleanup deletes by it.
// Server-local, and only this line moves it -- which is what lets the claim sites leave it
// implicit, since it cannot advance while Mission_available is false.
DUWS_mission_token = (missionNamespace getVariable ["DUWS_mission_token", 0]) + 1;
["INFO", "MISSION", format ["start type=%1 name=%2 pos=%3 token=%4",
	_missionType, _mission_name, _MissionPos, DUWS_mission_token]] call fnc_log;
true
