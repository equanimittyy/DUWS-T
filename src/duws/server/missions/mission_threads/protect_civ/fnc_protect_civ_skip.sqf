// Locality: server -- the Skip Prep Phase action on the informant remoteExecs this to target 2.
// Raises the per-instance skip flag the thread's prep loop polls to drop straight into the defend phase.
if (!isServer) exitWith {};
params ["_taskName"];
missionNamespace setVariable [format ["%1_skip", _taskName], true];
