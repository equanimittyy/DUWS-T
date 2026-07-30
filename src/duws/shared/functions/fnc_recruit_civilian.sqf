// Locality: all machines -- inherited from shared/functions/fnc_addRecruitAction.sqf.
params ["_civilian", "_caller"];

["INFO", "CIV", format ["Client called by %1 on %2", _caller, _civilian]] call fnc_log;

// 本地防重（避免玩家快速多次点击）
if (_civilian getVariable ["recruit_processed_local", false]) exitWith {
    [localize "STR_DUWS_T_RECRUIT_ALREADY"] remoteExec ["hint", _caller];
};
_civilian setVariable ["recruit_processed_local", true];

// 发送到服务器执行
[_civilian, _caller, netId _civilian, getPlayerUID _caller] remoteExec ["fnc_recruit_civilian_server", 2];