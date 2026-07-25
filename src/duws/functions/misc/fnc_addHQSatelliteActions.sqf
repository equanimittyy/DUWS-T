// Locality: client; the addAction bodies below run on the machine that triggers them, not here.
/*
    fnc_addHQSatelliteActions.sqf
    参数: _satellite - 卫星电话对象
    由服务器远程调用，在每个客户端为卫星电话添加交互动作
*/
if (!hasInterface) exitWith {};

params ["_satellite"];

if (isNull _satellite) exitWith {};

// 去重
if (!isNil {_satellite getVariable "satellite_actions_done"}) exitWith {};
_satellite setVariable ["satellite_actions_done", true];

// GM 休息治疗动作（仅限 game_master）
if ((vehiclevarname player) in game_master) then {
    _satellite addAction [
        localize "STR_DUWS_T_9eiwr3bt",
        {
            params ["_target", "_caller", "_actionId", "_arguments"];
            // 将请求发送到服务器执行实际治疗
            [_caller] remoteExec ["fnc_restHealServer", 2];
        },
        "",
        0,
        true,
        true,
        "",
        "_this == player"
    ];
};