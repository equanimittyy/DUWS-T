/*
    fnc_corpse_search_action.sqf
    在尸体上添加长按搜身获取情报的动作
    参数: _netId (尸体网络ID)
*/
if (!hasInterface) exitWith {};

params ["_netId"];
private _corpse = objectFromNetId _netId;
if (isNull _corpse) exitWith {};

if (_corpse getVariable ["corpse_search_action_added", false]) exitWith {};
_corpse setVariable ["corpse_search_action_added", true];

// 获取当前任务目标位置（由任务脚本设置）
private _targetPos = missionNamespace getVariable ["current_mission_target_pos", []];

// 存储到尸体变量，供回调使用
_corpse setVariable ["corpse_target_pos", _targetPos];

// 添加长按动作
[
    _corpse,                                                            // 目标对象
    localize "STR_DUWS_T_SEARCH_CORPSE",                                // 动作标题
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",      // 空闲图标
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",      // 进度图标
    "_this distance _target < 3",                                       // 动作可用条件
    "_caller distance _target < 3",                                     // 进度条件
    {                                                                   // 开始代码
        params ["_target", "_caller", "_actionId", "_arguments"];
        private _playerName = name _caller;
        [_playerName, localize "STR_DUWS_T_SEARCH_START_SUBTITLE"] remoteExec ["BIS_fnc_showSubtitle", _caller];
    },
    {},                                                                 // 每帧代码
    {                                                                   // 完成代码
        params ["_target", "_caller", "_actionId", "_arguments"];
        _arguments params ["_targetPos"];
        private _rand = random 1;
        private _playerName = name _caller;
        
        if (_rand < 0.4) then {
            // 40% 揭示目标位置
            if (count _targetPos == 3) then {
                private _markerName = format ["intel_reveal_%1", round time];
                createMarker [_markerName, _targetPos];
                _markerName setMarkerShape "ICON";
                _markerName setMarkerType "o_unknown";
                _markerName setMarkerColor "ColorRed";
                _markerName setMarkerSize [0.8, 0.8];
                _markerName setMarkerText localize "STR_DUWS_T_INTEL_TARGET";
                [_markerName] spawn { sleep 120; deleteMarker (_this select 0); };
                // 单行通知（标题 + 描述）
                ["info", [localize "STR_DUWS_T_INTEL_FOUND_TARGETtitle", localize "STR_DUWS_T_INTEL_FOUND_TARGETdesc"]] remoteExec ["BIS_fnc_showNotification", 0];
                // 使用玩家名字作为说话者
                [_playerName, ([localize "STR_DUWS_T_INTEL_FOUND_TARGET"] call fnc_cs)] remoteExec ["BIS_fnc_showSubtitle", 0];
	            [] remoteExec ["fnc_broadcastRadioChatter", 0];
                sleep 8;
                [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_INTEL_FOUND_TARGET2"] remoteExec ["BIS_fnc_showSubtitle", 0];
	            [] remoteExec ["fnc_broadcastRadioChatter", 0];
            };
        } else {
            if (_rand < 0.6) then {
                // 20% 额外情报：+1 CP, +1 AP
                [1] remoteExec ["fnc_cp_adjust", 2];
                WARCOM_blufor_ap = WARCOM_blufor_ap + 1;
                publicVariable "WARCOM_blufor_ap";
                [_playerName, localize "STR_DUWS_T_INTEL_FOUND_x"] remoteExec ["BIS_fnc_showSubtitle", 0];
	            [] remoteExec ["fnc_broadcastRadioChatter", 0];
                ["infosearch", [localize "STR_DUWS_T_INTEL_BONUS_TITLE", format [localize "STR_DUWS_T_INTEL_BONUS_DESC", 1, 1]]] remoteExec ["BIS_fnc_showNotification", 0];
            } else {
                // 40% 无收获s
                [_playerName, localize "STR_DUWS_T_INTEL_FOUND_n"] remoteExec ["BIS_fnc_showSubtitle", _caller];
            };
        };
    },
    {},                                                                 // 中断代码
    [_targetPos],                                                       // 传递参数
    2,                                                                  // 持续时间（秒）
    1,                                                                  // 优先级
    true,                                                               // 完成后移除
    false                                                               // 不在昏迷状态显示
] call BIS_fnc_holdActionAdd;

diag_log format ["[INTEL] HoldAction added to corpse %1", _corpse];