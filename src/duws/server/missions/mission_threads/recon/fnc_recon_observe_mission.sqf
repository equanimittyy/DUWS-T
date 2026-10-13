// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;

// Target: the finder returned it as _MissionPos, so re-deriving the nearest unrevealed OPFOR position
// lands on the same one via the shared picker. Kind (zone/hardpoint) rides the pick; if it was captured
// or revealed since the offer the next nearest resolves, none left aborts.
private _pick = [_MissionPos] call fnc_recon_observe_pick;
if (_pick isEqualTo []) exitWith {
    [12, _requester, "no_target_pick"] call fnc_mission_abort;
};

if (!([12, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

private _overwatch = [_pick] call fnc_recon_observe_overwatch;
if (_overwatch isEqualTo []) exitWith {
    [12, _requester, "no_overwatch"] call fnc_mission_abort;
};

private _taskID = format ["recon_%1", round time];
[_taskID, localize "STR_DUWS_T_RECON_OBSERVE_TASK", _mission_name, _overwatch, "scout"] call fnc_missionTaskCreate;

private _won = ["hq", _pick, _overwatch, DUWS_curDeadlineAt] call fnc_recon_observe_run;
[_mission_name, _taskID, ["FAILED", "SUCCEEDED"] select _won, _overwatch, 0, [], [], _won] call fnc_mission_finish;
