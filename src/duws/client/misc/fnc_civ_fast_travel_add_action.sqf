// Locality: client; the addAction bodies below run on the machine that triggers them, not here.
/*
    fnc_civ_fast_travel_add_action.sqf
    为平民添加快速传送动作（始终显示，但声望不足时会失败）
    参数: _unit - 平民单位
    修改：消耗 1 个 Money_roll 而不是 CP
*/
if (!hasInterface) exitWith {};

params ["_unit"];
if (isNull _unit) exitWith {};

// 避免重复添加
if (_unit getVariable ["fast_travel_action_added", false]) exitWith {};
_unit setVariable ["fast_travel_action_added", true];

private _actionID = _unit addAction [
    localize "STR_DUWS_T_FAST_TRAVEL_CIV",
    {
        params ["_target", "_caller", "_actionId"];
        // 客户端预检查：是否有至少 1 个 Money_roll
        private _moneyCount = { _x == "Money_roll" } count (magazines _caller);
        if (_moneyCount < 1) exitWith {
            hint (localize "STR_DUWS_T_nocpinf2"); // 复用 CP 不足提示
        };
        // 立即移除该动作，防止重复点击同一个平民
        _target removeAction _actionId;
        // 调用请求函数
        [_caller] spawn fnc_civ_fast_travel_request;
    },
    nil,
    6,
    true,
    true,
    "",
    "_this distance _target < 3"
];
_unit setVariable ["fast_travel_action_id", _actionID];

// 平民死亡时移除动作
_unit addEventHandler ["Killed", {
    params ["_unit"];
    private _aid = _unit getVariable ["fast_travel_action_id", -1];
    if (_aid != -1) then { _unit removeAction _aid; };
    _unit setVariable ["fast_travel_action_added", nil];
}];