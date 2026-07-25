if (!isServer) exitWith {};

private _missionTypes = [
    ["STR_DUWS_T_mortarspotter", fnc_dyna_mission_mortarspotter, 0.1],
    ["STR_DUWS_T_supply_recovery", fnc_dyna_mission_supply_recovery, 0.1]
];

// 初始化全局活动标志
missionNamespace setVariable ["dyna_mission_active", false];

sleep 120;

while {true} do {
    sleep 1200; // 测试用，正常应为1200

    // 如果已经有任务在运行，跳过本次循环
    if (missionNamespace getVariable ["dyna_mission_active", false]) then {
        ["WARN", "MISSION", "A mission is already active, skipping this cycle."] call fnc_log;
        continue;
    };

    // 遍历任务类型
    {
        _x params ["_nameKey", "_fnc", "_chance"];
        if (random 1 < _chance) then {
            // 设置全局活动标志
            missionNamespace setVariable ["dyna_mission_active", true];
            // 启动任务，传递名称键
            [_nameKey] spawn _fnc;
            // 只触发一个任务，跳出循环
            break;
        };
    } forEach _missionTypes;
};