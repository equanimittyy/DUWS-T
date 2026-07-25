// Locality: all machines; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 0).
/*
    fnc_civ_stopCommand.sqf
    参数: _unit - 平民单位
    为平民添加“叫过来”动作，平民会移动到玩家位置
    仅非丧尸模式添加
*/
params ["_unit"];

if (isNull _unit) exitWith {};

// 定义远程移除函数（确保所有客户端都有）
if (isNil "fnc_removeStopCommandAction") then {
    fnc_removeStopCommandAction = {
        params ["_unit"];
        private _id = _unit getVariable ["stopCommandActionID", -1];
        if (_id != -1) then {
            _unit removeAction _id;
            _unit setVariable ["stopCommandActionID", nil];
        };
    };
    publicVariable "fnc_removeStopCommandAction";
};

private _actionID = _unit addAction [
    localize "STR_DUWS_T_CIV_STOP",
{
    params ["_target", "_caller", "_actionId"];
    
    [_target] remoteExec ["fnc_removeStopCommandAction", 0];
    [([localize "STR_DUWS_T_actionteam"] call fnc_cs), localize "STR_DUWS_T_STOP"] remoteExec ["BIS_fnc_showSubtitle", _caller];
    
    // 发送服务器请求，让平民移动到玩家位置
    [_target, _caller] remoteExec ["fnc_civ_moveToPlayerServer", 2];
    sleep 4;
    // 提示成功
    hint localize "STR_DUWS_T_STOP_SUCCESS_HINT";
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_STOP_SUCCESS"] remoteExec ["BIS_fnc_showSubtitle", _caller];
},
    nil,
    6,
    true,
    true,
    "",
    "_this distance _target < 40"
];

_unit setVariable ["stopCommandActionID", _actionID];