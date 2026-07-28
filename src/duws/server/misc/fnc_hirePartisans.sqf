// fnc_hirePartisans.sqf
// 功能：雇佣平民游击队，消耗10个Money_roll，根据声望生成6-12名武装平民，独立成组加入高级指挥
// 参数: _caller - 执行动作的玩家
// 执行端: 服务器
if (!isServer) exitWith {};

params ["_caller"];
if (isNull _caller) exitWith {};

// ========== 冷却检查（30分钟 = 1800秒） ==========
private _cooldownVar = "DUWS_hirePartisans_lastUse";
private _lastUse = _caller getVariable [_cooldownVar, -1800];
private _cooldownRemaining = 1800 - (diag_tickTime - _lastUse);
if (_cooldownRemaining > 0) exitWith {
    private _minutes = floor (_cooldownRemaining / 60);
    private _seconds = floor (_cooldownRemaining % 60);
    private _msg = format [localize "STR_DUWS_T_HIRE_PARTISANS_COOLDOWN", _minutes, _seconds];
    ["info", [localize "STR_DUWS_T_HIRE_PARTISANS_TITLE", _msg]] remoteExec ["BIS_fnc_showNotification", _caller];
};

// 检查声望
private _rep = missionNamespace getVariable ["Player_Reputation", 0];
if (_rep < 2) exitWith {
    private _msg = localize "STR_DUWS_T_HIRE_PARTISANS_LOW_REP";
    ["info", [localize "STR_DUWS_T_HIRE_PARTISANS_TITLE", _msg]] remoteExec ["BIS_fnc_showNotification", _caller];
};

// 检查并扣除 10 个 Money_roll
if !([_caller, 10] call fnc_coins_spend) exitWith {
    private _msg = localize "STR_DUWS_T_NOT_ENOUGH_MONEY";
    ["info", [localize "STR_DUWS_T_HIRE_PARTISANS_TITLE", _msg]] remoteExec ["BIS_fnc_showNotification", _caller];
};

// 记录使用时间
_caller setVariable [_cooldownVar, diag_tickTime, true];

// 计算游击队数量（声望2=6，每增加2点声望+1，上限12）
private _count = 6 + floor ((_rep - 2) / 2);
_count = _count max 6 min 12;

// ========== 通知客户端打开地图选择部署位置 ==========
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_HIRE_PARTISANS_choseMap"] remoteExec ["fnc_duws_dialogue", _caller];
[_caller, _count] remoteExec ["fnc_hirePartisans_clientMap", _caller];
// 服务器不再做更多事情，后续由客户端调用 spawnDeployed