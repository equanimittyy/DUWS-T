/*
    fnc_civ_askForAid_server.sqf
    参数: [_civilian, _caller]
    在服务器上处理求援逻辑：检查声望、扣除纸币、生成医疗箱
*/
if (!isServer) exitWith {};

params ["_civilian", "_caller"];

if (isNull _civilian || isNull _caller) exitWith {};

[localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_ASK_AID_hi"] remoteExec ["fnc_duws_dialogue", _caller];
sleep 5;
// 获取该城镇声望（平民自带城镇编号，无需距离判定）
private _rep = [_civilian getVariable ["civ_locIndex", -1]] call fnc_civ_repAt;
if (_rep <= 0) exitWith {
    // 声望不足，失败提示
    [localize "STR_DUWS_T_ASK_AID_FAIL_REP"] remoteExec ["hint", _caller];
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_ASK_AID_REFUSE"] remoteExec ["fnc_duws_dialogue", _caller];
};

// 检查并扣除 1 个 Money_roll
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
    [localize "STR_DUWS_T_nocpinf2"] remoteExec ["hint", _caller];
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_NOT_ENOUGH_CP"] remoteExec ["fnc_duws_dialogue", _caller];
};

// 成功：在平民周围地面生成医疗箱
private _pos = getPosATL _civilian;
private _medikit = createVehicle ["Item_Medikit", _pos, [], 0, "CAN_COLLIDE"];
// 确保物品落在地面（如果悬空则调整）
_medikit setPosATL [_pos select 0, _pos select 1, (_pos select 2) + 0.05];
_medikit enableSimulation true;
// 60秒后自动删除
[_medikit] spawn {
    params ["_box"];
    sleep 60;
    if (!isNull _box) then { deleteVehicle _box; };
};

// 成功提示
[localize "STR_DUWS_T_ASK_AID_SUCCESS"] remoteExec ["hint", _caller];
[localize "STR_DUWS_T_civ", localize "STR_DUWS_T_ASK_AID_GRANT"] remoteExec ["fnc_duws_dialogue", _caller];