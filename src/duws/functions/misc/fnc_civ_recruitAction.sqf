params ["_unit"];

if (isNull _unit) exitWith {};

private _actionID = _unit addAction [
    localize "STR_DUWS_T_CIV_RECRUIT",
    {
        params ["_target", "_caller", "_actionId"];
        [([localize "STR_DUWS_T_actionteam"] call fnc_cs), localize "STR_DUWS_T_fight4freedom"] call BIS_fnc_showSubtitle;
        sleep 3;
        // --- 前置检查：检查玩家是否有至少 2 个 Money_roll ---
        private _moneyCount = { _x == "Money_roll" } count (magazines _caller);
        if (_moneyCount < 2) exitWith {
            hint (localize "STR_DUWS_T_nocpinf2"); // 复用原有提示
            [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_NOT_ENOUGH_CP"] call BIS_fnc_showSubtitle;
        };
        private _rep = missionNamespace getVariable ["Player_Reputation", 0];
        if (_rep <= 0) exitWith {
            hint (localize "STR_DUWS_T_RECRUIT_FAIL_REP_HINT");
            [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_RECRUIT_FAIL_REP"] call BIS_fnc_showSubtitle;
            // 让平民随机跑离
            private _runDir = random 360;
            private _runDist = 50 + random 50;
            private _runPos = (getPos _target) getPos [_runDist, _runDir];
            _target doMove _runPos;
        };
        // --- 移除所有客户端上该平民的所有动作 ---
        removeAllActions _target;
        [_target] remoteExec ["removeAllActions", 0];
        // --- 计算成功率 ---
        private _chance = (_rep min 7) * 0.1; // 每点声望10%，最高70%
        if (random 1 < _chance) then {
            // 成功招募：本地设置俘虏状态以获得即时反馈
            _target setCaptive false;
            // 发送网络 ID 到服务器，由服务器广播给所有客户端（确保全网一致）
            private _netId = netId _target;
            [_netId, false] remoteExec ["fnc_globalSetCaptive", 2];
            // 调用服务器函数进行后续处理（服务器端会扣除钱币）
            [_target, _caller, _netId] remoteExec ["fnc_recruitSuccessServer", 2];
        } else {
            // 让平民随机跑离
            private _runDir = random 360;
            private _runDist = 50 + random 50;
            private _runPos = (getPos _target) getPos [_runDist, _runDir];
            _target doMove _runPos;
            [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_RECRUIT_FAIL"] call BIS_fnc_showSubtitle;
            hint (localize "STR_DUWS_T_RECRUIT_FAIL_HINT");
        };
    },
    nil,
    6,
    true,
    true,
    "",
    "_this distance _target < 3"
];

_unit setVariable ["recruitActionID", _actionID];