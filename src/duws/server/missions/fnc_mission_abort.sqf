// Locality: server -- mission threads and fnc_mission_site call it, and all of them run server-side.
//
// Releases everything fnc_mission_begin claimed, for a thread that cannot build its mission.
// The caller must exit itself afterwards: neither exitWith nor breakOut inside a called function
// can terminate its caller's scope.
//
// _reason names the select criterion that failed at click-time, as a stable snake_case slug, or
// "slug: human detail". It is the grep/telemetry key for why a type aborts, so keep the slug stable
// when the wording changes. A thread whose branches share one player-facing hint (the informant hunt:
// several criteria, one "unavailable" line) MUST pass it so the log can tell the criteria apart;
// a single-criterion caller may omit it and the hint key stands in.
params ["_missionType", ["_hintKey", "STR_DUWS_T_crtzxs0j"], ["_reason", ""]];

// fnc_mission_begin stamps the full cooldown before the thread has found so much as a position, so
// a thread that gives up here left the type greyed out on the strategic map having spawned nothing.
// Cleared rather than restored to a previous value: the type never ran, so it has no cooldown to
// serve. Zero reads as expired on any clock, so this needs no knowledge of which one is in use.
missionNamespace setVariable [format ["mission_cooldown_%1", _missionType], 0, true];
Mission_available = true;
publicVariable "Mission_available";

// Explicit reason where the caller gave one; the hint key stands in for single-criterion callers.
private _why = [_reason, _hintKey] select (_reason isEqualTo "");
["WARN", "MISSION", format ["type=%1 aborted before spawning: %2, slot and cooldown released",
    _missionType, _why]] call fnc_log;
[_hintKey, {hint localize _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];
