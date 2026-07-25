// Locality: all machines; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 0).
/*
    fnc_civ_askForToolkit.sqf
    参数: _unit - 平民单位
    为平民添加“请求工具箱”动作，消耗2纸币，50%成功率，成功时生成工具箱
    多人兼容
*/
params ["_unit"];

if (isNull _unit) exitWith {};

// 防重
if (_unit getVariable ["askForToolkitActionAdded", false]) exitWith {};
_unit setVariable ["askForToolkitActionAdded", true];

private _actionID = _unit addAction [
    localize "STR_DUWS_T_ASK_FOR_TOOLKIT",
    {
        params ["_target", "_caller", "_actionId"];
        _target removeAction _actionId;
        _target setVariable ["askForToolkitActionAdded", false];
        [_target, _caller] remoteExec ["fnc_civ_askForToolkit_server", 2];
    },
    nil,
    6,
    true,
    true,
    "",
    "_this distance _target < 3"
];

_unit setVariable ["askForToolkitActionID", _actionID];

_unit addEventHandler ["Killed", {
    params ["_unit"];
    private _aid = _unit getVariable ["askForToolkitActionID", -1];
    if (_aid != -1) then { _unit removeAction _aid; };
    _unit setVariable ["askForToolkitActionAdded", nil];
}];