/*
    fnc_restHealServer.sqf
    参数: _caller - 发起治疗的玩家
    在服务器上执行休息治疗逻辑
*/
if (!isServer) exitWith {};

params ["_caller", "_restSite"];

private _coolDownVar = "GM_Heal_LastUsedTime";
private _coolDownSeconds = 600;
private _currentTime = time;
private _lastUsedTime = missionNamespace getVariable [_coolDownVar, 0];

if (_currentTime - _lastUsedTime >= _coolDownSeconds) then {
    [_restSite] remoteExec ["fnc_rest_heal", 2];
    missionNamespace setVariable [_coolDownVar, _currentTime];
    publicVariable _coolDownVar;
    _speakeracteam = localize "STR_DUWS_T_actionteam";
    _message = ([localize "STR_DUWS_T_restsuccess"] call fnc_cs);
    [_speakeracteam, _message] remoteExec ["fnc_duws_dialogue", 0];
} else {
    _speaker = localize "STR_DUWS_T_OVERLORD";
    _message1 = localize "STR_DUWS_T_restcooldown";
    [_speaker, _message1] remoteExec ["fnc_duws_dialogue", _caller];
    hint (localize "STR_DUWS_T_restcooldownhint");
};