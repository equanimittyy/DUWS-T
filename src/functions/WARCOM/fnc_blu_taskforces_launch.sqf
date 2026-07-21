// fnc_blu_taskforces_launch.sqf
if (!isServer) exitWith {};

private _standby = missionNamespace getVariable ["blu_taskforces_standby", []];
if (count _standby == 0) exitWith {
    ["info", [localize "STR_DUWS_T_no_standby_tf", localize "STR_DUWS_T_no_standby_tf_desc"]] remoteExec ["BIS_fnc_showNotification", 0];
};
// 提示玩家
[localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_taskforces_launchrqst"] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 6;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_taskforces_launched"] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
{
    if (!isNull _x) then {
        // 清除现有路点（待命路点）
        while {count (waypoints _x) > 0} do {
            deleteWaypoint ((waypoints _x) select 0);
        };
        // 调用原有进攻路点函数（会为组添加攻击敌区的路点）
        [_x] spawn fnc_WARCOM_wp_blu_assault;
        // GPS 标记函数已经在待命时启动，它会自动更新目标，不需要重新调用
    };
} forEach _standby;

// 清空待命数组
missionNamespace setVariable ["blu_taskforces_standby", [], true];


["info", [localize "STR_DUWS_T_taskforces_launched_title", localize "STR_DUWS_T_taskforces_launched_desc"]] remoteExec ["BIS_fnc_showNotification", 0];