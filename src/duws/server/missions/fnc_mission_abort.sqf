// Locality: server -- mission threads and fnc_mission_site call it, and all of them run server-side.
//
// Releases everything fnc_mission_begin claimed, for a thread that cannot build its mission.
// The caller must exit itself afterwards: neither exitWith nor breakOut inside a called function
// can terminate its caller's scope.
params ["_missionType", ["_hintKey", "STR_DUWS_T_crtzxs0j"]];

// fnc_mission_begin stamps a full hour before the thread has found so much as a position, so a
// thread that gives up here left the type greyed out on the strategic map having spawned nothing.
// Cleared rather than restored to a previous value: the type never ran, so it has no cooldown to
// serve.
missionNamespace setVariable [format ["mission_cooldown_%1", _missionType], 0, true];
Mission_available = true;
publicVariable "Mission_available";

["WARN", "MISSION", format ["type=%1 aborted before spawning, slot and cooldown released",
    _missionType]] call fnc_log;
[_hintKey, {hint localize _this}] remoteExec ["BIS_fnc_Spawn", 0];
