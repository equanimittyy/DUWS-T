// Locality: server -- inherited from server/missions/dyna/fnc_dynamicAtmosphere_init.sqf.
/*
    fnc_dyna_mission_supply_recovery.sqf
    功能：回收补给箱任务
    流程：
        1. 随机选择一名玩家，在其周围1000-6600米寻找安全位置生成补给箱
        2. 生成巡逻队保护补给箱
        3. 补给箱被运至FOB或HQ附近即成功，被毁即失败
        4. 任务结束360秒后自动删除其他生成的单位（保留箱子）
    参数：
        _nameKey: 任务名称的本地化键（来自主循环）
*/

params ["_nameKey"];

// 清理函数：重置全局活动标志 + 删除任务生成的所有单位（除补给箱）
private _fnc_cleanup = {
    // 重置动态任务标志
    missionNamespace setVariable ["dyna_mission_active", false];
    
    // 删除除补给箱外的所有任务物体
    private _taskUnits = missionNamespace getVariable ["dyna_mission_objects", []];
    {
        if (!isNull _x && {_x != _box}) then {
            deleteVehicle _x;
        };
    } forEach _taskUnits;
    missionNamespace setVariable ["dyna_mission_objects", nil];
};

["INFO", "MISSION", format ["Mission started with key: %1", _nameKey]] call fnc_log;

// ---------- 随机选择一名玩家 ----------
private _allPlayers = call BIS_fnc_listPlayers;
if (_allPlayers isEqualTo []) exitWith {
    ["ERROR", "MISSION", "No players, aborting."] call fnc_log;
    call _fnc_cleanup;
};

private _targetPlayer = selectRandom _allPlayers;
private _playerPos = getPos _targetPlayer;

// ---------- 2. 寻找安全位置（距离玩家1000-6600米，远离战区、HQ和FOB）----------
private _foundPos = [];
private _attempts = 0;
private _maxAttempts = 50;

// 提前收集所有需要避开的区域
private _allZones = [];
{
    _allZones append (missionNamespace getVariable [_x, []]);
} forEach ["WARCOM_zones_controled_by_BLUFOR", "WARCOM_zones_controled_by_OPFOR"];

private _hqPos = missionNamespace getVariable ["PosOfBLUHQ", [0,0,0]];
private _fobPositions = [];
{
    if (!isNull _x) then { _fobPositions pushBack (getPos _x); };
} forEach (missionNamespace getVariable ["Array_of_FOBS", []]);

while {_attempts < _maxAttempts && _foundPos isEqualTo []} do {
    private _angle = random 360;
    private _dist = 1000 + random 5600; // 1000-6600米
    private _candidate = _playerPos getPos [_dist, _angle];
    private _safePos = [_candidate, 0, 50, 5, 0, 0.2, 0] call BIS_fnc_findSafePos;
    if (_safePos isEqualTo [0,0,0]) then { _safePos = _candidate; };

    // 检查是否远离所有战区（至少500米）
    private _tooClose = false;
    {
        if (_safePos distance _x < 500) exitWith { _tooClose = true; };
    } forEach _allZones;

    // 检查是否远离HQ（至少1000米）
    if (!_tooClose && {_safePos distance _hqPos > 1000}) then {
        // 检查是否远离所有FOB（至少500米）
        private _fobTooClose = false;
        {
            if (_safePos distance _x < 500) exitWith { _fobTooClose = true; };
        } forEach _fobPositions;
        if (!_fobTooClose) then {
            _foundPos = _safePos;
        };
    };
    _attempts = _attempts + 1;
};

if (_foundPos isEqualTo []) exitWith {
    ["INFO", "MISSION", "No safe position found."] call fnc_log;
    call _fnc_cleanup;
};

// ---------- 生成补给箱（无敌20秒）----------
_box = createVehicle ["Box_NATO_AmmoVeh_F", _foundPos, [], 0, "NONE"];
_box allowDamage false;
[_box] spawn {
    params ["_box"];
    sleep 20;
    _box allowDamage true;
};

// ---------- 记录所有将要生成的单位 ----------
private _generatedObjects = [];
// 将补给箱加入记录
_generatedObjects pushBack _box;

// ---------- 记录生成巡逻队前的敌单位 ----------
private _beforeUnits = [];
{
    if (side _x == EAST) then {
        _beforeUnits pushBack _x;
    };
} forEach (nearestObjects [_foundPos, ["CAManBase","LandVehicle","Air"], 300]);

// ---------- 生成巡逻队（半径200米）----------
[_foundPos, 200] spawn fnc_missionPatrols;

