// Locality: server -- the informant's DEBUG: Skip Assault action remoteExecs this to target 2.
// Raises the per-instance skip-assault flag the defend wait polls, ending the hold as a win.
if (!isServer) exitWith {};
params ["_taskName"];
missionNamespace setVariable [format ["%1_skipAssault", _taskName], true];
