/*
    fnc_night_horde_event.sqf
    功能：夜间随机尸潮事件，生成多波僵尸进攻HQ，并创建任务
    执行端：服务器
    依赖：PosOfBLUHQ（HQ位置）
    注意：仅在丧尸模式 (CIV_PRESENCE == "RAVAGE") 下启用，请在调用处控制。
*/

if (!isServer) exitWith {};

// 从存档中读取上次触发日，默认为-1
private _lastHordeDate = missionNamespace getVariable ["Horde_LastDay", -1];

// 定义僵尸类名数组（仅使用 zombie_runner）
private _zombieClasses = [
    "zombie_runner"
];

// 检查Ravage模组是否加载（以 zombie_runner 是否存在为准）
if (!isClass (configFile >> "CfgVehicles" >> "zombie_runner")) then {
    _zombieClasses = [
        "C_Man_casual_1_F"  // 后备：使用单一平民类名
    ];
    ["ERROR", "MISSION", "Ravage mod not found, using default civilian for horde."] call fnc_log;
};

// 主循环
while {true} do {
    // 等待进入夜间时段（20:00 - 05:00）
    waitUntil {
        sleep 60;
        (daytime >= 20 || daytime < 5)
    };

    private _checkInterval = 2; // 测试用，正式请改回600

    // 夜间持续循环
    while {daytime >= 20 || daytime < 5} do {
        private _currentDay = date select 2; // 当前天数（1-31）

        // 如果今天尚未触发过
        if (_lastHordeDate != _currentDay) then {
            // 10%概率触发
            if (random 1 < 0.1) then {
                _lastHordeDate = _currentDay; // 记录触发日
                missionNamespace setVariable ["Horde_LastDay", _lastHordeDate]; // 保存到存档
                [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_hordealert1"] remoteExec ["fnc_duws_dialogue", 0];
                [] remoteExec ["fnc_broadcastRadioChatter", 0];
                sleep 6;
                [localize "STR_DUWS_T_actionteam", ([localize "STR_DUWS_T_hordealert2"] call fnc_cs)] remoteExec ["fnc_duws_dialogue", 0];
                [] remoteExec ["fnc_broadcastRadioChatter", 0];
                sleep 6;

                // 创建任务
                if ("horde_task" call BIS_fnc_taskExists) then {
                    ["horde_task"] call BIS_fnc_deleteTask;
                };
                private _taskID = "horde_task";
                [
                    west,
                    _taskID,
                    [
                        localize "STR_DUWS_T_HORDE_TASK_DESC",
                        localize "STR_DUWS_T_HORDE_TASK_TITLE",
                        PosOfBLUHQ
                    ],
                    objNull,
                    true,
                    0,
                    true
                ] call BIS_fnc_taskCreate;

                private _hqPos = PosOfBLUHQ;
                private _waveCount = 3;
                private _allPlayers = call BIS_fnc_listPlayers; // 获取所有玩家

                for "_wave" from 1 to _waveCount do {
                    private _zombieGroup = createGroup [civilian, true];
                    private _spawnPos = [_hqPos, 130, 150, 5, 0, 0.2, 0] call BIS_fnc_findSafePos;

                    // 生成40个僵尸
                    for "_i" from 1 to 40 do {
                        private _unitType = selectRandom _zombieClasses;
                        private _unit = _zombieGroup createUnit [_unitType, _spawnPos, [], 0, "NONE"];
                        _unit setPos ([_spawnPos, 0, 10, 3, 0, 0.2, 0] call BIS_fnc_findSafePos);
                        _unit allowDamage false;
                        _unit setBehaviour "AWARE";
                        _unit setCombatMode "RED";
                        _unit setVariable ["Vcm_Disable", true];
                        _unit setSpeedMode "FULL";
                        sleep 0.2;
                    };

                    // 清除组原有路点，添加新路点到HQ
                    while {(count (waypoints _zombieGroup)) > 0} do {
                        deleteWaypoint ((waypoints _zombieGroup) select 0);
                    };
                    private _wp = _zombieGroup addWaypoint [_hqPos, 0];
                    _wp setWaypointType "SAD";
                    _wp setWaypointSpeed "FULL";
                    _wp setWaypointBehaviour "AWARE";
                    _wp setWaypointCombatMode "RED";
                    _wp setWaypointCompletionRadius 50;

                    // 让每个僵尸知晓所有玩家位置
                    {
                        _x reveal [_x, 4];
                    } forEach units _zombieGroup;

                    // 延迟5秒后允许伤害
                    [_zombieGroup] spawn {
                        params ["_group"];
                        sleep 5;
                        {
                            _x allowDamage true;
                        } forEach units _group;
                    };

                    if (_wave < _waveCount) then { sleep 40 };
                };

                ["INFO", "MISSION", "Event triggered successfully."] call fnc_log;

                // 最后一波生成后等待60秒，任务成功
                [_taskID] spawn {
                    params ["_taskID"];
                    sleep 60;
                    [_taskID, "SUCCEEDED"] call BIS_fnc_taskSetState;
                };
            };
        };

        sleep _checkInterval;
        if (daytime >= 5 && daytime < 20) then { break };
    };
};