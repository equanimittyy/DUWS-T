// Locality: all machines; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 0).
/*
    fnc_civ_healAction.sqf
    参数: _unit - 平民单位
    为平民添加提供医疗救助的动作。
    优先消耗玩家携带的 ACE 食物，其次为医疗箱（FirstAidKit）。
    成功时有 70% 几率提升玩家声望，失败时不消耗任何物品。
    仅在非丧尸/非 WBK 模式下添加。
*/
params ["_unit"];

if (isNull _unit) exitWith {};

private _actionID = _unit addAction [
    localize "STR_DUWS_T_CIV_HEAL",
    {
        params ["_target", "_caller", "_actionId"];
        // 让平民停止移动
        _target disableAI "PATH";
        
        // ===== 定义 ACE 食物列表（如果未加载 ACE，这些类名不存在，但不影响逻辑）=====
        private _aceFoods = [
            "ACE_MRE_SteakVegetables",
            "ACE_MRE_MeatballsPasta",
            "ACE_MRE_LambCurry",
            "ACE_MRE_CreamTomatoSoup",
            "ACE_MRE_CreamChickenSoup",
            "ACE_MRE_ChickenHerbDumplings",
            "ACE_MRE_ChickenTikkaMasala",
            "ACE_MRE_BeefStew",
            "ACE_Humanitarian_Ration"
        ];
        
        // 检查玩家是否拥有 ACE 食物
        private _hasFood = false;
        private _foodItem = "";
        {
            if (_x in _aceFoods) exitWith {
                _hasFood = true;
                _foodItem = _x;
            };
        } forEach (items _caller);
        
        // 检查是否拥有医疗箱
        private _hasFirstAidKit = "FirstAidKit" in (items _caller);
        
        // 如果都没有，退出并保留动作，允许玩家以后再来
        if (!_hasFood && !_hasFirstAidKit) exitWith {
            hint (localize "STR_DUWS_T_NO_FirstAidKit");
        };
        
        // 移除平民身上所有动作，防止重复交互
        removeAllActions _target;
        [_target] remoteExec ["removeAllActions", 0];
        
        [([localize "STR_DUWS_T_actionteam"] call fnc_cs), localize "STR_DUWS_T_providemed"] call BIS_fnc_showSubtitle;
        sleep 3;
        
        // 70% 成功率
        if (random 1 < 0.7) then {
            // ---- 成功：根据持有的物品种类扣除 ----
            if (_hasFood) then {
                _caller removeItem _foodItem;
            } else {
                _caller removeItem "FirstAidKit";
            };
            
            [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_providemedtks"] call BIS_fnc_showSubtitle;
            [0.5, "healed_civilian"] remoteExec ["fnc_rep_adjust", 2];
            // The change is applied on the server, so the local copy is still the old
            // value here; show the expected total rather than re-reading the global.
            ["info", [localize "STR_DUWS_T_rqwho9bq", format [localize "STR_DUWS_T_0pluxey2", Player_Reputation + 0.5]]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated, false];
            [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_HEAL_SUCCESS"] call BIS_fnc_showSubtitle;
            hint (localize "STR_DUWS_T_HEAL_SUCCESS_HINT");
        } else {
            // ---- 失败：不消耗任何物品 ----
            [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_HEAL_FAIL"] call BIS_fnc_showSubtitle;
            hint (localize "STR_DUWS_T_HEAL_FAIL_HINT");
        };
        
        // 恢复平民移动（如果还活着）
        if (alive _target) then {
            _target enableAI "PATH";
        };
    },
    nil,
    6,
    true,
    true,
    "",
    "_this distance _target < 3"
];

_unit setVariable ["healActionID", _actionID];

// 平民死亡时移除所有动作
_unit addEventHandler ["Killed", {
    params ["_unit"];
    removeAllActions _unit;
    [_unit] remoteExec ["removeAllActions", 0];
}];