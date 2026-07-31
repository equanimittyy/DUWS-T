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
["INFO", "MISSION", format ["start type=%1 name=%2 pos=%3",
	_missionType, _mission_name, _MissionPos]] call fnc_log;
// Every mission generates an operation name and, until now, only ever showed it in the task
// list. Announced here rather than in the seventeen threads: this is the one line all of
// them pass through, so a card added anywhere else would cover some missions and not others.
// Typed rather than titleText'd, to match the card the campaign opens with. Spawned on each
// client rather than remoteExec'd straight to BIS_fnc_typeText: it sleeps between characters,
// which throws in the unscheduled environment remoteExec would call it in.
// The hold is the line's own third element, not a trailing argument: BIS_fnc_typeText's second
// and third arguments are screen coordinates, so a hold passed there types the card two screens
// below the bottom edge and nobody sees it. Four seconds, because the default puts the last
// character on screen and takes the line away again.
[_mission_name, {
	[[[toUpper _this, "<t align='center' shadow='1' size='1'>%1</t>", 4]]] spawn BIS_fnc_typeText;
}] remoteExec ["spawn", [0,-2] select isDedicated];
// Under the card, and one of only two places music plays -- the other is the insertion flight.
// Double brackets: playMusic is a unary command whose one argument is an array, so written flat
// remoteExec hands it the string alone and it throws on the type.
[["LeadTrack02_F", 0]] remoteExec ["playMusic", [0,-2] select isDedicated];
true
