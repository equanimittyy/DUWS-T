// Locality: server -- inherited from server/missions/dyna/fnc_dynamicAtmosphere_init.sqf.

params ["_nameKey"];

// 清理函数：重置全局活动标志
private _fnc_cleanup = {
    missionNamespace setVariable ["dyna_mission_active", false];
};

["INFO", "MISSION", format ["Mission started with key: %1", _nameKey]] call fnc_log;

// ---------- 1. 随机选择一名玩家 ----------
private _allPlayers = call BIS_fnc_listPlayers;
if (_allPlayers isEqualTo []) exitWith {
    ["ERROR", "MISSION", "No players, aborting."] call fnc_log;
    call _fnc_cleanup;
};
private _targetPlayer = selectRandom _allPlayers;
private _playerPos = getPos _targetPlayer;

// ---------- 2. 生成两发下落的迫击炮弹（间隔5秒） ----------
private _spawnShell = {
    params ["_pos", "_target"];
    private _shell = createVehicle ["Sh_82mm_AMOS", _pos, [], 0, "NONE"];
    _shell setPos _pos;
    _shell setVelocity [0, 0, -30]; // 快速下落
    // 可添加音效或提示
};

private _shellPos1 = _playerPos getPos [100 + random 20, random 360];
_shellPos1 set [2, 150]; // 空中高度
[_shellPos1] call _spawnShell;
sleep 5;
private _shellPos2 = _playerPos getPos [100 + random 20, random 360];
_shellPos2 set [2, 150];
[_shellPos2] call _spawnShell;

// ---------- 3. 寻找观察员位置（300-1200米范围内，优先建筑） ----------
private _spotterPos = [];
private _building = objNull;

// 获取该范围内的所有建筑（扩大建筑类型）
private _nearBuildings = nearestObjects [_playerPos, ["House","Building","Strategic","Ruins"], 1200];
_nearBuildings = _nearBuildings select { _x distance _playerPos >= 300 && _x distance _playerPos <= 1200 };

// 过滤掉太靠近HQ或战区的建筑，同时排除FOB附近
private _allZones = [];
{
    _allZones append (missionNamespace getVariable [_x, []]);
} forEach ["WARCOM_zones_controled_by_BLUFOR", "WARCOM_zones_controled_by_OPFOR"];
private _hqPos = missionNamespace getVariable ["PosOfBLUHQ", [0,0,0]];
private _fobPositions = [];
{
    if (!isNull _x) then { _fobPositions pushBack (getPos _x); };
} forEach (missionNamespace getVariable ["Array_of_FOBS", []]);

_nearBuildings = _nearBuildings select {
    private _bPos = getPos _x;
    // 距离HQ至少500米（原为200米，可调）
    (_bPos distance _hqPos >= 500) &&
    // 距离任何战区至少300米
    { { _bPos distance _x >= 300 } count _allZones == 0 } &&
    // 距离任何FOB至少300米
    { { _bPos distance _x >= 300 } count _fobPositions == 0 }
};

// 调试输出
["INFO", "MISSION", format ["Near buildings count: %1", count _nearBuildings]] call fnc_log;

// 如果有合适的建筑，随机选择一个并获取其位置
if (count _nearBuildings > 0) then {
    _building = selectRandom _nearBuildings;
    _spotterPos = getPos _building;
    // 尝试获取建筑内的位置
    private _buildingPositions = [_building] call BIS_fnc_buildingPositions;
    if (count _buildingPositions > 0) then {
        _spotterPos = selectRandom _buildingPositions;
    };
    ["INFO", "MISSION", format ["Selected building at %1", _spotterPos]] call fnc_log;
} else {
    // 无合适建筑：尝试在随机位置附近寻找最近建筑
    ["WARN", "MISSION", "No suitable building found, trying fallback."] call fnc_log;
    private _randomPos = [_playerPos, 300, 1200, 5, 0, 0.2, 0, [], [_playerPos, _playerPos]] call BIS_fnc_findSafePos;
    if (_randomPos isEqualTo [0,0,0]) then {
        _randomPos = _playerPos getPos [300 + random 700, random 360];
    };
    private _nearestBuilding = nearestBuilding _randomPos;
    if (!isNull _nearestBuilding) then {
        _building = _nearestBuilding;
        _spotterPos = getPos _building;
        private _buildingPositions = [_building] call BIS_fnc_buildingPositions;
        if (count _buildingPositions > 0) then {
            _spotterPos = selectRandom _buildingPositions;
        };
        ["WARN", "MISSION", format ["Fallback: found building at %1", _spotterPos]] call fnc_log;
    } else {
        // 实在没有建筑，使用随机位置
        _spotterPos = _randomPos;
        ["WARN", "MISSION", format ["Fallback: no building, using random pos %1", _spotterPos]] call fnc_log;
    };
};

