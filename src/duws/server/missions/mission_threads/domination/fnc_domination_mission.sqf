// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
if (!([13, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

// 定义任务基本参数
_radius = 800;
_cpreward = 10;
_apreward = 25;
_speaker = localize "STR_DUWS_T_hound";
_speaker1 = localize "STR_DUWS_T_OVERLORD";
_speakeracteam = localize "STR_DUWS_T_actionteam";
_message = localize "STR_DUWS_T_dominationletsdothis";
_message1 = ([localize "STR_DUWS_T_dominationoverlord"] call fnc_cs);
_message2 = ([localize "STR_DUWS_T_dominationcopy"] call fnc_cs);
_message3 = ([localize "STR_DUWS_T_dominationend"] call fnc_cs);
_messagehoundlost = ([localize "STR_DUWS_T_dominationhoundlost"] call fnc_cs);
_markerText = "Hound Pos";
_markerText2 = localize "STR_DUWS_T_c13";

// 初始化变量
_randomPos = [];
_Posfound = false;
_targetpos = [];
_failSafe = 0;

// [MOD] 用于存储蓝方 APC 标记名称，任务结束时清理
_apcMarkers = [];

// 调用函数寻找合适的任务目标位置
_POSdata = [_MissionPos, _radius, _Posfound, _targetpos, _failSafe] call fnc_missionTargetPos;

_randomPos = _POSdata select 0;
_Posfound = _POSdata select 2;
_targetpos = _POSdata select 3;
_failSafe = _POSdata select 4;

// 如果安全计数器超过10次且仍未找到合适位置，则退出任务并提示
if (_failsafe > 10 && _Posfound == false) exitWith {
    Mission_available = true; 
    publicVariable "Mission_available"; 
    [{hint"No suitable location found. Please try again."}] remoteExec ["BIS_fnc_Spawn", 0];
};

// 向玩家显示任务提示
["Armor Hunting",{hint _this}] remoteExec ["BIS_fnc_Spawn", 0];

sleep 2;

// ================ 水域检测生成函数 ================

// 蓝方步兵组生成函数（带水域检测，在中心附近生成）
_fn_waterproofBluforGroupCenter = {
    params ["_centerPos", "_spawnRadius", "_unitTypes", "_faceDirection"];
    
    private ["_spawnPos", "_attempts", "_validPos"];
    
    _attempts = 0;
    _validPos = false;
    
    // 尝试最多10次找到合适的生成位置
    while {_attempts < 10 && !_validPos} do {
        // 在中心点_spawnRadius米内创建随机位置
        _randomAngle = random 360;
        _randomDistance = random _spawnRadius;
        _spawnPos = _centerPos getPos [_randomDistance, _randomAngle];
        
        // 检测位置是否在水中
        if (!surfaceIsWater _spawnPos) then {
            _validPos = true;
        };
        
        _attempts = _attempts + 1;
        sleep 0.5; // 避免密集循环
    };
    
    // 如果10次尝试后仍未找到合适位置，则使用最后一次尝试的位置
    if (!_validPos) then {
        _randomAngle = random 360;
        _randomDistance = random _spawnRadius;
        _spawnPos = _centerPos getPos [_randomDistance, _randomAngle];
    };
    
    // 调整位置，确保在地面上
    _groundPos = _spawnPos;
    _groundPos set [2, 0];
    
    // 创建班组
    _bluforGroup = [_groundPos, WEST, _unitTypes, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
    
    // 为蓝方部队设置战斗状态和自动战斗
    {
        // 禁用逃跑 - 设为0表示完全不会逃跑
        _x allowFleeing 0;
        
        // 启用自动战斗模式（保持开启）
        // 注意：这里我们不使用disableAI "AUTOCOMBAT"，以保持自动战斗开启
        
        // 设置AI为战斗状态
        _x setBehaviour "COMBAT";
        _x setCombatMode "RED";
        
        // 设置单位立即进入警戒状态
        _x setUnitPos "AUTO";
        
        // 设置单位面向指定方向
        _x setDir _faceDirection;
        
    } forEach units _bluforGroup;
    
    // 删除组时的自动清理
    _bluforGroup deleteGroupWhenEmpty true;
    
    // 返回创建的组
    _bluforGroup
};

// 蓝方车辆生成函数（带水域检测，在中心附近生成）
_fn_waterproofBluforVehicleCenter = {
    params ["_centerPos", "_spawnRadius", "_vehicleType", "_faceDirection"];
    
    private ["_spawnPos", "_attempts", "_validPos"];
    
    _attempts = 0;
    _validPos = false;
    
    // 尝试最多10次找到合适的生成位置
    while {_attempts < 10 && !_validPos} do {
        // 在中心点_spawnRadius米内创建随机位置
        _randomAngle = random 360;
        _randomDistance = random _spawnRadius;
        _spawnPos = _centerPos getPos [_randomDistance, _randomAngle];
        
        // 检测位置是否在水中
        if (!surfaceIsWater _spawnPos) then {
            _validPos = true;
        };
        
        _attempts = _attempts + 1;
        sleep 0.5; // 避免密集循环
    };
    
    // 如果10次尝试后仍未找到合适位置，则使用最后一次尝试的位置
    if (!_validPos) then {
        _randomAngle = random 360;
        _randomDistance = random _spawnRadius;
        _spawnPos = _centerPos getPos [_randomDistance, _randomAngle];
    };
    
    // 调整位置，确保在地面上
    _groundPos = _spawnPos;
    _groundPos set [2, 0];
    
    // 创建车辆，并设置面向红方进攻方向
    _vehicle = createVehicle [_vehicleType, _groundPos, [], 0, "NONE"];
    _vehicle setDir _faceDirection;
    
    // 返回创建的车辆
    _vehicle
};

// 蓝方载具乘员组生成函数（使用BIS_fnc_spawnGroup）
_fn_createBluforCrewGroup = {
    params ["_vehicle", "_centerPos", "_unitTypes", "_faceDirection"];
    
    // 在车辆位置创建乘员组
    _crewGroup = [getPos _vehicle, WEST, _unitTypes, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
    
    // 为每个乘员分配车辆座位并确保他们进入车辆
    _units = units _crewGroup;
    
    if (count _units >= 1) then {
        _units select 0 assignAsDriver _vehicle;
        (_units select 0) moveInDriver _vehicle;
    };
    
    if (count _units >= 2) then {
        _units select 1 assignAsGunner _vehicle;
        (_units select 1) moveInGunner _vehicle;
    };
    
    if (count _units >= 3) then {
        _units select 2 assignAsCommander _vehicle;
        (_units select 2) moveInCommander _vehicle;
    };
    
    // 额外处理：确保所有单位都进入车辆（包括可能的多余乘员）
    {
        if (!(_x in _vehicle)) then {
            _x moveInCargo _vehicle;
        };
    } forEach _units;
    
    // 为蓝方乘员设置战斗状态和自动战斗
    {
        // 设置乘员无敌（任务开始前）
        _x allowDamage false;
        _x allowFleeing 0;
        
        // 启用自动战斗模式（保持开启）
        // 注意：这里我们不使用disableAI "AUTOCOMBAT"，以保持自动战斗开启
        
        // 设置AI为战斗状态
        _x setBehaviour "COMBAT";
        _x setCombatMode "RED";
        
        // 设置单位面向指定方向
        _x setDir _faceDirection;
        
    } forEach units _crewGroup;
    
    // 删除组时的自动清理
    _crewGroup deleteGroupWhenEmpty true;
    
    // 返回创建的组
    _crewGroup
};

// 红方步兵组生成函数（带水域检测，在边缘生成）
_fn_waterproofOpforGroupEdge = {
    params ["_centerPos", "_radius", "_unitTypes", "_opforAngle"];
    
    private ["_spawnPos", "_attempts", "_validPos"];
    
    _attempts = 0;
    _validPos = false;
    
    // 尝试最多10次找到合适的生成位置
    while {_attempts < 10 && !_validPos} do {
        // 在边缘（半径附近）创建位置，基于给定角度
        _angleVariation = (random 60) - 30; // 在指定角度±30度内变化
        _currentAngle = _opforAngle + _angleVariation;
        
        // 确保角度在0-360范围内
        while {_currentAngle >= 360} do {_currentAngle = _currentAngle - 360};
        while {_currentAngle < 0} do {_currentAngle = _currentAngle + 360};
        
        // 距离在半径的80%-100%之间
        _distanceVariation = _radius * (0.8 + random 0.2);
        _spawnPos = _centerPos getPos [_distanceVariation, _currentAngle];
        
        // 检测位置是否在水中
        if (!surfaceIsWater _spawnPos) then {
            _validPos = true;
        };
        
        _attempts = _attempts + 1;
        sleep 0.5; // 避免密集循环
    };
    
    // 如果10次尝试后仍未找到合适位置，则使用最后一次尝试的位置
    if (!_validPos) then {
        _spawnPos = _centerPos getPos [_radius, _opforAngle];
    };
    
    // 调整位置，确保在地面上
    _groundPos = _spawnPos;
    _groundPos set [2, 0];
    
    // 创建班组
    _opforGroup = [_groundPos, EAST, _unitTypes, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    {
    [_x] call fnc_addRandomLoot;
    } forEach units _opforGroup;
    // 为红方部队设置战斗状态和自动战斗（已修改：开启autocombat并设为战斗状态）
    {
        // 禁用逃跑 - 设为0表示完全不会逃跑
        _x allowFleeing 0;
        
        // 启用自动战斗模式（保持开启）- 移除disableAI "AUTOCOMBAT"
        // 注意：这里我们不使用disableAI "AUTOCOMBAT"，以保持自动战斗开启
        
        // 设置AI为战斗状态
        _x setBehaviour "COMBAT";
        _x setCombatMode "RED";
        
        // 设置单位立即进入警戒状态
        _x setUnitPos "AUTO";
        
        // 设置单位面向任务中心方向
        _x setDir (_opforAngle - 180);
        
    } forEach units _opforGroup;
    
    // 删除组时的自动清理
    _opforGroup deleteGroupWhenEmpty true;
    
    // 返回创建的组
    _opforGroup
};

// 红方车辆生成函数（带水域检测，在边缘生成）
_fn_waterproofOpforVehicleEdge = {
    params ["_centerPos", "_radius", "_vehicleType", "_opforAngle"];
    
    private ["_spawnPos", "_attempts", "_validPos"];
    
    _attempts = 0;
    _validPos = false;
    
    // 尝试最多10次找到合适的生成位置
    while {_attempts < 10 && !_validPos} do {
        // 在边缘（半径附近）创建位置，基于给定角度
        _angleVariation = (random 60) - 30; // 在指定角度±30度内变化
        _currentAngle = _opforAngle + _angleVariation;
        
        // 确保角度在0-360范围内
        while {_currentAngle >= 360} do {_currentAngle = _currentAngle - 360};
        while {_currentAngle < 0} do {_currentAngle = _currentAngle + 360};
        
        // 距离在半径的80%-100%之间
        _distanceVariation = _radius * (0.8 + random 0.2);
        _spawnPos = _centerPos getPos [_distanceVariation, _currentAngle];
        
        // 检测位置是否在水中
        if (!surfaceIsWater _spawnPos) then {
            _validPos = true;
        };
        
        _attempts = _attempts + 1;
        sleep 0.5; // 避免密集循环
    };
    
    // 如果10次尝试后仍未找到合适位置，则使用最后一次尝试的位置
    if (!_validPos) then {
        _spawnPos = _centerPos getPos [_radius, _opforAngle];
    };
    
    // 调整位置，确保在地面上
    _groundPos = _spawnPos;
    _groundPos set [2, 0];
    
    // 创建车辆
    _vehicle = createVehicle [_vehicleType, _groundPos, [], 0, "NONE"];
    _vehicle setDir _opforAngle; // 车辆面向任务中心方向
    
    // 返回创建的车辆
    _vehicle
};

// 红方载具乘员组生成函数（使用BIS_fnc_spawnGroup）
_fn_createOpforCrewGroup = {
    params ["_vehicle", "_centerPos", "_unitTypes", "_faceDirection"];
    
    // 在车辆位置创建乘员组
    _crewGroup = [getPos _vehicle, EAST, _unitTypes, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    
    // 为每个乘员分配车辆座位并确保他们进入车辆
    _units = units _crewGroup;
    
    if (count _units >= 1) then {
        _units select 0 assignAsDriver _vehicle;
        (_units select 0) moveInDriver _vehicle;
    };
    
    if (count _units >= 2) then {
        _units select 1 assignAsGunner _vehicle;
        (_units select 1) moveInGunner _vehicle;
    };
    
    if (count _units >= 3) then {
        _units select 2 assignAsCommander _vehicle;
        (_units select 2) moveInCommander _vehicle;
    };
    
    // 额外处理：确保所有单位都进入车辆（包括可能的多余乘员）
    {
        if (!(_x in _vehicle)) then {
            _x moveInCargo _vehicle;
        };
    } forEach _units;
    
    // 为红方乘员设置无敌状态和战斗行为（已修改：开启autocombat并设为战斗状态）
    {
        // 设置乘员无敌（任务开始前）
        _x allowDamage false;
        _x allowFleeing 0;
        
        // 启用自动战斗模式（保持开启）- 移除disableAI "AUTOCOMBAT"
        // 注意：这里我们不使用disableAI "AUTOCOMBAT"，以保持自动战斗开启
        
        // 设置AI为战斗状态
        _x setBehaviour "COMBAT";
        _x setCombatMode "RED";
        
        // 设置单位面向任务中心方向
        _x setDir _faceDirection;
        
    } forEach units _crewGroup;
    
    // 删除组时的自动清理
    _crewGroup deleteGroupWhenEmpty true;
    
    // 返回创建的组
    _crewGroup
};

// 验证和调整红方进攻角度，确保不在水中
_fn_validateOpforAngle = {
    params ["_centerPos", "_radius", "_initialAngle"];
    
    private ["_currentAngle", "_attempts", "_foundValidAngle", "_testPos"];
    
    _currentAngle = _initialAngle;
    _attempts = 0;
    _foundValidAngle = false;
    
    // 最多尝试10个不同的角度
    while {_attempts < 10 && !_foundValidAngle} do {
        // 在该角度上检查3个不同的距离点
        _validPoints = 0;
        
        // 检查半径的80%、90%和100%处的点
        for "_i" from 0 to 2 do {
            _distance = _radius * (0.8 + (_i * 0.1));
            _testPos = _centerPos getPos [_distance, _currentAngle];
            
            if (!surfaceIsWater _testPos) then {
                _validPoints = _validPoints + 1;
            };
        };
        
        // 如果3个点中有2个以上不在水中，则认为这个角度有效
        if (_validPoints >= 2) then {
            _foundValidAngle = true;
        } else {
            // 尝试下一个角度（增加45度）
            _currentAngle = _currentAngle + 45;
            if (_currentAngle >= 360) then {
                _currentAngle = _currentAngle - 360;
            };
            _attempts = _attempts + 1;
        };
        
        sleep 0.5;
    };
    
    // 如果10次尝试后仍未找到合适角度，则返回原始角度
    if (!_foundValidAngle) then {
        _currentAngle = _initialAngle;
        ["INFO", "MISSION", format ["WARNING: NO suitable attack angle found, using original one: %1", _currentAngle]] call fnc_log;
    };
    
    _currentAngle
};

// ================ 生成部队 ================

// 随机选择红方进攻方向，并确保不在水中
_initialOpforAngle = random 360;
_opforAngle = [_MissionPos, _radius, _initialOpforAngle] call _fn_validateOpforAngle;

_bluforSpawnRadius = 150; // 蓝方在中心150米半径内生成
_redSpawnRadius = _radius - 50; // 红方在半径边缘生成（留50米缓冲）

// 计算蓝方面对的方向（朝向红方进攻方向）
_bluforFaceDir = _opforAngle; // 直接面对红方进攻方向

// 创建蓝方部队 - 分开为载具组和步兵组
_bluforVehicleGroups = []; // 存储蓝方载具组
_bluforInfantryGroups = []; // 存储蓝方步兵组
_bluforUnitsAll = []; // 存储所有蓝方单位以便后续设置无敌状态
_bluforAPCs = [];      // [MOD] 存储蓝方APC车辆，用于红方侦察与路点

// 蓝方乘员类型定义 - 使用标准的乘员单位类型
_bluforCrewTypes = [
    blufor_SOLDIER_X,      // 驾驶员
    blufor_SOLDIER_X,      // 炮手
    blufor_SOLDIER_X       // 车长
];

for "_i" from 1 to 2 do {
    // ================ 蓝方载具组 ================
    // 生成蓝方装甲运兵车，面向红方进攻方向
    _bluforAPC = [_MissionPos, _bluforSpawnRadius, blufor_APC_PATROL1_X, _bluforFaceDir] call _fn_waterproofBluforVehicleCenter;
    
    _bluforAPCs pushBack _bluforAPC; // [MOD] 记录此APC

    // [MOD] 为当前 APC 创建地图标记
    _apcMarkerName = format ["apc_marker_%1_%2", _i, round(time)];
    _apcMarker = createMarker [_apcMarkerName, getPos _bluforAPC];
    _apcMarker setMarkerType "o_unknown";
    _apcMarker setMarkerColor "ColorBlue";
    _apcMarker setMarkerSize [1, 1];
    _apcMarker setMarkerText "APC";
    _apcMarkers pushBack _apcMarkerName;

    // 使用BIS_fnc_spawnGroup生成乘员组
    _bluforVehicleGroup = [_bluforAPC, _MissionPos, _bluforCrewTypes, _bluforFaceDir] call _fn_createBluforCrewGroup;
    
    // 检查乘员是否在车辆内
    {
        // 将乘员添加到所有单位数组中
        _bluforUnitsAll pushBack _x;
    } forEach units _bluforVehicleGroup;
    
    // 设置APC为无敌状态（任务开始前）
    _bluforAPC allowDamage false;
    _bluforUnitsAll pushBack _bluforAPC;
    
    // 将载具组添加到载具组数组
    _bluforVehicleGroups pushBack _bluforVehicleGroup;
    
    // ================ 蓝方步兵组 ================
    // 在APC附近创建步兵组
    _apcPos = getPos _bluforAPC;
    
    // 步兵类型
    _bluforInfantryTypes = [
        blufor_SOLDIER_SL_X,
        blufor_SOLDIER_TL_X,
        blufor_SOLDIER_AR_X,
        blufor_MARKSMAN_X,
        blufor_SOLDIER_SL_X,
        blufor_SOLDIER_TL_X,
        blufor_SOLDIER_AR_X,
        blufor_MARKSMAN_X
    ];
    
    // 使用BIS_fnc_spawnGroup创建步兵组
    _infantryGroup = [_apcPos, WEST, _bluforInfantryTypes, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
    
    // 将组中的每个单位移动到APC周围的随机位置
    {
        // 计算步兵位置（在APC旁边）
        _angle = random 360;
        _distance = 10 + random 5; // 距离APC 10-15米
        _infantryPos = _apcPos getPos [_distance, _angle];
        
        // 确保位置不在水中
        if (surfaceIsWater _infantryPos) then {
            // 如果在水里，尝试靠近APC
            _infantryPos = _apcPos getPos [5, _angle];
        };
        
        // 将单位移动到新位置
        _x setPos _infantryPos;
        
        // 设置步兵战斗状态和自动战斗
        _x allowDamage false; // 设置步兵无敌（任务开始前）
        _x allowFleeing 0;
        
        // 启用自动战斗模式（保持开启）
        // 注意：这里我们不使用disableAI "AUTOCOMBAT"，以保持自动战斗开启
        
        // 设置AI为战斗状态
        _x setBehaviour "COMBAT";
        _x setCombatMode "RED";
        
        // 设置单位立即进入警戒状态
        _x setUnitPos "AUTO";
        
        // 设置单位面向红方进攻方向
        _x setDir _bluforFaceDir;
        
        // 将步兵添加到所有单位数组中
        _bluforUnitsAll pushBack _x;
        
    } forEach units _infantryGroup;
    
    // 设置步兵组行为
    _infantryGroup setBehaviour "COMBAT";
    _infantryGroup setCombatMode "RED";
    
    // 删除组时的自动清理
    _infantryGroup deleteGroupWhenEmpty true;
    
    // 将步兵组添加到步兵组数组
    _bluforInfantryGroups pushBack _infantryGroup;
};

// 创建红方步兵班组（在边缘生成）
_opforGroups = [];
for "_i" from 1 to 3 do {
    _opforUnits = [
        opfor_SOLDIER_X,
        opfor_AR_SOLDIER_X,
        opfor_AR_SOLDIER_X,
        opfor_AR_SOLDIER_X,
        opfor_GL_SOLDIER_X,
        opfor_AA_SOLDIER_X,
        opfor_TL_SOLDIER_X,
        opfor_AR_SOLDIER_X,
        opfor_AR_SOLDIER_X,
        opfor_GL_SOLDIER_X
    ];
    
    // 使用水域检测函数生成红方班组（在边缘，基于指定角度）
    _opforGroup = [_MissionPos, _redSpawnRadius, _opforUnits, _opforAngle] call _fn_waterproofOpforGroupEdge;
    _opforGroups pushBack _opforGroup;
};

// 红方乘员类型定义 - 使用标准的乘员单位类型
_opforCrewTypes = [
    opfor_CREW_X,      // 驾驶员
    opfor_CREW_X,      // 炮手
    opfor_CREW_X       // 车长
];

// 生成红方坦克（在边缘生成）- 4辆
_opforTanks = [];
_opforTankGroups = [];
_opforTankUnitsAll = []; // 存储所有红方坦克乘员以便后续设置无敌状态

for "_i" from 1 to 4 do {
    _opforTank = [_MissionPos, _redSpawnRadius, opfor_MBT_TANK1_X, _opforAngle] call _fn_waterproofOpforVehicleEdge;
    
    // 使用BIS_fnc_spawnGroup生成乘员组
    _opforTankGroup = [_opforTank, _MissionPos, _opforCrewTypes, _opforAngle] call _fn_createOpforCrewGroup;
    // 检查乘员是否在车辆内
    {
        // 将乘员添加到所有单位数组中
        _opforTankUnitsAll pushBack _x;
    } forEach units _opforTankGroup;
    
    // 设置坦克为无敌状态（任务开始前）
    _opforTank allowDamage false;
    {
    [_x] call fnc_addRandomLoot;
    } forEach units _crewGroup;
    _opforTankUnitsAll pushBack _opforTank;
    
    _opforTanks pushBack _opforTank;
    _opforTankGroups pushBack _opforTankGroup;
};

// 将所有红方组合并到一个数组
_allOpforGroups = _opforGroups + _opforTankGroups;

// ---------- 蓝方侦察红方（原有逻辑）----------
{
    _bluforUnit = _x;
    // Reveal红方坦克
    {
        _bluforUnit reveal _x;
    } forEach _opforTanks;
    
    // Reveal红方步兵
    {
        {
            _bluforUnit reveal _x;
        } forEach units _x;
    } forEach _opforGroups;
    
    // Reveal红方坦克乘员组
    {
        {
            _bluforUnit reveal _x;
        } forEach units _x;
    } forEach _opforTankGroups;
} forEach _bluforUnitsAll;

// ---------- [MOD] 红方侦察蓝方（对称侦察）----------
// 收集所有红方单位（坦克、坦克乘员、步兵）
_allRedUnits = [];
{
    _allRedUnits pushBack _x;
} forEach _opforTanks;
{
    {
        _allRedUnits pushBack _x;
    } forEach units _x;
} forEach _opforTankGroups;
{
    {
        _allRedUnits pushBack _x;
    } forEach units _x;
} forEach _opforGroups;

// 每个红方单位主动侦察所有蓝方单位
{
    _redUnit = _x;
    {
        _redUnit reveal _x;
    } forEach _bluforUnitsAll;
} forEach _allRedUnits;
// ---------- 侦察修改结束 ----------

// ================ 创建红方出生点箭头标记 ================

// 计算红方出生点位置（在边缘）
_redSpawnPos = _MissionPos getPos [_redSpawnRadius, _opforAngle];

// 确保位置不在水中
_attempts = 0;
_validMarkerPos = false;
while {_attempts < 10 && !_validMarkerPos} do {
    _testPos = _MissionPos getPos [_redSpawnRadius, _opforAngle + (random 60 - 30)];
    
    if (!surfaceIsWater _testPos) then {
        _redSpawnPos = _testPos;
        _validMarkerPos = true;
    };
    
    _attempts = _attempts + 1;
    sleep 0.5;
};

[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 12;
[_speaker1, _message1] remoteExec ["fnc_duws_dialogue", 0];
sleep 12;
[_speakeracteam, _message2] remoteExec ["fnc_duws_dialogue", 0];
sleep 12;

// 计算箭头指向任务中心的方向
_arrowDir = _redSpawnPos getDir _MissionPos;
// 创建箭头标记
_arrowMarkerName = format ["opfor_spawn_arrow_%1", round(time)];
_arrowMarker = createMarker [_arrowMarkerName, _redSpawnPos];
_arrowMarker setMarkerType "mil_arrow2";
_arrowMarker setMarkerColor "ColorRed";
_arrowMarker setMarkerDir _arrowDir; // 箭头指向任务中心
_arrowMarker setMarkerSize [1.1, 1.1];
_arrowMarker setMarkerAlpha 0.7;
_arrowMarker setMarkerText localize "STR_DUWS_T_dominationarrow";
//Create the marker	
_markerData = [_randomPos, _markerText, _markerText2, _radius] call fnc_missionMarkerData;
_markername = _markerData select 0;
_markername2 = _markerData select 1;

// TASK AND NOTIFICATION
private "_VARtaskgeneratedName";
// 生成唯一的任务变量名
_VARtaskgeneratedName = format ["combat%1%2", round(_MissionPos select 0), round(_MissionPos select 1)];

// 创建任务：消灭所有红方坦克
[west, [_VARtaskgeneratedName], 
[localize "STR_DUWS_T_domination", _mission_name, _markername2], objNull, true] call BIS_fnc_taskCreate; 

// ================ [MOD] 设置红方路点（进攻蓝方APC位置） ================

// 获取所有蓝方APC的位置
_bluforAPCPositions = [];
{
    _bluforAPCPositions pushBack (getPos _x);
} forEach _bluforAPCs;

// 为红方所有组设置路点：依次攻击每一个蓝方APC
{
    _group = _x;
    // 为每辆APC添加一个SAD路点
    {
        _wp = _group addWaypoint [_x, 0];
        _wp setWaypointType "SAD";
        _wp setWaypointBehaviour "AWARE";
        _wp setWaypointCombatMode "RED";
        _wp setWaypointSpeed "FULL";
    } forEach _bluforAPCPositions;
    
    // 添加一个循环路点，确保持续搜索目标（指向第一个APC位置）
    _wp2 = _group addWaypoint [_bluforAPCPositions select 0, 0];
    _wp2 setWaypointType "SAD";
    _wp2 setWaypointBehaviour "AWARE";
    _wp2 setWaypointCombatMode "RED";
    _wp2 setWaypointSpeed "FULL";
} forEach _allOpforGroups;

sleep 5;
// ================ 解除载具无敌状态（任务创建后） ================
// 蓝方所有单位（载具、乘员、步兵）恢复可被伤害
{
    _x allowDamage true;
} forEach _bluforUnitsAll;

// 红方坦克和乘员恢复可被伤害
{
    _x allowDamage true;
} forEach _opforTankUnitsAll;


sleep 90;
{
    _x setDamage 1;
} forEach _bluforAPCs;
[_speaker1, _messagehoundlost] remoteExec ["fnc_duws_dialogue", 0];
// ================ 任务完成条件 ================
// 等待条件：红方载具乘员组全部死亡 或 任务被取消
waitUntil {
    sleep 3;
    
    // 检查是否所有红方坦克乘员组全部死亡
    _allCrewDead = true;
    {
        // 检查该组中是否有存活的成员
        if ({alive _x} count units _x > 0) then {
            _allCrewDead = false;
        };
    } forEach _opforTankGroups;
    
    _allCrewDead
};

// 删除标记
deleteMarker str(_markername2);
deleteMarker str(_markername);
deleteMarker _arrowMarkerName;
// [MOD] 删除蓝方 APC 标记
{ deleteMarker _x; } forEach _apcMarkers;

[_speaker1, _message3] remoteExec ["fnc_duws_dialogue", 0];
sleep 12;
[_VARtaskgeneratedName, "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated,_VARtaskgeneratedName];

sleep 1;

// 给予奖励：指挥点、行动点，并显示通知
[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
// 启动下一个任务计时器
[] spawn fnc_missionTimer;
// 启动清理程序
[_MissionPos, _radius, "", true] spawn fnc_mission_cleanup;