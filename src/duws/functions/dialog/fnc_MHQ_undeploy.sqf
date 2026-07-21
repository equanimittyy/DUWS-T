// fnc_MHQ_undeploy.sqf
// 取消部署机动指挥部，清理弹药箱、帐篷、复活点，解锁载具

// 删除隐形乘员
{
    deleteVehicle _x;
} forEach crew MHQ1;

// 删除静态物体
deleteVehicle MHQ_tent;
deleteVehicle MHQ_ammobox;

// 更新地图标记
_markerType = "b_motor_inf";
if (MHQ1 isKindof "tank") then {_markerType = "b_armor"};

// 移除已部署标记，恢复未部署标记
[MHQ1] remoteExec ["kndr_removeMarker", [0,-2] select isDedicated,false];
sleep 0.2;
[MHQ1, _markerType, "ColorYellow", 1, 1, localize "STR_DUWS_T_9ziy0qai"] remoteExec ["kndr_assignMarker", [0,-2] select isDedicated,false];

// ========== 安全移除复活点（仅服务器执行） ==========
if (isServer) then {
    if (!isNil "MHQ_respawn") then {
        MHQ_respawn call BIS_fnc_removeRespawnPosition;
        diag_log format ["[MHQ] Respawn position %1 removed", MHQ_respawn];
        MHQ_respawn = nil;
        publicVariable "MHQ_respawn";
    };
    // 强制客户端刷新复活点列表
    [] remoteExec ["BIS_fnc_forceRespawn", 0];
} else {
    // 若函数在客户端被误调用，则请求服务器执行（保险）
    [] remoteExec ["fnc_MHQ_undeploy", 2];
};
// =====================================================

MHQ_deployed = false;
publicVariable "MHQ_deployed";

// Unlock vehicle
MHQ1 setVehicleLock "UNLOCKED";

["deploy"] remoteExec ["fnc_MHQ_addActions", [0,-2] select isDedicated,true];