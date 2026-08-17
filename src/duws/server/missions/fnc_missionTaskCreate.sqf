// Locality: server -- every mission thread runs there, and the JIP keys are the server's to own.

// BIS_fnc_taskCreate does not synchronise itself. A plain server-side call leaves the task on
// the server, where only a hosting player -- whose client is the server -- ever sees it, and the
// state change that follows minutes later then lands on clients holding no such task and is
// dropped without an error. Broadcasting the creation is what makes both halves land.
params ["_taskId", "_description", "_title", "_destination", ["_type", "unknown"]];
if (!isServer) exitWith {};

// Journal footer, built once here so all 17 threads share it: mission text, the deadline as an in-game
// wall clock, a blank line, then the reward block. Only the journal shows the clock -- the map picker
// stays a relative band, or a deadline read while browsing overstates the time actually left once the
// mission is picked. DUWS_curDeadlineAt is an absolute engine-time (seconds) and daytime advances 1:1
// with engine seconds -- the same assumption fnc_mission_begin built the deadline on -- so the seconds
// left convert straight to a clock. Guarded on a live future deadline; a stale/unset global adds nothing.
private _dl = missionNamespace getVariable ["DUWS_curDeadlineAt", -1];
if (_dl > time) then {
	_description = _description
		+ format [localize "STR_DUWS_T_mission_deadline_desc", [_dl] call fnc_time_clock]
		+ "<br />";  // second break: blank line between the deadline line and the reward block

	(missionNamespace getVariable ["DUWS_curReward", [0,0,0]]) params ["_cp", "_ap", "_rep"];
	_description = _description + format [localize "STR_DUWS_T_mission_cpap", _cp, _ap];
	if (_rep > 0) then { _description = _description + format [localize "STR_DUWS_T_mission_rep", _rep] };
	// Concrete rolled duration in in-game hours, rounded: the map's pre-pick range has collapsed to one
	// value by now.
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
