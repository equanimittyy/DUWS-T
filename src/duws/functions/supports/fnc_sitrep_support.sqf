if (commandpointsblu1 >= 1) exitWith  
{
    // 扣除 CP 并同步
    [-1] remoteExec ["fnc_cp_adjust", 2];

    // 如果当前是服务器，则显示确认对话框（对话框始终在服务器上显示，无需广播）
    if (isServer) then {
        private _result = [localize "STR_DUWS_T_ylnwrgad", localize "STR_DUWS_T_5xcfatn0", true, true] call BIS_fnc_guiMessage;
        if (_result) then {
            [] call fnc_autoSave; // 自动保存（已在服务器执行，无需广播）
            sleep 0.5;
            // 将通知广播给所有玩家
            ["sitrepinfo", [localize "STR_DUWS_T_qkkva9tk", localize "STR_DUWS_T_biham0s3"]] remoteExec ["BIS_fnc_showNotification", 0];
            sleep 5;
        };  
    };

    // 广播简短战况消息（侧信道或系统消息）
    private _shortMsg = format [localize "STR_DUWS_T_10dzingj", commandpointsblu1, WARCOM_blufor_ap, WARCOM_opfor_ap];
    // 直接使用 systemChat 广播给所有玩家
    [_shortMsg] remoteExec ["systemChat", 0];

    // 让所有玩家显示详细的战况报告（fnc_sitrep_display 内部包含 hint）
    [] remoteExec ["fnc_sitrep_display", 0];

    // 让所有玩家显示底部 OSD 信息
    [] remoteExec ["fnc_bottom_right_message", 0];
    // 字幕和电台声音已经是全局广播，无需修改
    [localize "STR_DUWS_T_allseer", localize "STR_DUWS_T_sitrep"] remoteExec ["BIS_fnc_showSubtitle", 0];
    [] remoteExec ["fnc_broadcastRadioChatter", 0];
};

// CP 不足时的处理：同样广播给所有玩家
["sitrepinfo", [localize "STR_DUWS_T_qkkva9tk", format [localize "STR_DUWS_T_p6sb3ply", 1]]] remoteExec ["BIS_fnc_showNotification", 0];