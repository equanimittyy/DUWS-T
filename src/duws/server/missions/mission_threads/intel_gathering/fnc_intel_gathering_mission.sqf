// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];

// ========== 增援系统变量（必须提前声明，避免提前退出时未定义） ==========
private _varSuffix = format ["%1_%2", round(_MissionPos select 0), round(_MissionPos select 1)];
private _initialCountVar = format ["opf_initial_%1", _varSuffix];
private _triggeredVar = format ["opf_reinforce_%1", _varSuffix];
// ====================================

private _radius = 800;
private _minBuildings = 20;
_cpreward = 5;
_apreward = 5;
// 获取可用建筑（至少需要3个建筑位置）
private _usableBuildings = [_MissionPos, 3, _radius] call fnc_usableBuildings;

if (count _usableBuildings < _minBuildings) exitWith {
    diag_log format ["[Intel Mission] Not enough usable buildings (%1), aborting.", count _usableBuildings];
    hint localize "STR_DUWS_T_INTEL_GATHERING_NO_BUILDINGS";
    // 不设置冷却，直接退出
};

// Gated after the building check on purpose: too few buildings must not burn the cooldown.
if (!([16, _MissionPos, _mission_name] call fnc_mission_begin)) exitWith {};

// ========== 随机选取最多30个建筑 ==========
private _maxBuildings = 30;
private _selectedBuildings = [];
if (count _usableBuildings <= _maxBuildings) then {
    _selectedBuildings = _usableBuildings;
} else {
    private _tempArray = +_usableBuildings;
    for "_i" from 1 to _maxBuildings do {
        private _index = floor random (count _tempArray);
        _selectedBuildings pushBack (_tempArray select _index);
        _tempArray deleteAt _index;
    };
};
diag_log format ["[Intel Mission] Selected %1 buildings.", count _selectedBuildings];

// ========== 定义敌方单位类型池 ==========
private _possibleUnitTypes = [];
{
    if (!isNil "_x" && {_x != ""}) then {
        _possibleUnitTypes pushBack _x;
    };
} forEach [
    opfor_SOLDIER_X,
    opfor_AA_SOLDIER_X,
    opfor_AR_SOLDIER_X,
    opfor_AT_SOLDIER_X,
    opfor_LAT_SOLDIER_X,
    opfor_SL_SOLDIER_X,
    opfor_GL_SOLDIER_X,
    opfor_MARK_SOLDIER_X
];
if (count _possibleUnitTypes == 0) then {
    _possibleUnitTypes = [opfor_SOLDIER_X];
};

// ========== 容器类名列表 ==========
private _containerClasses = [
    "Land_PaperBox_open_full_F",
    "Land_Ammobox_rounds_F",
    "Land_Suitcase_F",
    "Land_PaperBox_01_small_ransacked_brown_F",
    "Land_PaperBox_01_small_destroyed_brown_F",
    "Land_WoodenCrate_01_F",
    "Land_WoodenBox_F",
    "Land_PaperBox_01_small_destroyed_white_IDAP_F",
    "Land_PaperBox_01_small_ransacked_white_IDAP_F",
    "Land_WoodenBox_02_F",
    "Land_MetalCase_01_small_F",
    "Land_PlasticCase_01_small_olive_CBRN_F"
];

private _allSpawnedContainers = [];
private _allSpawnedUnits = [];
private _buildingMarkers = [];  // 存储建筑标记名称

// ========== 定义容器交互动作（客户端函数）==========
if (isNil "fnc_intel_container_addAction") then {
    fnc_intel_container_addAction = {
        params ["_container"];
        if (isNull _container) exitWith {};
        if (_container getVariable ["container_action_added", false]) exitWith {};
        _container setVariable ["container_action_added", true];
        
        [
            _container,
            localize "STR_DUWS_T_SEARCH_CONTAINER",
            "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
            "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_search_ca.paa",
            "_this distance _target < 3",
            "_caller distance _target < 3",
            {},
            {},
            {
                params ["_target", "_caller", "_actionId", "_arguments"];
                [_target, _caller] remoteExec ["fnc_intel_container_search_server", 2];
                _target removeAction _actionId;
                _target setVariable ["container_action_added", nil];
            },
            {},
            [],
            1,
            0,
            true,
            false
        ] call BIS_fnc_holdActionAdd;
    };
    publicVariable "fnc_intel_container_addAction";
};

