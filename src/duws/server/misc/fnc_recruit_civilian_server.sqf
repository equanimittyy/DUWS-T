/*
    fnc_recruit_civilian_server.sqf
    由客户端远程调用，在服务器执行实际招募逻辑
    参数: [_civilian, _caller, _civNetId, _callerUID]
    修改: 招募成功后清除城镇标记，防止被清理脚本误删
          同时立即减少对应城镇的人口并更新图标
          在 WBK 模式下奖励 8 CP，并动态显示奖励值
*/
// Recruitment reports through a hint box on purpose, not folded into the spoken dialogue the way
// the other civilian interactions are: stock DUWS confirms a recruit this way and players read it
// as the confirmation. The RAVAGE/WBK path this sits on is due a wider pass; the channel is not
// the part to change.
params ["_civilian", "_caller", "_civNetId", "_callerUID"];

if (!isServer) exitWith {};

// 重新获取对象（防止网络延迟导致对象失效）
if (isNull _civilian) then {
    _civilian = objectFromNetId _civNetId;
};
if (isNull _caller) then {
    {
        if (getPlayerUID _x == _callerUID) exitWith { _caller = _x; };
    } forEach allPlayers;
};

// 有效性检查
if (isNull _civilian || isNull _caller) exitWith {
    ["ERROR", "CIV", "Error: civilian or caller is null"] call fnc_log;
};
if (!alive _civilian) exitWith {
    [localize "STR_DUWS_T_RECRUIT_DEAD"] remoteExec ["hint", _caller];
};
if (_civilian getVariable ["recruit_processed_server", false]) exitWith {
    [localize "STR_DUWS_T_RECRUIT_ALREADY"] remoteExec ["hint", _caller];
};

_civilian setVariable ["recruit_processed_server", true];

// 记录原组和城镇索引（用于后续清理）
private _oldGroup = group _civilian;
private _locIndex = _civilian getVariable ["civ_locIndex", -1];

// 95%成功率
if (random 1 < 0.95) then {
    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_RECRUITconv1"] remoteExec ["fnc_duws_dialogue", _caller];
    sleep 3;
    [localize "STR_DUWS_T_survivor", localize "STR_DUWS_T_RECRUITconv2"] remoteExec ["fnc_duws_dialogue", _caller];
    
    // ---- 成功招募 ----
    // 终止漫游脚本（如果存在）
    private _roamHandle = _civilian getVariable ["roamScript", scriptNull];
    if (!isNull _roamHandle) then {
        terminate _roamHandle;
        _civilian setVariable ["roamScript", nil];
    };
    
    // 将平民转移到玩家组（自动处理阵营变化）
    [_civilian] joinSilent (group _caller);
    _civilian setVariable ["civ_locIndex", nil];
    
    // 确保单位不再被视为俘虏，且启用所有 AI 功能
    _civilian setCaptive false;
    _civilian stop false;
    _civilian enableAI "MOVE";
    _civilian enableAI "PATH";
    _civilian enableAI "AUTOTARGET";
    _civilian enableAI "TARGET";
    _civilian setUnitPos "AUTO";
    [_civilian] joinSilent (group _caller);
    _civilian setVariable ["civ_locIndex", nil];
    sleep 0.1;
    [_civilian] joinSilent (group _caller);
    _civilian setVariable ["civ_locIndex", nil];
    
    // 清除城镇标记（防止后续清理脚本误删）
    _civilian setVariable ["civ_locIndex", nil];
    
    // 处理原组：如果原组空了，则删除；并从城镇组列表中移除原组
    if (!isNull _oldGroup) then {
        if (count units _oldGroup == 0) then {
            deleteGroup _oldGroup;
        };
        if (_locIndex != -1) then {
            private _groupsVar = format ["civ_groups_%1", _locIndex];
            private _groups = missionNamespace getVariable [_groupsVar, []];
            _groups = _groups - [_oldGroup];
            missionNamespace setVariable [_groupsVar, _groups];
        };
    };
    
    ["INFO", "CIV", format ["Civilian %1 successfully recruited by %2", _civilian, name _caller]] call fnc_log;
    
    sleep 3;
    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_RECRUITconv3"] remoteExec ["fnc_duws_dialogue", _caller];
    [_civilian] joinSilent (group _caller);
    _civilian setVariable ["civ_locIndex", nil];
    
    // 启动回收检测（到达基地时删除并奖励）
    [_civilian, _caller] spawn {
        params ["_unit", "_caller"];
        private _hqPos = PosOfBLUHQ;
        waitUntil {
            sleep 5;
            (!alive _unit) || (_unit distance _hqPos < 50)
        };
        if (alive _unit && _unit distance _hqPos < 50) then {
            [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_RECRUITconv4"] remoteExec ["fnc_duws_dialogue", _caller];
            sleep 3;
            [localize "STR_DUWS_T_survivor", localize "STR_DUWS_T_RECRUITconv5"] remoteExec ["fnc_duws_dialogue", _caller];
            deleteVehicle _unit;
            
            // 根据平民模式决定奖励 CP
            private _reward = 5;
            if (CIV_PRESENCE == "WBK") then {
                _reward = 8;
            };
            [_reward, "civilian_recruited"] remoteExec ["fnc_cp_adjust", 2];
            
            // 构建动态描述文本，显示实际奖励值
            private _desc = format [localize "STR_DUWS_T_RECRUIT_gainCP", _reward];
            ["repup", [localize "STR_DUWS_T_RECRUIT_SUCCESS2", _desc]] remoteExec ["BIS_fnc_showNotification", 0];
        };
    };
    
    // 提示招募者成功
    [localize "STR_DUWS_T_RECRUIT_SUCCESS_MSG"] remoteExec ["hint", _caller];
    
} else {
    // ---- 招募失败 ----
    _civilian setBehaviour "CARELESS";
    _civilian doMove (getPos _civilian getPos [random 50, random 360]);
    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_RECRUITconv1"] remoteExec ["fnc_duws_dialogue", _caller];
    sleep 3;
    [localize "STR_DUWS_T_survivor", localize "STR_DUWS_T_RECRUITconv6"] remoteExec ["fnc_duws_dialogue", _caller];
    [localize "STR_DUWS_T_RECRUIT_FAIL_MSG"] remoteExec ["hint", _caller];
    sleep 3;
    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_RECRUITconv7"] remoteExec ["fnc_duws_dialogue", _caller];
};