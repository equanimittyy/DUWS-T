// Locality: server. No operation name, title card or music: those announce an HQ operation (fnc_missionTaskCreate).
params ["_id", "_titleKey", "_descKey", "_taskType"];
private _e = DUWS_civMissions get _id;

private _centre = (_e get "site") getPos [random 150, random 360];
_e set ["marker", [_centre, 250] call fnc_missionMarkerData];

private _taskId = format ["civ_mission_%1", _id];
_e set ["taskId", _taskId];
_e set ["title", _titleKey];
(_e get "reward") params ["_cp", "_money", "_rep"];
private _desc = (localize _descKey) + "<br />" + (localize "STR_DUWS_T_mission_divider")
    + format [localize "STR_DUWS_T_CIVMISSION_CPMONEY", floor (_cp * cp_reward_multiplier), _money]
    + format [localize "STR_DUWS_T_mission_rep", _rep];
// Server-side, never remoteExec'd (arma_engine_gotchas.md). "CREATED" leaves the HQ mission the current task.
[west, [_taskId], [_desc, localize _titleKey, ""], [_centre select 0, _centre select 1], "CREATED", 1, true, _taskType, false] call BIS_fnc_taskCreate;
