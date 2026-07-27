// Locality: all machines; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 0).
params ["_unit"];

if (isNull _unit) exitWith {};

private _actionID = _unit addAction [
    localize "STR_DUWS_T_CIV_RECRUIT",
    {
        params ["_target", "_caller", "_actionId"];
        [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_fight4freedom"] call fnc_duws_dialogue;
        sleep 3;
        // --- 前置检查：检查玩家是否有至少 2 个 Money_roll ---
        private _moneyCount = { _x == "Money_roll" } count (magazines _caller);
        if (_moneyCount < 2) exitWith {
            hint (localize "STR_DUWS_T_nocpinf2"); // 复用原有提示
            [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_NOT_ENOUGH_CP"] call fnc_duws_dialogue;
        };
        // --- 移除所有客户端上该平民的所有动作 ---
        removeAllActions _target;
        [_target] remoteExec ["removeAllActions", 0];
        // The reputation gate and the roll need the town, which is server-local.
        [_target, _caller] remoteExec ["fnc_civ_recruit_server", 2];
    },
    nil,
    6,
    true,
    true,
    "",
    "_this distance _target < 3"
];

_unit setVariable ["recruitActionID", _actionID];