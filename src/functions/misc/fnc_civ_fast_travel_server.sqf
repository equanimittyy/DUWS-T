/*
    fnc_civ_fast_travel_server.sqf
    服务器：处理快速传送请求，验证条件并响应
    参数: [_caller, _requestId]
    修改：消耗 3 个 Money_roll 而不是 CP
*/
if (!isServer) exitWith {};

params ["_caller", "_requestId"];
private _varName = format ["fast_travel_req_%1", _requestId];

// 检查声望
private _rep = missionNamespace getVariable ["Player_Reputation", 0];
if (_rep < 1) exitWith {
    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_FAST_TRAVEL_hey"] remoteExec ["BIS_fnc_showSubtitle", _caller];
    sleep 4;
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_FAST_TRAVEL_fkoff"] remoteExec ["BIS_fnc_showSubtitle", _caller];
    missionNamespace setVariable [_varName, [false, localize "STR_DUWS_T_FAST_TRAVEL_LOW_REP"]];
    publicVariable _varName;
};

// 50% 成功率
private _successRoll = random 1 < 0.5;
if (!_successRoll) exitWith {
    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_FAST_TRAVEL_hey"] remoteExec ["BIS_fnc_showSubtitle", _caller];
    sleep 4;
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_FAST_TRAVEL_idk"] remoteExec ["BIS_fnc_showSubtitle", _caller];
    missionNamespace setVariable [_varName, [false, localize "STR_DUWS_T_FAST_TRAVEL_FAIL_ROLL"]];
    publicVariable _varName;
};

// ===== 检查并扣除 1 个 Money_roll =====
private _moneyRemoved = 0;
{
    if (_x == "Money_roll" && _moneyRemoved < 1) then {
        _caller removeItem "Money_roll";
        _moneyRemoved = _moneyRemoved + 1;
    };
} forEach (items _caller);
if (_moneyRemoved < 1) then {
    {
        if (_x == "Money_roll" && _moneyRemoved < 1) then {
            _caller removeMagazineGlobal "Money_roll";
            _moneyRemoved = _moneyRemoved + 1;
        };
    } forEach (magazines _caller);
};

if (_moneyRemoved < 1) exitWith {
    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_FAST_TRAVEL_hey"] remoteExec ["BIS_fnc_showSubtitle", _caller];
    sleep 4;
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_FAST_TRAVEL_ne"] remoteExec ["BIS_fnc_showSubtitle", _caller];
    missionNamespace setVariable [_varName, [false, localize "STR_DUWS_T_nocpinf2"]];
    publicVariable _varName;
};

[localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_FAST_TRAVEL_hey"] remoteExec ["BIS_fnc_showSubtitle", _caller];
sleep 4;
[localize "STR_DUWS_T_civ", localize "STR_DUWS_T_FAST_TRAVEL_ik"] remoteExec ["BIS_fnc_showSubtitle", _caller];

// 成功响应
missionNamespace setVariable [_varName, [true, ""]];
publicVariable _varName;