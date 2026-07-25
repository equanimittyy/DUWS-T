// Locality: all machines; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 0).
/*
    fnc_addAskEnemyAction.sqf
    参数: _unit - 平民单位
    为平民添加打听敌人动向的动作，根据声望决定结果
    成功时揭示一个1500米内的随机红方班组位置（本地标记）
    询问期间平民停止移动
    消耗 1 个钱币（Money_roll）
*/
params ["_unit"];

if (isNull _unit) exitWith {};

private _actionID = _unit addAction [
    localize "STR_DUWS_T_ASK_ENEMY",
    {
        params ["_target", "_caller", "_actionId"];
        
        // 检查玩家是否有至少 1 个 Money_roll
        private _moneyCount = { _x == "Money_roll" } count (magazines _caller);
        if (_moneyCount < 1) exitWith {
            hint (localize "STR_DUWS_T_nocpinf2");
            [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_NOT_ENOUGH_CP"] remoteExec ["BIS_fnc_showSubtitle", _caller];
            removeAllActions _target;
            [_target] remoteExec ["removeAllActions", 0];
        };
        
        // 让平民停止移动
        _target disableAI "PATH";
        
        // 移除所有客户端上该平民的所有动作
        removeAllActions _target;
        [_target] remoteExec ["removeAllActions", 0];
        [([localize "STR_DUWS_T_actionteam"] call fnc_cs), localize "STR_DUWS_T_askopforloc"] remoteExec ["BIS_fnc_showSubtitle", _caller];
        
        private _rep = missionNamespace getVariable ["Player_Reputation", 0];
        if (_rep > 0) then {
            private _chance = _rep * 0.1;
            if (_chance > 0.7) then { _chance = 0.7; };
            sleep 3;
            if (random 1 < _chance) then {
                // 成功：扣除 1 个 Money_roll
                _caller removeMagazineGlobal "Money_roll";
                
                private _nearEastGroups = allGroups select {
                    side _x == EAST && 
                    { alive (leader _x) && { (leader _x) distance _caller <= 700 } }
                };
                if (count _nearEastGroups > 0) then {
                    private _selectedGroup = selectRandom _nearEastGroups;
                    private _leaderPos = getPos (leader _selectedGroup);
                    private _markerName = format ["enemy_group_%1", diag_tickTime];
                    createMarker [_markerName, _leaderPos];
                    _markerName setMarkerShapeLocal "ICON";
                    _markerName setMarkerTypeLocal "o_unknown";
                    _markerName setMarkerColorLocal "ColorRed";
                    _markerName setMarkerTextLocal (localize "STR_DUWS_T_ENEMY_GROUP");
                    _markerName setMarkerSizeLocal [0.8, 0.8];
                    
                    [_markerName] spawn { sleep 60; deleteMarker (_this select 0); };
                    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_askopforlocyes"] remoteExec ["BIS_fnc_showSubtitle", _caller];
                    hint (localize "STR_DUWS_T_ASK_SUCCESS");
                } else {
                    hint (localize "STR_DUWS_T_NO_ENEMY_GROUPS");
                    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_askopforlocno2"] remoteExec ["BIS_fnc_showSubtitle", _caller];
                    sleep 4;
                    [([localize "STR_DUWS_T_actionteam"] call fnc_cs), localize "STR_DUWS_T_askopforlocno3"] remoteExec ["BIS_fnc_showSubtitle", _caller];
                };
            } else {
                hint (localize "STR_DUWS_T_ASK_FAIL");
                // 让平民随机跑离
                private _runDir = random 360;
                private _runDist = 50 + random 50;
                private _runPos = (getPos _unit) getPos [_runDist, _runDir];
                _unit doMove _runPos;
                [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_askopforlocno"] remoteExec ["BIS_fnc_showSubtitle", _caller];
            };
        } else {
            sleep 5;
            hint (localize "STR_DUWS_T_ASK_REFUSE");
            private _runDir = random 360;
            private _runDist = 50 + random 50;
            private _runPos = (getPos _unit) getPos [_runDist, _runDir];
            _unit doMove _runPos;
            [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_stfu"] remoteExec ["BIS_fnc_showSubtitle", _caller];
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

_unit setVariable ["askActionID", _actionID];

// 平民死亡时移除所有动作
_unit addEventHandler ["Killed", {
    params ["_unit"];
    removeAllActions _unit;
    [_unit] remoteExec ["removeAllActions", 0];
}];