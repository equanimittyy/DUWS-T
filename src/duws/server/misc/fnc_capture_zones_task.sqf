// fnc_capture_zones_task.sqf
// CREATE MAIN TASK/OBJECTIVE
if (!isServer) exitWith {};

// 初始化丧尸任务标志
if (isNil "ZombieTaskCreated") then {
    ZombieTaskCreated = false;
};

// Orders arrive with the player, not on a timer: the fixed 60s wait this replaces expired
// part-way through zone build-out, and manual placement runs minutes past it, so the task told
// the player to capture zones that did not exist yet.
while {!(["ZONES", "mission_init_complete (zones built, civilians registered)",
    {mission_init_complete}, 300] call fnc_waitLogged)} do {};
// Then the fast-rope. Not retried on timeout, unlike the wait above -- fnc_intro_heli has early
// exits that never publish this, and a campaign with no main task has no win condition at all.
// The gate above is what keeps that fall-through from landing back at mission start.
["ZONES", "intro_heli_done (players landed)", {!isNil "intro_heli_done"}, 420] call fnc_waitLogged;
// Then the sitrep radio item, so orders never land before the tool that reports on them.
// Not retried for the same reason as above: only the game_master slot adds the item, so an
// MP session with that slot empty would never publish it.
["ZONES", "sitrep_granted (radio item added)", {!isNil "sitrep_granted"}, 90] call fnc_waitLogged;

// The task ID is a fixed key and must never be localized: the SUCCEEDED update at the end of
// this file looks the task up by this exact string, so a localized ID silently stops matching
// the moment the server is not English and the campaign task never completes. The player-facing
// name comes from the description array below, not from the ID.
// Broadcast, not called: BIS_fnc_taskCreate does not synchronise itself, so a server-side call
// leaves the campaign objective visible to a hosting player alone. The JIP key is suffixed
// because the SUCCEEDED update below is filed under the bare id, and a same-key entry replaces
// rather than joins.
[west, ["Campaign"],
    [localize "STR_DUWS_T_92465yls", localize "STR_DUWS_T_q5xntd8z", localize "STR_DUWS_T_q5xntd8z"], objNull, true]
    remoteExec ["BIS_fnc_taskCreate", [0,-2] select isDedicated, "Campaign_new"];
sleep 2;
// 如果是丧尸模式且尚未创建额外任务，则创建
if (CIV_PRESENCE == "RAVAGE" && !ZombieTaskCreated) then {
    // ===== 丧尸模式额外任务（请在此处填写具体内容）=====
    [west, ["ZombieTask"],
        [localize "STR_DUWS_T_zhxdjj", localize "STR_DUWS_T_zhxd", localize "STR_DUWS_T_zhxd"], objNull, true]
        remoteExec ["BIS_fnc_taskCreate", [0,-2] select isDedicated, "ZombieTask_new"];
    // =================================================
    ZombieTaskCreated = true;
};
// 如果是 WBK 模式且尚未创建额外任务，则创建
if (CIV_PRESENCE == "WBK" && !ZombieTaskCreated) then {
    [west, ["WBKTask"],
        [localize "STR_DUWS_T_WBK_TASK_DESC", localize "STR_DUWS_T_zhxd", localize "STR_DUWS_T_zhxd"], objNull, true]
        remoteExec ["BIS_fnc_taskCreate", [0,-2] select isDedicated, "WBKTask_new"];
    ZombieTaskCreated = true;
};

// 等待区域生成完成和区域被全部占领
waitUntil {sleep 10; WARCOM_init_done};
// The zone count has to be checked, not assumed: with none created the comparison reads 0 >= 0
// and wins the campaign on its first evaluation. Ordering alone is not enough of a guard --
// every zone slot can be dropped by the origin keep-out in fnc_locatorzones_random.
// Both endings are waited on together and the branch below picks which fired. A second thread
// watching for the loss is not an option: this wait blocks for the whole campaign, so anything
// appended after it is unreachable until the win lands.
waitUntil {
    sleep 30;
    (amount_zones_created > 0 && {zoneundercontrolblu >= amount_zones_created})
    || {!isNil "campaign_lost"}
};

// The pause only lets the notification and the task update land before the outro card replaces
// them. The notification takes title and body as separate fields; the hint and side-chat take
// one string, so they need the separator the `+` concatenation was missing -- it ran the
// headline straight into the sentence as "Mission Completed!Every zone...".
private _won = isNil "campaign_lost";
private _title = [localize "STR_DUWS_T_CAMPAIGN_LOST_TITLE", localize "STR_DUWS_T_fo1ihi1n"] select _won;
// The losing body names which ending this was: there is more than one way to lose now, and the
// ruined-island line reads as a non sequitur after the commander is shot at his own desk. Carried
// as a stringtable key rather than as resolved text so the setter does not have to be a machine
// with a stringtable -- and so this stays the one place the campaign's endings are worded.
private _body = [localize (missionNamespace getVariable
    ["campaign_lost_body", "STR_DUWS_T_CAMPAIGN_LOST"]), localize "STR_DUWS_T_CAMPAIGN_WON"] select _won;

["info", [_title, _body]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
[format ["%1 %2", _title, _body], {hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

["Campaign", ["FAILED", "SUCCEEDED"] select _won] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated, "Campaign"];
sleep 10;
// Two-argument form: the one-argument call defaults victory to true, which would end a
// flattened Altis on the winning card.
["island_captured_win", _won] call BIS_fnc_endMissionServer;
