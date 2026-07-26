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

// 创建主要任务（占领所有区域）
// The task ID is a fixed key and must never be localized: the SUCCEEDED update at the end of
// this file looks the task up by this exact string, so a localized ID silently stops matching
// the moment the server is not English and the campaign task never completes. The player-facing
// name comes from the description array below, not from the ID.
[west, ["Campaign"],
    [localize "STR_DUWS_T_92465yls", localize "STR_DUWS_T_q5xntd8z", localize "STR_DUWS_T_q5xntd8z"], objNull, true] call BIS_fnc_taskCreate;
sleep 2;
// 如果是丧尸模式且尚未创建额外任务，则创建
if (CIV_PRESENCE == "RAVAGE" && !ZombieTaskCreated) then {
    // ===== 丧尸模式额外任务（请在此处填写具体内容）=====
    [west, ["ZombieTask"],
        [localize "STR_DUWS_T_zhxdjj", localize "STR_DUWS_T_zhxd", localize "STR_DUWS_T_zhxd"], objNull, true] call BIS_fnc_taskCreate;
    // =================================================
    ZombieTaskCreated = true;
};
// 如果是 WBK 模式且尚未创建额外任务，则创建
if (CIV_PRESENCE == "WBK" && !ZombieTaskCreated) then {
    [west, ["WBKTask"],
        [localize "STR_DUWS_T_WBK_TASK_DESC", localize "STR_DUWS_T_zhxd", localize "STR_DUWS_T_zhxd"], objNull, true] call BIS_fnc_taskCreate;
    ZombieTaskCreated = true;
};

// 等待区域生成完成和区域被全部占领
waitUntil {sleep 10; WARCOM_init_done};
// The zone count has to be checked, not assumed: with none created the comparison reads 0 >= 0
// and wins the campaign on its first evaluation. Ordering alone is not enough of a guard --
// every zone slot can be dropped by the origin keep-out in fnc_locatorzones_random.
waitUntil {sleep 30; amount_zones_created > 0 && {zoneundercontrolblu >= amount_zones_created}};

// Every zone is BLUFOR: the campaign is over. The pause only lets the notification and the
// task update land before the outro card replaces them.
// The notification takes title and body as separate fields; the hint and side-chat take one
// string, so they need the separator the `+` concatenation was missing -- it ran the headline
// straight into the sentence as "Mission Completed!Every zone...".
private _endLine = format ["%1 %2", localize "STR_DUWS_T_fo1ihi1n", localize "STR_DUWS_T_CAMPAIGN_WON"];
["info",[localize "STR_DUWS_T_fo1ihi1n", localize "STR_DUWS_T_CAMPAIGN_WON"]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
[_endLine,{hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
[_endLine] spawn fnc_sideChat_filter;

["Campaign", "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", 0];
sleep 10;
"island_captured_win" call BIS_fnc_endMissionServer;
