// Locality: all machines; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 0).
/*
    fnc_addAskEnemyAction.sqf
    参数: _unit - 平民单位
    为平民添加打听敌人动向的动作。判定在服务器上进行（fnc_civ_askEnemy_server），
    结果由 fnc_civ_askEnemy_reveal 在询问者本机呈现。
    消耗 1 个钱币（Money_roll）
*/
params ["_unit"];

if (isNull _unit) exitWith {};

private _actionID = _unit addAction [
    localize "STR_DUWS_T_ASK_ENEMY",
    {
        params ["_target", "_caller", "_actionId"];

        // The caller's own inventory, so this stays here; everything downstream of it needs the
        // town's reputation, which is server-local.
        private _moneyCount = { _x == "Money_roll" } count (magazines _caller);
        if (_moneyCount < 1) exitWith {
            hint (localize "STR_DUWS_T_nocpinf2");
            [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_NOT_ENOUGH_CP"] call fnc_duws_dialogue;
            removeAllActions _target;
            [_target] remoteExec ["removeAllActions", 0];
        };

        removeAllActions _target;
        [_target] remoteExec ["removeAllActions", 0];
        [_target, _caller] remoteExec ["fnc_civ_askEnemy_server", 2];
    },
    nil,
    6,
    true,
    true,
    "",
    "_this distance _target < 3"
];

_unit setVariable ["askActionID", _actionID];

// 平民死亡时移除所有动作
_unit addEventHandler ["Killed", {
    params ["_unit"];
    removeAllActions _unit;
    [_unit] remoteExec ["removeAllActions", 0];
}];