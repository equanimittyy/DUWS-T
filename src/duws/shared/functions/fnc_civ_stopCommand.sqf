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
    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_STOP"] remoteExec ["fnc_duws_dialogue", _caller];
    
    // 发送服务器请求，让平民移动到玩家位置
    [_target, _caller] remoteExec ["fnc_civ_moveToPlayerServer", 2];
    sleep 4;
    // The spoken reply is the whole feedback. A hint on top of it narrated the civilian walking
    // over, which the player can already see.
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_STOP_SUCCESS"] remoteExec ["fnc_duws_dialogue", _caller];
},
    nil,
    6,
    true,
    true,
    "",
    // Facing test on top of the range. getRelDir is 0 straight ahead and wraps through 360, so
    // this is a 15 degree cone either side -- close to an aim test, where the 30 it was read as
    // "roughly on screen" and picked up whoever was standing beside the person meant. Horizontal
    // only: looking over someone's head still counts, which is the intended slack.
    //
    // 3 m, the range the conversational rows work at, so halting someone is done at arm's length
    // rather than shouted across a square. The menu still opens at 15 m because it carries arrest,
    // but it is gated on this having happened -- so the reach here is what sets the range of the
    // whole exchange, and a crowd fifteen deep no longer fills the scroll menu.
    //
    // Panicking civilians drop out: someone running from gunfire is not stopping to be called,
    // and the entry coming back is what tells the player the town has settled. fnc_civ_panic
    // broadcasts the flag and clears it once they are pathing normally again.
    "_this distance _target < 3 && {abs (180 - (_this getRelDir _target)) > 165} && {!(_target getVariable ['DUWS_civ_panicked', false])}"
];

_unit setVariable ["stopCommandActionID", _actionID];