// ========== 定义服务器端处理函数（物品获取逻辑）==========
if (isNil "fnc_intel_container_search_server") then {
    fnc_intel_container_search_server = {
        params ["_container", "_caller"];
        if (!isServer) exitWith {};
        if (isNull _container || isNull _caller) exitWith {};
        
        // 普通物品池
        private _normalIntelItems = [
            "Money_roll",
            "Files",
            "Wallet_ID",
            "SmartPhone",
            "MobilePhone",
            "FlashDisk"
        ];
        // 绝密物品池
        private _topSecretItems = ["FileTopSecret", "FilesSecret"];
        
        // 80% 概率获得物品
        if (random 1 < 0.8) then {
            private _itemsToGive = [];
            private _hasTopSecret = false;
            
            // 10% 概率获得一个绝密物品
            if (random 1 < 0.1) then {
                private _topSecretItem = selectRandom _topSecretItems;
                _itemsToGive pushBack _topSecretItem;
                _hasTopSecret = true;
            };
            
            // 普通物品数量 0-3
            private _normalCount = floor random 4;
            for "_i" from 1 to _normalCount do {
                _itemsToGive pushBack (selectRandom _normalIntelItems);
            };
            
            if (count _itemsToGive == 0) exitWith {
                [localize "STR_DUWS_T_CONTAINER_EMPTY"] remoteExec ["hint", _caller];
            };
            
            // 尝试添加到玩家背包
            private _addedToInventory = true;
            private _droppedItems = [];
            {
                private _class = _x;
                private _added = false;
                if (isClass (configFile >> "CfgWeapons" >> _class)) then {
                    if (count (items _caller) < 10) then {
                        _caller addItem _class;
                        _added = true;
                    };
                };
                if (!_added) then {
                    if (count (magazines _caller) < 20) then {
                        _caller addMagazineGlobal _class;
                        _added = true;
                    };
                };
                if (!_added) then {
                    _addedToInventory = false;
                    _droppedItems pushBack _class;
                };
            } forEach _itemsToGive;
            
            if (!_addedToInventory) then {
                private _pos = getPosATL _caller;
                private _holder = createVehicle ["GroundWeaponHolder", _pos, [], 0, "CAN_COLLIDE"];
                {
                    _holder addItemCargoGlobal [_x, 1];
                } forEach _droppedItems;
                [localize "STR_DUWS_T_ITEMS_DROPPED"] remoteExec ["hint", _caller];
            } else {
                [format [localize "STR_DUWS_T_ITEMS_FOUND", count _itemsToGive]] remoteExec ["hint", _caller];
            };
            
            if (_hasTopSecret) then {
                private _title = localize "STR_DUWS_T_TOPSECRET_TITLE";
                private _desc = format [localize "STR_DUWS_T_TOPSECRET_DESC", name _caller];
                ["info", [_title, _desc]] remoteExec ["BIS_fnc_showNotification", 0];
                [([localize "STR_DUWS_T_actionteam"] call fnc_cs), ([localize "STR_DUWS_T_INTEL_GATHERINGTS1"] call fnc_cs)] remoteExec ["BIS_fnc_showSubtitle", 0];
                [] remoteExec ["fnc_broadcastRadioChatter", 0];
                sleep 6;
                [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_INTEL_GATHERINGTS2"] remoteExec ["BIS_fnc_showSubtitle", 0];
                [] remoteExec ["fnc_broadcastRadioChatter", 0];
            };
        } else {
            [localize "STR_DUWS_T_CONTAINER_EMPTY"] remoteExec ["hint", _caller];
        };
    };
    publicVariable "fnc_intel_container_search_server";
};

// ========== 遍历每个建筑：放置士兵、生成容器 ==========
{
    private _building = _x;
    private _positions = [_building] call BIS_fnc_buildingPositions;
    private _posCount = count _positions;
    if (_posCount == 0) then { continue };

    // 创建建筑标记
    private _buildingPos = getPos _building;
    private _markerName = format ["intel_bldg_%1_%2", round(time), _forEachIndex];
    private _marker = createMarker [_markerName, _buildingPos];
    _marker setMarkerShape "ICON";
    _marker setMarkerType "o_unknown";
    _marker setMarkerColor "ColorRed";
    _marker setMarkerSize [0.5, 0.5];
    _buildingMarkers pushBack _markerName;
    
    // 放置士兵
    private _baseCount = 3;
    private _extraChance = (_posCount / 10) min 1;
    private _extra = floor (random 4);
    if (random 1 < _extraChance) then {
        _extra = _extra + floor (random 3);
    };
    private _unitCount = (_baseCount + _extra) min 6;
    if (_unitCount > _posCount) then { _unitCount = _posCount };
    
    private _unitTypes = [];
    for "_i" from 1 to _unitCount do {
        _unitTypes pushBack (selectRandom _possibleUnitTypes);
    };
    
    private _group = [_MissionPos, EAST, _unitTypes, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    _group deleteGroupWhenEmpty true;
    
    private _unitsArray = units _group;
    for "_i" from 0 to (_unitCount - 1) do {
        private _unit = _unitsArray select _i;
        private _randPosIndex = floor random _posCount;
        private _unitPos = _building buildingPos _randPosIndex;
        private _unitPositions = ["UP", "MIDDLE"];
        _unit setUnitPos (selectRandom _unitPositions);
        _unit setPosATL _unitPos;
        _unit setBehaviour "AWARE";
        _unit setCombatMode "RED";
        
        [_unit] call fnc_addRandomLoot;
        
        [_unit, _building, _positions] spawn {
            params ["_unit", "_building", "_positions"];
            sleep 2 + random 5;
            private _buildingPos = getPosATL _building;
            while {alive _unit} do {
                if (_unit distance _buildingPos > 15 && count _positions > 0) then {
                    private _returnPos = selectRandom _positions;
                    _unit doMove _returnPos;
                };
                if (count _positions > 0) then {
                    private _targetPosIndex = floor random (count _positions);
                    private _targetPos = _building buildingPos _targetPosIndex;
                    _unit doMove _targetPos;
                    private _timeout = time + 30;
                    waitUntil {
                        sleep 5;
                        (unitReady _unit) || 
                        (!alive _unit) || 
                        (_unit distance _targetPos < 2) || 
                        (time > _timeout)
                    };
                    sleep 5 + random 5;
                } else {
                    sleep 5 + random 5;
                };
            };
        };
        
        _allSpawnedUnits pushBack _unit;
    };
    
    // 生成随机容器（0-3个）
    private _containerCountProb = (_posCount / 10) min 1;
    private _containerCount = 0;
    private _rand = random 1;
    if (_rand < _containerCountProb * 0.33) then {
        _containerCount = 1;
    } else {
        if (_rand < _containerCountProb * 0.66) then {
            _containerCount = 2;
        } else {
            if (_rand < _containerCountProb) then {
                _containerCount = 3;
            };
        };
    };
    
    for "_c" from 1 to _containerCount do {
        private _containerClass = selectRandom _containerClasses;
        private _containerPosIndex = floor random _posCount;
        private _containerPos = _building buildingPos _containerPosIndex;
        private _container = createVehicle [_containerClass, _containerPos, [], 0, "CAN_COLLIDE"];
        _container setPosATL _containerPos;
        _container setDir random 360;
        _allSpawnedContainers pushBack _container;
        
        [_container] remoteExec ["fnc_intel_container_addAction", 0, true];
    };
    
} forEach _selectedBuildings;

// 在任务区域周围生成额外巡逻队
[_MissionPos, _radius] spawn fnc_missionPatrols;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_INTEL_GATHERING1"] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 6;
[localize "STR_DUWS_T_OVERLORD", ([localize "STR_DUWS_T_INTEL_GATHERING2"] call fnc_cs)] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];

// ========== 创建任务标记 ==========
private _randomPos = [_MissionPos, 0, _radius, 5, 0, 0.2, 0] call BIS_fnc_findSafePos;
if (_randomPos isEqualTo [0,0,0]) then { _randomPos = _MissionPos; };
private _markerData = [_randomPos, "Intel", localize "STR_DUWS_T_INTEL_GATHERING_TITLE", _radius] call fnc_missionMarkerData;
_markername = _markerData select 0;
_markername2 = _markerData select 1;

// ========== 创建任务 ==========
private _taskID = format ["intel_gathering_%1", round time];
[
    west,
    _taskID,
    [localize "STR_DUWS_T_INTEL_GATHERING_DESC", localize "STR_DUWS_T_INTEL_GATHERING_TITLE", "getMarkerPos str(_markername)"],
    objNull,
    true
] call BIS_fnc_taskCreate;

[([localize "STR_DUWS_T_actionteam"] call fnc_cs), ([localize "STR_DUWS_T_INTEL_GATHERING3"] call fnc_cs)] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 6;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_INTEL_GATHERING4"] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 6;
[([localize "STR_DUWS_T_actionteam"] call fnc_cs), localize "STR_DUWS_T_INTEL_GATHERING5"] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];

