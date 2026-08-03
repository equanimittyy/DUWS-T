if (!isServer) exitWith {};

params ["_caller"];
if (isNull _caller) exitWith {};

// ========== 冷却检查（30分钟 = 1800秒） ==========
private _cooldownVar = "DUWS_hirePartisans_lastUse";
private _lastUse = _caller getVariable [_cooldownVar, -1800];
private _cooldownRemaining = 1800 - (diag_tickTime - _lastUse);
// Hints, where the squad arriving below is a card: a refusal answers the one player who
// clicked and the hire is news for the team (docs/info/player_facing_text.md).
if (_cooldownRemaining > 0) exitWith {
    private _minutes = floor (_cooldownRemaining / 60);
    private _seconds = floor (_cooldownRemaining % 60);
    private _msg = format [localize "STR_DUWS_T_HIRE_PARTISANS_COOLDOWN", _minutes, _seconds];
    [_msg] remoteExec ["hint", _caller];
};

// 检查并扣除 10 个 Money_roll
if !([_caller, 10] call fnc_coins_spend) exitWith {
    private _msg = localize "STR_DUWS_T_NOT_ENOUGH_MONEY";
    [_msg] remoteExec ["hint", _caller];
};

// 记录使用时间
_caller setVariable [_cooldownVar, diag_tickTime, true];

// Flat squad, no reputation scaling: there is no campaign-wide reputation to scale off, and the
// town the squad drops into is not known here -- the client picks that position after this runs.
private _count = 6;

// ========== 通知客户端打开地图选择部署位置 ==========
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_HIRE_PARTISANS_choseMap"] remoteExec ["fnc_duws_dialogue", _caller];
[_caller, _count] remoteExec ["fnc_hirePartisans_clientMap", _caller];
// 服务器不再做更多事情，后续由客户端调用 spawnDeployed