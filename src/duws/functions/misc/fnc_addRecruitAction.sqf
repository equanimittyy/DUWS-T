/*
    fnc_addRecruitAction.sqf
    参数: _unit - 平民单位
    由服务器远程调用，在每个客户端执行为平民添加招募动作
*/
params ["_unit"];

if (isNull _unit) exitWith {};

_unit addAction [
    localize "STR_DUWS_T_RECRUIT_ACTION",
    { 
        params ["_target", "_caller", "_actionId", "_arguments"];
        [_target, _caller] spawn fnc_recruit_civilian;
        _target removeAction _actionId;
    },
    nil,
    6,
    true,
    true,
    "",
    "true"
];