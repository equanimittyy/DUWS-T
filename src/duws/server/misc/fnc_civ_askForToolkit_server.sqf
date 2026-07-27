/*
    fnc_civ_askForToolkit_server.sqf
    参数: [_civilian, _caller]
    服务器处理：声望为正时50%概率成功，扣除2纸币，成功生成工具箱
*/
if (!isServer) exitWith {};

params ["_civilian", "_caller"];

if (isNull _civilian || isNull _caller) exitWith {};
[localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_ASK_TOOLKIT_hi"] remoteExec ["fnc_duws_dialogue", _caller];

sleep 5;

// 该城镇声望（平民自带城镇编号，无需距离判定）
private _rep = [_civilian getVariable ["civ_locIndex", -1]] call fnc_civ_repAt;

if (_rep <= 0) exitWith {
    [localize "STR_DUWS_T_ASK_TOOLKIT_FAIL_REP"] remoteExec ["hint", _caller];
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_ASK_TOOLKIT_REFUSE"] remoteExec ["fnc_duws_dialogue", _caller];
};

// 检查并扣除 2 个 Money_roll
private _moneyRemoved = 0;
{
    if (_x == "Money_roll" && _moneyRemoved < 2) then {
        _caller removeItem "Money_roll";
        _moneyRemoved = _moneyRemoved + 1;
    };
} forEach (items _caller);
if (_moneyRemoved < 2) then {
    {
        if (_x == "Money_roll" && _moneyRemoved < 2) then {
            _caller removeMagazineGlobal "Money_roll";
            _moneyRemoved = _moneyRemoved + 1;
        };
    } forEach (magazines _caller);
};

if (_moneyRemoved < 2) exitWith {
    [localize "STR_DUWS_T_nocpinf2"] remoteExec ["hint", _caller];
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_NOT_ENOUGH_CP"] remoteExec ["fnc_duws_dialogue", _caller];
};

// 50% 成功率
private _success = random 1 < 0.5;

if (!_success) exitWith {
    [localize "STR_DUWS_T_ASK_TOOLKIT_FAIL"] remoteExec ["hint", _caller];
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_ASK_TOOLKIT_REFUSE2"] remoteExec ["fnc_duws_dialogue", _caller];
};

// 成功：生成工具箱
private _pos = getPosATL _civilian;
private _toolkit = createVehicle ["Item_Toolkit", _pos, [], 0, "CAN_COLLIDE"];
_toolkit setPosATL [_pos select 0, _pos select 1, (_pos select 2) + 0.05];
_toolkit enableSimulation true;

[localize "STR_DUWS_T_ASK_TOOLKIT_SUCCESS"] remoteExec ["hint", _caller];
[localize "STR_DUWS_T_civ", localize "STR_DUWS_T_ASK_TOOLKIT_GRANT"] remoteExec ["fnc_duws_dialogue", _caller];