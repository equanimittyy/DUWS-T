// Locality: server -- every mission thread creates its task here; BIS_fnc_taskCreate, called
// server-side, syncs the task out to the owner side's clients (joiners included) on its own.
params ["_taskId", "_description", "_title", "_destination", ["_type", "unknown"]];
if (!isServer) exitWith {};

// Only the journal shows a clock; the map picker (fnc_stratmap) shows a time band instead, since a
// deadline read while browsing would overstate what is left once picked. DUWS_curDeadlineAt is absolute
// engine-time and daytime advances 1:1 with it, so seconds-left converts straight to a clock. Name, type
// and note are single-sourced from mission_types.hpp via fnc_mission_begin's globals.
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
	// Same band the map offered; the exact deadline sits above it (the "You have until" clock).
	_description = _description + ((missionNamespace getVariable ["DUWS_curDeadlineBand", [0,0]]) call fnc_time_band);
};

// Created server-side and left to the task framework to synchronise. NOT remoteExec'd: broadcasting
// the create serialises the owner and destination over the wire as live references, and BIS's
// per-frame map draw then resolves those by netId every frame the map is open -- flooding the rpt
// with "objectFromNetId/groupFromNetId: type OBJECT/TASK, expected STRING" for the task's whole life
// and jamming the strategic map's tooltip and click (docs/info/architecture/arma_engine_gotchas.md). A native
// server-side create keeps the references as their own netId strings, so the destination pin draws
// clean while still reaching every client on the owner side.
//
// _destination is the mission centre, handed straight in as the task's map pin. visibleIn3D stays
// off: a strategic side mission wants the map diamond, not a world-space icon. _type names a
// CfgTaskTypes class and only picks the icon; an unrecognised one falls back to the default.
// Flattened to 2D: a getPos-derived centre carries a below-surface Z on coastal towns
// (docs/info/architecture/arma_engine_gotchas.md), which sinks the task diamond underground.
_destination = _destination select [0, 2];
[west, [_taskId], [_description, _title, _title], _destination, true, 1, true, _type, false] call BIS_fnc_taskCreate;

// The card rides with the task create, not with the thread's entry gate: a thread that fails to find
// ground exits before creating a task, and announcing at the gate named an operation nobody got.
// Spawned per client rather than remoteExec'd into BIS_fnc_typeText, which sleeps between characters
// and would throw unscheduled. The hold is the line's own third element -- the function's second and
// third arguments are screen coordinates, so a hold passed there types the card off-screen.
[_title, {
	[[[toUpper _this, "<t align='center' shadow='1' size='1'>%1</t>", 5]]] spawn BIS_fnc_typeText;
}] remoteExec ["spawn", [0,-2] select isDedicated];
// Under the card, and one of only two places music plays -- the other is the insertion flight.
// Spawned per client rather than a bare playMusic remoteExec so each one honours its own mute
// toggle (DUWS_T_muteMissionMusic, set at the medical tent); a single server-side playMusic would
// force the sting on every client alike.
[[], {
	if (profileNamespace getVariable ["DUWS_T_muteMissionMusic", false]) exitWith {};
	playMusic ["LeadTrack02_F", 0];
}] remoteExec ["spawn", [0,-2] select isDedicated];

// Closes the requester's progress line: survey -> generating -> complete, now the task exists.
[missionNamespace getVariable ["DUWS_curRequester", 0], "STR_DUWS_T_MISSION_GEN_COMPLETE"] call fnc_mission_notice;
