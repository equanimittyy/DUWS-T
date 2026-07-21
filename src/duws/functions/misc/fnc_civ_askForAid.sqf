/*
    fnc_civ_askForAid.sqf
    参数: _unit - 平民单位
    为平民添加“请求医疗援助”动作，消耗1纸币，成功时生成医疗箱
    仅非丧尸模式添加，多人兼容
*/
params ["_unit"];

if (isNull _unit) exitWith {};

// 防重：避免重复添加
if (_unit getVariable ["askForAidActionAdded", false]) exitWith {};
_unit setVariable ["askForAidActionAdded", true];

private _actionID = _unit addAction [
    localize "STR_DUWS_T_ASK_FOR_AID",   // 需要在 stringtable.xml 中添加对应的本地化键
    {
        params ["_target", "_caller", "_actionId"];
        // 立即移除该平民身上的这个动作（一次性）
        _target removeAction _actionId;
        _target setVariable ["askForAidActionAdded", false];
        // 远程调用服务器处理实际逻辑
        [_target, _caller] remoteExec ["fnc_civ_askForAid_server", 2];
    },
    nil,
    6,
    true,
    true,
    "",
    "_this distance _target < 3"
];

_unit setVariable ["askForAidActionID", _actionID];

// 平民死亡时清理动作
_unit addEventHandler ["Killed", {
    params ["_unit"];
    private _aid = _unit getVariable ["askForAidActionID", -1];
    if (_aid != -1) then { _unit removeAction _aid; };
    _unit setVariable ["askForAidActionAdded", nil];
}];