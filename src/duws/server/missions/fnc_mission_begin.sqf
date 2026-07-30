// Opens every side-mission thread: cooldown gate, cooldown stamp, and the mission lock.
// Returns false when the caller must abort -- the caller has to exit itself, because
// neither exitWith nor breakOut inside a called function can terminate its caller's scope.
// The 17 copies this replaces tried to, via `breakOut "main"` into a scope no thread
// declares, so a mission on cooldown unwound through an undefined scope name.
// _requester is remoteExecutedOwner read in the calling thread -- it must be sampled
// there, in the scope remoteExec actually entered. 0 means the thread was called
// locally, in which case a plain hint is the only machine there is to reach.
params ["_missionType", "_MissionPos", "_mission_name", ["_requester", 0], ["_cooldown", 3600]];
private _var = format ["mission_cooldown_%1", _missionType];
private _until = missionNamespace getVariable [_var, 0];
if (_until > diag_tickTime) exitWith {
	private _remaining = _until - diag_tickTime;
	// Floor the seconds too: diag_tickTime is fractional, so an unfloored remainder reaches
	// format at full precision and the hint reads "59 min 0.000381 sec".
	private _parts = [floor (_remaining / 60), floor (_remaining % 60)];
	// Localised on the receiving machine: the server's language is not the player's.
	if (_requester > 0) then {
		[_parts, {
			hint format [localize "STR_DUWS_T_MISSION_COOLDOWN", _this select 0, _this select 1];
		}] remoteExec ["spawn", _requester];
	} else {
		hint format [localize "STR_DUWS_T_MISSION_COOLDOWN", _parts select 0, _parts select 1];
	};
	["DEBUG", "MISSION", format ["type=%1 refused, %2s of cooldown left",
		_missionType, round _remaining]] call fnc_log;
	false
};
missionNamespace setVariable [_var, diag_tickTime + _cooldown, true];
// Holds off the next mission until this thread finishes; each thread clears it on exit.
Mission_available = false;
publicVariable "Mission_available";
["INFO", "MISSION", format ["start type=%1 name=%2 pos=%3",
	_missionType, _mission_name, _MissionPos]] call fnc_log;
// Every mission generates an operation name and, until now, only ever showed it in the task
// list. Announced here rather than in the seventeen threads: this is the one line all of
// them pass through, so a card added anywhere else would cover some missions and not others.
// Typed rather than titleText'd, to match the card the campaign opens with. Spawned on each
// client rather than remoteExec'd straight to BIS_fnc_typeText: it sleeps between characters,
// which throws in the unscheduled environment remoteExec would call it in.
[_mission_name, {
	[[[toUpper _this, "<t align='center' shadow='1' size='1'>%1</t>"]]] spawn BIS_fnc_typeText;
}] remoteExec ["spawn", [0,-2] select isDedicated];
true
