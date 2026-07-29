// Locality: all machines; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 0).
/*
    fnc_addRecruitAction.sqf
    参数: _unit - 平民单位
    由服务器远程调用，在每个客户端执行为平民添加招募动作
*/
#include "..\includes\action_style.hpp"

params ["_unit"];

if (isNull _unit) exitWith {};

_unit addAction [
    ACT_CIVILIAN_INTERACTION("STR_DUWS_T_RECRUIT_ACTION"),
    { 
        params ["_target", "_caller", "_actionId", "_arguments"];
        [_target, _caller] spawn fnc_recruit_civilian;
        _target removeAction _actionId;
    },
    [],
    50,
    true,
    true,
    "",
    "true"
];