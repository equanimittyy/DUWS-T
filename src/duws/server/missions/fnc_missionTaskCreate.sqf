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
// The framework destination stays [] on purpose. A destination given to BIS_fnc_taskCreate is stored
// as a shared target and re-resolved by netId every frame the map is open; broadcast creation crosses
// that metadata, so the resolve is fed the task object itself and throws
// "objectFromNetId/groupFromNetId: type TASK, expected STRING" for the task's whole life -- a
// per-frame flood that jams the strategic map's tooltip and click (docs/info/arma_engine_gotchas.md).
// The centre pin is set instead just below with setSimpleTaskDestination, which writes a plain
// position and never takes that shared-target path. _type names a CfgTaskTypes class and only picks
// the icon; an unrecognised one falls back to the default.
[west, [_taskId], [_description, _title, _title], [], true, 1, true, _type, false]
	remoteExec ["BIS_fnc_taskCreate", [0,-2] select isDedicated, _taskId + "_new"];

// Pin at the mission centre, drawn per client so a joiner (JIP key) gets it too. setSimpleTaskDestination
// writes a static position straight onto the local simple task, so the pin renders with none of the
// netId resolve a framework destination triggers. Polls for the task because the create above, though
// ordered before this on each target, may not have registered on this machine on the first frame; the
// 10s cap keeps a joiner reaching a mission that already ended from waiting forever.
if !(_destination isEqualTo []) then {
	[[_taskId, _destination], {
		params ["_id", "_pos"];
		private _deadline = time + 10;
		private _hit = [];
		waitUntil {
			uiSleep 0.5;
			_hit = (simpleTasks player) select { taskName _x == _id };
			(count _hit > 0) || time > _deadline
		};
		if (count _hit > 0) then { (_hit select 0) setSimpleTaskDestination _pos };
	}] remoteExec ["spawn", [0,-2] select isDedicated, _taskId + "_dest"];
};

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
