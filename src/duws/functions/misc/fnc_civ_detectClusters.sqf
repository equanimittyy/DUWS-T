/*
    fnc_civ_detectClusters.sqf (DCWR优化版 - 随机采样 + 最大数量限制)
    功能: 通过随机网格采样和自适应半径快速检测地图上的平民聚落
    参数:
        _existingLocations: 已有城镇位置对象数组（用于排除）
        _minBuildings: 聚落最少建筑数，默认3
        _excludeMilitary: 是否排除军事区域，默认true
        _gridSize: 采样网格大小（米），默认800
        _maxRadius: 聚落最大搜索半径（米），默认100
        _stepRadius: 半径递增步长（米），默认50
        _maxClusters: 最大聚落数量，默认100
*/
if (!isServer) exitWith {[]};

params [
    ["_existingLocations", [], [[]]],
    ["_minBuildings", 3],
    ["_excludeMilitary", true],
    ["_gridSize", 800],
    ["_maxRadius", 100],
    ["_stepRadius", 50],
    ["_maxClusters", 100]
];

diag_log "===== fnc_civ_detectClusters (DCWR优化版 - 随机采样) 开始 =====";
private _startTime = diag_tickTime;
private _clusters = [];
["dc",[localize "STR_DUWS_T_dc1",localize "STR_DUWS_T_dc2"]] remoteExec ["bis_fnc_showNotification", 0];
try {
    // 获取地图尺寸（确保正确）
    private _worldSize = getNumber (configfile >> "CfgWorlds" >> worldName >> "mapSize");
    if (_worldSize == 0) then { _worldSize = 8192; };
    diag_log format ["[CIV] 地图尺寸: %1", _worldSize];

    // 使用 nearestTerrainObjects 全图扫描建筑（比 allMissionObjects 更可靠）
    private _center = [_worldSize/2, _worldSize/2, 0];
    private _allBuildings = nearestTerrainObjects [_center, ["House"], _worldSize * 1.5, true];
    diag_log format ["[CIV] 通过地形对象获取的建筑数: %1", count _allBuildings];

    // 筛选有建筑位置的建筑（可进入）
    _allBuildings = _allBuildings select { count ([_x] call BIS_fnc_buildingPositions) > 0 };
    diag_log format ["[CIV] 其中有建筑位置的建筑: %1", count _allBuildings];

    if (count _allBuildings == 0) exitWith {
        diag_log "[CIV] 错误：没有找到任何可进入建筑！";
    };

    private _buildingPositions = _allBuildings apply { getPos _x };

    // 获取城镇中心
    private _townCenters = _existingLocations apply { getPos _x };

    // 获取军事排除位置
    private _excludePositions = [];
    if (_excludeMilitary) then {
        waitUntil { sleep 0.1; !isNil "createzone_server" || time > time + 5 };
        if (!isNil "WARCOM_zones_controled_by_OPFOR") then { _excludePositions append WARCOM_zones_controled_by_OPFOR };
        if (!isNil "WARCOM_zones_controled_by_BLUFOR") then { _excludePositions append WARCOM_zones_controled_by_BLUFOR };
        if (!isNil "PosOfBLUHQ") then { _excludePositions pushBack PosOfBLUHQ };
        if (!isNil "Array_of_FOBS") then {
            { if (!isNull _x) then { _excludePositions pushBack (getPos _x) } } forEach Array_of_FOBS;
        };
        diag_log format ["[CIV] 军事排除点: %1", count _excludePositions];
    };

    // 生成候选点（网格采样）
    private _candidatePositions = [];
    for "_x" from 0 to _worldSize step _gridSize do {
        for "_y" from 0 to _worldSize step _gridSize do {
            private _pos = [_x, _y, 0];
            if (surfaceIsWater _pos) then { continue };
            // 初步排除离城镇太近的点（可选，加快速度）
            private _tooClose = false;
            {
                if (_pos distance _x < 200) exitWith { _tooClose = true };
            } forEach _townCenters;
            if (_tooClose) then { continue };
            _candidatePositions pushBack _pos;
        };
    };
    diag_log format ["[CIV] 候选点总数: %1", count _candidatePositions];

    // 随机打乱候选点顺序
    _candidatePositions = _candidatePositions call BIS_fnc_arrayShuffle;

    // 遍历候选点进行自适应半径检测
    {
        // 如果已达到最大聚落数量，提前结束
        if (count _clusters >= _maxClusters) exitWith {
            diag_log format ["[CIV] 已达到最大聚落数量 %1，停止搜索。", _maxClusters];
        };

        private _pos = _x;

        // 快速排除离军事区太近的点
        if (_excludeMilitary) then {
            private _tooClose = false;
            {
                if (_pos distance _x < _gridSize) exitWith { _tooClose = true };
            } forEach _excludePositions;
            if (_tooClose) then { continue };
        };

        private _bestCount = 0;
        private _bestRadius = 0;
        private _lastCount = -1;

        for "_r" from _stepRadius to _maxRadius step _stepRadius do {
            private _count = 0;
            {
                if (_x distance _pos <= _r) then { _count = _count + 1 };
            } forEach _buildingPositions;

            if (_count > _bestCount) then {
                _bestCount = _count;
                _bestRadius = _r;
            };
            if (_count == _lastCount) then { break };
            _lastCount = _count;
        };

        if (_bestCount >= _minBuildings) then {
            // 检查距城镇距离
            private _tooClose = false;
            { if (_pos distance _x < 200) exitWith { _tooClose = true } } forEach _townCenters;
            if (_tooClose) then { continue };

            // 检查距军事距离（精确）
            if (_excludeMilitary) then {
                {
                    if (_pos distance _x < 150) exitWith { _tooClose = true };
                } forEach _excludePositions;
                if (_tooClose) then { continue };
            };

            // 去重
            private _duplicate = false;
            {
                if (_pos distance (getPos _x) < _bestRadius * 0.8) exitWith { _duplicate = true };
            } forEach _clusters;
            if (_duplicate) then { continue };

            private _loc = createLocation ["NameVillage", _pos, 0, 0];
            _loc setText (format [localize "STR_DUWS_T_DYNAMIC_TOWN", count _clusters + 1]);
            _loc setVariable ["isDynamic", true];
            _loc setVariable ["buildingCount", _bestCount];
            _loc setVariable ["clusterRadius", _bestRadius];
            _clusters pushBack _loc;
            diag_log format ["[CIV] 聚落 %2: 中心 %1, %3 栋, 半径 %4", _pos, count _clusters, _bestCount, _bestRadius];
        };
    } forEach _candidatePositions;

} catch {
    diag_log format ["[CIV] 检测出错: %1", _exception];
};
["dcb",[localize "STR_DUWS_T_dc1",localize "STR_DUWS_T_dc3"]] remoteExec ["bis_fnc_showNotification", 0];
diag_log format ["===== 检测完成，共 %1 个聚落，耗时 %2 秒 =====", count _clusters, diag_tickTime - _startTime];
_clusters