// ========== 统计初始敌军数量 ==========
sleep 5;
private _nearbyEnemies = _MissionPos nearEntities [["CAManBase", "LandVehicle", "Air"], _radius * 1.5] select { side _x == EAST };
private _initialEnemyCount = count _nearbyEnemies;
missionNamespace setVariable [_initialCountVar, _initialEnemyCount, true];
missionNamespace setVariable [_triggeredVar, false, true];
diag_log format ["[Reinforce] %1: Initial enemy count = %2", _mission_name, _initialEnemyCount];

// ========== 启动直升机增援监控 ==========
[_MissionPos, _radius, _initialCountVar, _triggeredVar, _taskID] spawn fnc_opf_heli_reinforce;
// ============================================

// ========== 15分钟后自动成功 ==========
[_taskID, _MissionPos, _radius, _markername, _markername2, _allSpawnedContainers, _buildingMarkers, _cpreward, _apreward, _mission_name] spawn {
    params ["_taskID", "_pos", "_rad", "_markerIcon", "_markerArea", "_containers", "_bldgMarkers", "_cpreward", "_apreward", "_mission_name"];

    sleep 900;

    [_taskID, "SUCCEEDED"] call BIS_fnc_taskSetState;

    deleteMarker _markerIcon;
    deleteMarker _markerArea;

    {
        deleteMarker _x;
    } forEach _bldgMarkers;

    [localize "STR_DUWS_T_allseer", localize "STR_DUWS_T_INTEL_GATHERING6"] remoteExec ["BIS_fnc_showSubtitle", 0];
    [] remoteExec ["fnc_broadcastRadioChatter", 0];

    [] spawn fnc_missionTimer;
    missionNamespace setVariable [_triggeredVar, true, true];
    [_pos, _rad] spawn fnc_mission_cleanup;

    [_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;

    sleep 360;

    {
        if (!isNull _x) then { deleteVehicle _x };
    } forEach _containers;

    Mission_available = true;
    publicVariable "Mission_available";
};

sleep 600;
["info",[localize "STR_DUWS_T_INTEL_GATHERING",localize "STR_DUWS_T_INTEL_GATHERING_TMLEFT"]] remoteExec ['BIS_fnc_showNotification',0];
sleep 300;
deleteMarker str(_markername2);
deleteMarker str(_markername);