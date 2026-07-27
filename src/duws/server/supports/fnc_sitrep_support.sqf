// Locality: client -- the comm-menu item runs on the machine that activated it, which is why
// the debit below goes through fnc_pool_spend and every line after it broadcasts outward.
if !(["CP", 1] call fnc_pool_spend) exitWith
{
    // CP 不足时的处理：同样广播给所有玩家
    ["sitrepinfo", [localize "STR_DUWS_T_qkkva9tk", format [localize "STR_DUWS_T_p6sb3ply", 1]]] remoteExec ["BIS_fnc_showNotification", 0];
};

// Saving is server work, so it is asked for rather than confirmed. This sat behind an
// if (isServer) test wrapping a BIS_fnc_guiMessage prompt: on a dedicated server no client
// passes that test, so the save never ran at all, and on a hosted game only the host was ever
// asked for it. Everyone pays the same CP, so everyone gets the same save.
[] remoteExec ["fnc_autoSave", 2];
["sitrepinfo", [localize "STR_DUWS_T_qkkva9tk", localize "STR_DUWS_T_biham0s3"]] remoteExec ["BIS_fnc_showNotification", 0];

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