// 等待巡逻队生成完成（给AI一点时间生成）
sleep 2;

// 记录生成巡逻队后的敌单位，并计算新增的单位
private _afterUnits = [];
{
    if (side _x == EAST) then {
        _afterUnits pushBack _x;
    };
} forEach (nearestObjects [_foundPos, ["CAManBase","LandVehicle","Air"], 300]);

// 取差集得到本次任务新增的单位
private _newUnits = [];
{
    if (!(_x in _beforeUnits)) then {
        _newUnits pushBack _x;
    };
} forEach _afterUnits;

// 将新增单位加入记录列表
_generatedObjects append _newUnits;

// ---------- 创建地图标记 ----------
private _markerData = [_foundPos, "Supply Cache", localize _nameKey, 200] call fnc_missionMarkerData;
_markerData params ["_markerIcon", "_markerArea"];
[localize "STR_DUWS_T_OVERLORD", ([localize "STR_DUWS_T_supply_start"] call fnc_cs)] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 6;
[([localize "STR_DUWS_T_actionteam"] call fnc_cs), ([localize "STR_DUWS_T_supply_start2"] call fnc_cs)] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];

// ---------- 创建任务 ----------
private _taskID = format ["dyna_supplyrecover_%1", round time];
[
    west,
    _taskID,
    [localize "STR_DUWS_T_supply_recovery", localize _nameKey, _foundPos],
    objNull,
    true
] call BIS_fnc_taskCreate;

// ---------- 将生成的单位存储到全局变量（供清理函数使用）----------
missionNamespace setVariable ["dyna_mission_objects", _generatedObjects];

// ---------- 监控任务完成条件 ----------
waitUntil {
    sleep 2;
    if (!alive _box) exitWith { true }; // 箱子被毁
    private _near = false;
    // 检查箱子是否靠近任何FOB或HQ
    {
        if (_box distance _x < 50) exitWith { _near = true; };
    } forEach (([PosOfBLUHQ] + (Array_of_FOBS apply {getPos _x})));
    _near
};

// 判断结局
if (!alive _box) then {
    deleteMarker _markerIcon;
    deleteMarker _markerArea;
    deleteMarker str(_markerIcon);
    deleteMarker str(_markerArea);
    [([localize "STR_DUWS_T_actionteam"] call fnc_cs), ([localize "STR_DUWS_T_supply_fail"] call fnc_cs)] remoteExec ["BIS_fnc_showSubtitle", 0];
    [] remoteExec ["fnc_broadcastRadioChatter", 0];
    sleep 5;
    [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_supply_fail2"] remoteExec ["BIS_fnc_showSubtitle", 0];
    [] remoteExec ["fnc_broadcastRadioChatter", 0];
    sleep 4;
    // 任务失败
    [_taskID, "FAILED"] call BIS_fnc_taskSetState;

    // 清理：移除除箱子以外的所有任务物体，重置标志
    missionNamespace setVariable ["dyna_mission_active", false];
    {
        if (!isNull _x && {_x != _box}) then { deleteVehicle _x; };
    } forEach (missionNamespace getVariable ["dyna_mission_objects", []]);
    missionNamespace setVariable ["dyna_mission_objects", nil];

} else {
    deleteMarker _markerIcon;
    deleteMarker _markerArea;
    deleteMarker str(_markerIcon);
    deleteMarker str(_markerArea);
    
    private _missionName = localize _nameKey;
    [15, 15, _missionName] spawn fnc_mission_reward;
    
    [([localize "STR_DUWS_T_actionteam"] call fnc_cs), ([localize "STR_DUWS_T_supply_success"] call fnc_cs)] remoteExec ["BIS_fnc_showSubtitle", 0];
    [] remoteExec ["fnc_broadcastRadioChatter", 0];
    sleep 5;
    // 任务成功
    [_taskID, "SUCCEEDED"] call BIS_fnc_taskSetState;

    // 清理：移除除箱子以外的所有任务物体，重置标志
    missionNamespace setVariable ["dyna_mission_active", false];
    {
        if (!isNull _x && {_x != _box}) then { deleteVehicle _x; };
    } forEach (missionNamespace getVariable ["dyna_mission_objects", []]);
    missionNamespace setVariable ["dyna_mission_objects", nil];
};

// ---------- 延迟 360 秒后执行清理（保留补给箱）----------
[_generatedObjects] spawn {
    params ["_objects"];
    private _box = _objects select 0;
    sleep 360;
    {
        if (!isNull _x && {_x != _box}) then {
            deleteVehicle _x;
        };
    } forEach _objects;
};