// 如果找不到任何合适位置，退出任务
if (_spotterPos isEqualTo []) exitWith {
    ["ERROR", "MISSION", "No valid spotter position found, aborting."] call fnc_log;
    call _fnc_cleanup;
};

// ---------- 4. 生成观察员（opfor_MARK_SOLDIER_X） ----------
private _spotterGroup = [_spotterPos, EAST, [opfor_MARK_SOLDIER_X], [], [], [0.5,0.6]] call BIS_fnc_spawnGroup;
private _spotter = leader _spotterGroup;
_spotterGroup deleteGroupWhenEmpty true;

// 设置位置（如果之前找到的是建筑内部位置，已经设置好了，否则手动设置）
_spotter setPos _spotterPos;

// 设置行为：蹲姿、禁止移动、允许战斗
_spotter setUnitPos "MIDDLE"; // 蹲姿
_spotter disableAI "PATH";    // 禁止移动
_spotter setBehaviour "COMBAT";
_spotter setCombatMode "RED";
_spotter setSkill 0.7;
_spotter setDir (_spotter getDir _targetPlayer);
// 无敌10秒
_spotter allowDamage false;
[_spotter] spawn {
    params ["_unit"];
    sleep 10;
    _unit allowDamage true;
};
sleep 6;
[localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_mortarspotter3"] remoteExec ["fnc_duws_dialogue", 0];
sleep 4;
[localize "STR_DUWS_T_allseer", ([localize "STR_DUWS_T_mortarspotter4"] call fnc_cs)] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
// ---------- 5. 创建任务和标记 ----------
private _taskID = format ["dyna_mortar_%1", round time];
[_taskID, localize "STR_DUWS_T_mortarspotter2", localize _nameKey, _spotterPos, "kill"] call fnc_missionTaskCreate;

// 生成一个在观察员位置周围50米内的随机偏移点
private _offsetPos = [_spotterPos, 0, 50, 5, 0, 0.2, 0, [], [_spotterPos, _spotterPos]] call BIS_fnc_findSafePos;
if (_offsetPos isEqualTo [0,0,0]) then {
    // 如果找不到安全位置，使用随机方向距离
    _offsetPos = _spotterPos getPos [random 50, random 360];
    _offsetPos set [2, 0]; // 确保地面高度
};

// 创建标记（图标和椭圆区域都以偏移点为中心）
private _markerArea = [_offsetPos, 50] call fnc_missionMarkerData;

// ---------- 6. 启动周期性炮击（每30秒一发，直到观察员死亡） ----------
[_targetPlayer, _spotter] spawn {
    params ["_player", "_spotter"];
    while {alive _spotter} do {
        sleep 30;
        if (!alive _spotter) exitWith {};
        private _pos = getPos _player;
        private _shellPos = _pos getPos [100 + random 20, random 360];
        _shellPos set [2, 150];
        private _shell = createVehicle ["Sh_82mm_AMOS", _shellPos, [], 0, "NONE"];
        _shell setVelocity [0, 0, -30];
    };
};

// ---------- 7. 等待观察员死亡 ----------
waitUntil {
    sleep 2;
    !alive _spotter
};
sleep 4;
[localize "STR_DUWS_T_actionteam", ([localize "STR_DUWS_T_mortarspotter5"] call fnc_cs)] remoteExec ["fnc_duws_dialogue", 0];
sleep 4;
// ---------- 8. 任务成功，奖励 ----------
[_taskID, "SUCCEEDED"] call fnc_missionTaskEnd;
// 使用 fnc_mission_reward 发放奖励（CP 乘数自动应用，并触发特战队员技能提升）

private _missionName = localize _nameKey; // 获取本地化任务名称
[10, 5, _missionName] spawn fnc_mission_reward;

// str(): fnc_missionMarkerData creates the ellipse under str(name), so the real marker name
// carries literal quote characters and an unquoted deleteMarker silently misses it.
if (!isNil "_markerArea" && {_markerArea != ""}) then {
    deleteMarker str(_markerArea);
    ["INFO", "MISSION", format ["Deleted marker area: %1", _markerArea]] call fnc_log;
} else {
    ["ERROR", "MISSION", "_markerArea is nil or empty, cannot delete."] call fnc_log;
};

// 清除任务运行标志
call _fnc_cleanup;