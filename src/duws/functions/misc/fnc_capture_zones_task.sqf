// fnc_capture_zones_task.sqf
// CREATE MAIN TASK/OBJECTIVE
if (!isServer) exitWith {};

// 初始化丧尸任务标志
if (isNil "ZombieTaskCreated") then {
    ZombieTaskCreated = false;
};

sleep 60;

// 创建主要任务（占领所有区域）
[west, [localize "STR_DUWS_T_347ohzwn"],
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
waitUntil {sleep 30; zoneundercontrolblu >= amount_zones_created};

// Every zone is BLUFOR: the campaign is over. The pause only lets the notification and the
// task update land before the outro card replaces them.
["info",[localize "STR_DUWS_T_fo1ihi1n", localize "STR_DUWS_T_CAMPAIGN_WON"]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
[localize "STR_DUWS_T_fo1ihi1n" + localize "STR_DUWS_T_CAMPAIGN_WON",{hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
[localize "STR_DUWS_T_fo1ihi1n" + localize "STR_DUWS_T_CAMPAIGN_WON"] spawn fnc_sideChat_filter;

["Campaign", "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", 0];
sleep 10;
"island_captured_win" call BIS_fnc_endMissionServer;
