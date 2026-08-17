// Locality: server -- every mission thread runs there, and the JIP keys are the server's to own.

// BIS_fnc_taskCreate does not synchronise itself. A plain server-side call leaves the task on
// the server, where only a hosting player -- whose client is the server -- ever sees it, and the
// state change that follows minutes later then lands on clients holding no such task and is
// dropped without an error. Broadcasting the creation is what makes both halves land.
params ["_taskId", "_description", "_title", "_destination", ["_type", "unknown"]];
if (!isServer) exitWith {};

// Journal footer, built once here so all threads share it. Order: the mission body (passed in), a blank
// line and the deadline as an in-game wall clock, the optional Note line, then a divider and the stats
// block -- mission name, type, reward, time. Only the journal shows the clock; the map picker
// (fnc_stratmap) builds the same stats block but prints a time band, since a deadline read while browsing
// overstates the time left once the mission is picked. DUWS_curDeadlineAt is an absolute engine-time
// (seconds) and daytime advances 1:1 with engine seconds, so the seconds left convert straight to a
// clock. Guarded on a live future deadline; a stale/unset global adds nothing.
//
// Name, type and note are single-sourced from mission_types.hpp through fnc_mission_begin's globals: the
// type token is title-cased into its display word, and the note renders only when the type carries one.
private _dl = missionNamespace getVariable ["DUWS_curDeadlineAt", -1];
if (_dl > time) then {
	// A blank line opens each section: the line strings carry one leading break, so a second one here
	// leaves an empty line between the body, the deadline, the note and the divider.
	_description = _description + "<br />" + format [localize "STR_DUWS_T_mission_deadline_desc", [_dl] call fnc_time_clock];

	private _noteKey = missionNamespace getVariable ["DUWS_curNoteKey", ""];
	if (_noteKey != "") then {
		_description = _description + "<br />" + format [localize "STR_DUWS_T_mission_note_line", localize _noteKey];
	};

	_description = _description + "<br />" + localize "STR_DUWS_T_mission_divider";
	_description = _description + format [localize "STR_DUWS_T_mission_name_line", localize (missionNamespace getVariable ["DUWS_curNameKey", ""])];
	private _obj = missionNamespace getVariable ["DUWS_curObjective", ""];
	_description = _description + format [localize "STR_DUWS_T_mission_type_line", (toUpper (_obj select [0,1])) + (_obj select [1])];

	(missionNamespace getVariable ["DUWS_curReward", [0,0,0]]) params ["_cp", "_ap", "_rep"];
	_description = _description + format [localize "STR_DUWS_T_mission_cpap", _cp, _ap];
	if (_rep > 0) then { _description = _description + format [localize "STR_DUWS_T_mission_rep", _rep] };
	// Concrete rolled duration in in-game hours, rounded: the map's pre-pick range has collapsed to one value.
	_description = _description + format [localize "STR_DUWS_T_mission_time_fixed", round (([_dl] call fnc_time_remaining) / 3600)];
};

// The JIP key must not be the bare task id: fnc_missionTaskEnd files the state change under
// that, and a same-key entry replaces rather than joins the queue, so a joiner would be handed
// the completion of a task that was never created on their machine.
//
// _destination is a position rather than the target object on purpose: a JIP entry outlives the
// mission that made it, and a deleted object reaches the joiner as null while a position still
// draws where the mission was. _type names a CfgTaskTypes class and only picks the icon; an
// unrecognised one falls back to the default rather than failing.
//
// sharedTarget (last arg) is false: it makes BIS_fnc_taskCreate share the destination across the
// network by its netId, but a position has no netId, so each frame BIS_fnc_setTaskLocal tried to
// resolve one and threw "groupFromNetId/objectFromNetId: type TASK, expected STRING" for the whole
// life of the task. On an open strategic map that per-frame throw also broke the task figure's
// tooltip and click. The position is already global, so nothing needs sharing.
[west, [_taskId], [_description, _title, _title], _destination, true, 1, true, _type, false]
	remoteExec ["BIS_fnc_taskCreate", [0,-2] select isDedicated, _taskId + "_new"];

// The card rides with the broadcast, not with the thread's entry gate: a thread that fails to find
// ground exits before creating a task, and announcing at the gate named an operation nobody got.
// Spawned per client rather than remoteExec'd into BIS_fnc_typeText, which sleeps between characters
// and would throw unscheduled. The hold is the line's own third element -- the function's second and
// third arguments are screen coordinates, so a hold passed there types the card off-screen.
[_title, {
	[[[toUpper _this, "<t align='center' shadow='1' size='1'>%1</t>", 5]]] spawn BIS_fnc_typeText;
}] remoteExec ["spawn", [0,-2] select isDedicated];
// Under the card, and one of only two places music plays -- the other is the insertion flight.
// Double brackets: playMusic is a unary command whose one argument is an array, so written flat
// remoteExec hands it the string alone and it throws on the type.
[["LeadTrack02_F", 0]] remoteExec ["playMusic", [0,-2] select isDedicated];
