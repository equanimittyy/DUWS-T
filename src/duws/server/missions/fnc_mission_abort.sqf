// Locality: server -- mission threads and fnc_mission_site call it, and all of them run server-side.
//
// Releases everything fnc_mission_begin claimed, for a thread that cannot build its mission.
// The caller must exit itself afterwards: neither exitWith nor breakOut inside a called function
// can terminate its caller's scope.
//
// _requester is the thread's remoteExecutedOwner: the fail hint lands on the machine that clicked the
// offer (0 -> forced locally, so the host). _reason names the select criterion that failed, as a stable
// snake_case slug or "slug: human detail" -- the grep/telemetry key for why a type aborts, so keep the
// slug stable when the wording changes. A thread whose branches share one player-facing hint (the
// informant hunt: several criteria, one line) MUST pass it so the log can tell the criteria apart.
// _compKey is the composition a part-way build already placed, released here so it does not leak; ""
// for an abort before anything was built. _hintKey overrides the generic "generation failed" line.
params ["_missionType", ["_requester", 0], ["_reason", ""], ["_compKey", ""], ["_hintKey", "STR_DUWS_T_MISSION_GEN_FAILED"]];

// fnc_mission_begin stamps the gate before the thread has found so much as a position, so a thread
// that gives up here would burn three in-game hours having spawned nothing. Cleared rather than
// restored to a previous value: the mission never ran, so it has no wait to serve. Zero reads as
// long past on the campaign clock, so the gate opens again at once.
DUWS_lastMissionStartDate = 0;
publicVariable "DUWS_lastMissionStartDate";
Mission_available = true;
publicVariable "Mission_available";

// Orphan sweep: a build that bailed part-way may have placed a composition and claimed units under this
// mission's token. Run the same teardown a finished mission gets -- release the composition, flag the
// token-owned units for the map sweep -- so both go on the keep-radius clock instead of leaking or
// blinking out. Token-scoped, so it can never reach a successor. Position/radius go unread by cleanup.
private _token = missionNamespace getVariable ["DUWS_mission_token", 0];
[[0,0,0], 0, _compKey, false, _token] call fnc_mission_cleanup;

// Explicit reason where the caller gave one; the hint key stands in for single-criterion callers.
private _why = [_reason, _hintKey] select (_reason isEqualTo "");
["WARN", "MISSION", format ["type=%1 aborted during generation: %2, slot and gate released",
    _missionType, _why]] call fnc_log;
[_requester, _hintKey] call fnc_mission_notice;
