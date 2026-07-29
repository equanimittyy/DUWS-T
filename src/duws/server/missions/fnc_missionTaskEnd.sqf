// Locality: server -- mission threads call this directly; the one client thread that finishes a
// mission remoteExecs it to target 2 rather than broadcasting the state itself.

// Retires a side-mission task: final state to every client, then removal once it has been read.
params ["_taskId", ["_state", "SUCCEEDED"]];
if (!isServer) exitWith {};

[_taskId, _state] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated, _taskId];

[_taskId] spawn {
	params ["_taskId"];
	// Deleted rather than left completed: nothing else in the campaign removes a side-mission
	// task, so a long session ends with every mission it has ever run still listed. The delay is
	// there so the completion is on screen long enough to be read before the entry goes.
	sleep 120;
	[_taskId] remoteExec ["BIS_fnc_deleteTask", [0,-2] select isDedicated];
	// Both queue entries have to go with it, or a player joining an hour later is handed the
	// creation and completion of a mission that finished before they connected.
	remoteExec ["", _taskId + "_new"];
	remoteExec ["", _taskId];
};
