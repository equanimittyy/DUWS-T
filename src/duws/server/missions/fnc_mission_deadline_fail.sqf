// Locality: server -- side-mission threads call it, all server-side.
//
// The teardown a side mission owes when its deadline runs out before the objective is met: the
// player-facing notice, a FAILED task, the objective marker cleared and the standard end. One call
// so a thread's timeout branch is not the same four lines re-inlined seventeen times. Threads that
// clear extra markers or unwind an escort (domination, transport, rescue pilot) keep their own
// branch instead -- this covers only the common shape.
//
// _marker / _compKey / _sweepFriendly default empty so a mission that owns no marker or built
// composition can omit them; _compKey and _sweepFriendly are handed straight to fnc_mission_end.
params ["_taskId", ["_marker", ""], ["_compKey", ""], ["_tpos", [0,0,0]], ["_radius", 0], ["_sweepFriendly", false]];
if (!isServer) exitWith {};

call fnc_mission_timeout_notice;
[_taskId, "FAILED"] call fnc_missionTaskEnd;
if (_marker != "") then { [_marker] call fnc_missionMarkerClear };
[_tpos, _radius, _compKey, _sweepFriendly] call fnc_mission_end;
