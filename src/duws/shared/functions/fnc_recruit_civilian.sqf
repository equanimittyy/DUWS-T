// Locality: all machines -- inherited from shared/functions/fnc_addRecruitAction.sqf.
/*
    fnc_recruit_civilian.sqf
    参数: _civilian - 平民单位, _caller - 发起交互的玩家
    功能: 客户端触发，将招募请求发送到服务器执行
*/
params ["_civilian", "_caller"];

diag_log format ["[RECRUIT] Client called by %1 on %2", _caller, _civilian];

// 本地防重（避免玩家快速多次点击）
if (_civilian getVariable ["recruit_processed_local", false]) exitWith {
    [localize "STR_DUWS_T_RECRUIT_ALREADY"] remoteExec ["hint", _caller];
};
_civilian setVariable ["recruit_processed_local", true];

// 发送到服务器执行
[_civilian, _caller, netId _civilian, getPlayerUID _caller] remoteExec ["fnc_recruit_civilian_server", 2];