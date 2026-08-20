// Locality: server -- called by mission threads only, all server-side.

// Retires a side-mission task: final state to every client, then removal once it has been read.
params ["_taskId", ["_state", "SUCCEEDED"]];
if (!isServer) exitWith {};

[_taskId, _state] call BIS_fnc_taskSetState;

[_taskId] spawn {
	params ["_taskId"];
	// Deleted rather than left completed: nothing else in the campaign removes a side-mission
	// task, so a long session ends with every mission it has ever run still listed. The delay is
	// there so the completion is on screen long enough to be read before the entry goes.
	sleep 120;
	[_taskId] call BIS_fnc_deleteTask;
};
