/*
    fnc_civ_fast_travel_server.sqf
    服务器：处理快速传送请求，验证条件并响应
    参数: [_caller, _requestId]
    修改：消耗 3 个 Money_roll 而不是 CP
*/
if (!isServer) exitWith {};

params ["_caller", "_requestId"];
private _varName = format ["fast_travel_req_%1", _requestId];

// The town the player is standing in, not the one they are travelling to: the destination is
// chosen on a map click after this gate has already passed and taken payment, so it does not
// exist yet. What is being gated is whether the locals here will arrange the trip.
private _rep = [[getPos _caller] call fnc_civ_townAt] call fnc_civ_repAt;
if (_rep < 1) exitWith {
    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_FAST_TRAVEL_hey"] remoteExec ["fnc_duws_dialogue", _caller];
    sleep 4;
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_FAST_TRAVEL_fkoff"] remoteExec ["fnc_duws_dialogue", _caller];
    missionNamespace setVariable [_varName, [false, localize "STR_DUWS_T_FAST_TRAVEL_LOW_REP"]];
    publicVariable _varName;
};

// 50% 成功率
private _successRoll = random 1 < 0.5;
if (!_successRoll) exitWith {
    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_FAST_TRAVEL_hey"] remoteExec ["fnc_duws_dialogue", _caller];
    sleep 4;
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_FAST_TRAVEL_idk"] remoteExec ["fnc_duws_dialogue", _caller];
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
    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_FAST_TRAVEL_hey"] remoteExec ["fnc_duws_dialogue", _caller];
    sleep 4;
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_FAST_TRAVEL_ne"] remoteExec ["fnc_duws_dialogue", _caller];
    missionNamespace setVariable [_varName, [false, localize "STR_DUWS_T_nocpinf2"]];
    publicVariable _varName;
};

[localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_FAST_TRAVEL_hey"] remoteExec ["fnc_duws_dialogue", _caller];
sleep 4;
[localize "STR_DUWS_T_civ", localize "STR_DUWS_T_FAST_TRAVEL_ik"] remoteExec ["fnc_duws_dialogue", _caller];

// 成功响应
missionNamespace setVariable [_varName, [true, ""]];
publicVariable _varName;