// Locality: server -- every mission thread runs there, and the JIP keys are the server's to own.

// BIS_fnc_taskCreate does not synchronise itself. A plain server-side call leaves the task on
// the server, where only a hosting player -- whose client is the server -- ever sees it, and the
// state change that follows minutes later then lands on clients holding no such task and is
// dropped without an error. Broadcasting the creation is what makes both halves land.
params ["_taskId", "_description", "_title", "_destination", ["_type", "unknown"]];
if (!isServer) exitWith {};

// The JIP key must not be the bare task id: fnc_missionTaskEnd files the state change under
// that, and a same-key entry replaces rather than joins the queue, so a joiner would be handed
// the completion of a task that was never created on their machine.
//
// _destination is a position rather than the target object on purpose: a JIP entry outlives the
// mission that made it, and a deleted object reaches the joiner as null while a position still
// draws where the mission was. _type names a CfgTaskTypes class and only picks the icon; an
// unrecognised one falls back to the default rather than failing.
[west, [_taskId], [_description, _title, _title], _destination, true, 1, true, _type, true]
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
