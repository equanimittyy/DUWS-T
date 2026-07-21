/*
    fnc_civ_addDevelopInformantAction.sqf
    参数: _unit - 平民单位
    为平民添加“发展线人”动作，由客户端执行
    修改：消耗 5 个 Money_roll 而不是 CP
*/
params ["_unit"];

if (isNull _unit) exitWith {};

private _locIndex = _unit getVariable ["civ_locIndex", -1];
if (_locIndex == -1) exitWith {};
if (missionNamespace getVariable [format ["civ_informant_active_%1", _locIndex], false]) exitWith {};

private _actionID = _unit addAction [
    localize "STR_DUWS_T_DEVELOP_INFORMANT",
    {
        params ["_target", "_caller", "_actionId"];
        removeAllActions _target;
        [_target] remoteExec ["removeAllActions", 0];
        private _locIndex = _target getVariable ["civ_locIndex", -1];
        if (_locIndex == -1) exitWith {};
        
        // 检查玩家是否有至少 5 个 Money_roll
        private _moneyCount = { _x == "Money_roll" } count ((items _caller) + (magazines _caller));
        if (_moneyCount < 5) exitWith {
            // 复用原有 CP 不足提示（本地化不变）
            hint localize "STR_DUWS_T_nocpinf2";
            [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_nocpinf"] remoteExec ["BIS_fnc_showSubtitle", _caller];
        };
        
        [_target, _caller, _locIndex] remoteExec ["fnc_civ_developInformantServer", 2];
        [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_askinf"] call BIS_fnc_showSubtitle;
    },
    nil,
    6,
    true,
    true,
    "",
    "_this distance _target < 3"
];

_unit setVariable ["devActionID", _actionID];