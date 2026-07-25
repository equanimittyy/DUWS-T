/*
    fnc_civ_handler.sqf
    整合平民生成与清理功能
    参数: [_locIndex, _mode]
    _mode: "spawn" 或 "cleanup"
    执行端: 服务器
    修复：恢复全局互斥锁，生成前二次验证玩家位置，解决排队失效问题
*/
if (!isServer) exitWith {};

params ["_locIndex", "_mode"];

// ========== 全局互斥锁初始化 ==========
if (isNil "civ_current_active_location") then {
    civ_current_active_location = -1;
    publicVariable "civ_current_active_location";
};

// ========== 获取城镇数据 ==========
private _locations = missionNamespace getVariable ["civ_locations", []];
private _radii = missionNamespace getVariable ["civ_radii", []];
if (_locIndex >= count _locations) exitWith {
    diag_log format ["[CIV] Invalid location index %1", _locIndex];
};
private _location = _locations select _locIndex;
private _centerPos = getPos _location;
private _triggerRadius = _radii param [_locIndex, 500];
if (_centerPos isEqualTo [0,0,0]) exitWith {
    diag_log format ["[CIV] Location %1 has zero position", _locIndex];
};
private _locationName = if (text _location != "") then { text _location } else { format ["Unnamed%1", _locIndex] };

// ============================================
// 清理模式（延迟 60 秒）
// ============================================
if (_mode == "cleanup") exitWith {
    diag_log format ["[CIV] [Cleanup] Requested for location %1, will execute in 60 seconds", _locIndex];
    private _currentPop = missionNamespace getVariable [format ["civ_pop_%1", _locIndex], 0];
    if (_currentPop > 1) then {
        private _message = format [localize "STR_DUWS_T_CIV_CLEANUP_WARNING", _locationName];
        [_message] remoteExec ["hint", 0];
    };
    private _pendingVar = format ["civ_pending_cleanup_%1", _locIndex];
    missionNamespace setVariable [_pendingVar, true];

    private _threadVar = format ["civ_monitor_%1", _locIndex];
    missionNamespace setVariable [_threadVar, false];
    diag_log format ["[CIV] Cleanup stopped monitor for %1", _locIndex];

    sleep 60;

    if (!(missionNamespace getVariable [_pendingVar, false])) exitWith {
        diag_log format ["[CIV] [Cleanup] Pending cleanup cancelled for %1", _locIndex];
    };

    private _playersInArea = allPlayers select { _x distance _centerPos < _triggerRadius };
    if (count _playersInArea > 0) exitWith {
        diag_log format ["[CIV] [Cleanup] Cleanup aborted for %1 because players are still in area", _locIndex];
        missionNamespace setVariable [_pendingVar, false];
    };

    diag_log format ["[CIV] [Cleanup] Executing cleanup for location %1", _locIndex];

    private _spawnedKey = format ["civ_spawned_%1", _locIndex];
    if (!(missionNamespace getVariable [_spawnedKey, false])) exitWith {
        diag_log format ["[CIV] [Cleanup] Location %1 not spawned, ignoring", _locIndex];
        missionNamespace setVariable [_pendingVar, false];
        // 即使未生成也释放锁
        if (civ_current_active_location == _locIndex) then {
            civ_current_active_location = -1;
            publicVariable "civ_current_active_location";
        };
    };

    // 删除所有属于该城镇的单位
    private _allUnits = allUnits;
    private _deletedUnits = 0;
    {
        private _locIdx = _x getVariable ["civ_locIndex", -1];
        if (_locIdx == _locIndex) then {
            if (side _x == WEST && !(_x getVariable ["isHostile", false])) then {
                _x setVariable ["civ_locIndex", nil];
            } else {
                deleteVehicle _x;
                _deletedUnits = _deletedUnits + 1;
            };
        };
    } forEach _allUnits;
    diag_log format ["[CIV] [Cleanup] Deleted %1 units via allUnits scan", _deletedUnits];

    private _groups = missionNamespace getVariable [format ["civ_groups_%1", _locIndex], []];
    private _deletedGroups = 0;
    {
        if (!isNull _x) then {
            { deleteVehicle _x } forEach units _x;
            deleteGroup _x;
            _deletedGroups = _deletedGroups + 1;
        };
    } forEach _groups;
    diag_log format ["[CIV] [Cleanup] Deleted %1 groups from civ_groups list", _deletedGroups];
    missionNamespace setVariable [format ["civ_groups_%1", _locIndex], nil];

    private _allDead = allDeadMen;
    private _deletedCorpses = 0;
    {
        private _locIdx = _x getVariable ["civ_locIndex", -1];
        if (_locIdx == _locIndex) then {
            deleteVehicle _x;
            _deletedCorpses = _deletedCorpses + 1;
        };
    } forEach _allDead;
    diag_log format ["[CIV] [Cleanup] Deleted %1 corpses", _deletedCorpses];

    missionNamespace setVariable [_spawnedKey, false];
    missionNamespace setVariable [_pendingVar, false];

    private _iconName = format ["civ_icon_%1", _locIndex];
    private _currentPop = missionNamespace getVariable [format ["civ_pop_%1", _locIndex], 0];
    diag_log format ["[CIV] [Cleanup] Current population: %1", _currentPop];

    if (_currentPop <= 1) then {
        private _townName = text _location;
        private _title = localize "STR_DUWS_T_TOWN_DEPOPULATED_TITLE";
        private _desc = format [localize "STR_DUWS_T_TOWN_DEPOPULATED_DESC", _townName];
        ["biohazard", [_title, _desc]] remoteExec ["BIS_fnc_showNotification", 0];
        private _areaMarker = format ["civ_area_%1", _locIndex];
        _areaMarker setMarkerColor "ColorBlack";
        _areaMarker setMarkerAlpha 0.3;
        _iconName setMarkerText "X";
        if (_currentPop == 1) then {
            missionNamespace setVariable [format ["civ_pop_%1", _locIndex], 0];
        };
        if (scorched_earth_enabled) then {
            [15] remoteExec ["fnc_cp_adjust", 2];
            private _bluApPenalty = - (3 + floor random 3);
            ["BLU", _bluApPenalty] remoteExec ["fnc_ap_adjust", 2];
            private _repPenalty = - (3 + floor random 3);
            [_repPenalty] remoteExec ["fnc_rep_adjust", 2];
            private _opfApPenalty = - (3 + floor random 3);
            ["OPF", _opfApPenalty] remoteExec ["fnc_ap_adjust", 2];
            private _msg = format [localize "STR_DUWS_T_scorched_earth_effect2", _repPenalty, _bluApPenalty, _opfApPenalty];
            ["SE", [localize "STR_DUWS_T_scorched_earth_effect1", _msg]] remoteExec ["BIS_fnc_showNotification", 0];
        };
    } else {
        _iconName setMarkerText format ["%1", _currentPop];
    };

    // 释放互斥锁
    if (civ_current_active_location == _locIndex) then {
        civ_current_active_location = -1;
        publicVariable "civ_current_active_location";
        diag_log format ["[CIV] [Cleanup] Lock released for location %1", _locIndex];
    };

    diag_log format ["[CIV] [Cleanup] Finished for location %1, final pop: %2", _locIndex, _currentPop];
};

// ============================================
// 生成模式
// ============================================
if (_mode == "spawn") then {
    diag_log format ["[CIV] [Spawn] Function called for location %1", _locIndex];

    // 互斥等待：只有锁空闲或本城镇已持锁才能继续
    private _timeout = diag_tickTime + 600; // 10分钟超时
    waitUntil {
        sleep 2;
        (civ_current_active_location == -1 || civ_current_active_location == _locIndex) || diag_tickTime > _timeout
    };
    if (diag_tickTime > _timeout) then {
        diag_log format ["[CIV] [Spawn] Location %1 wait timeout, forcing spawn.", _locIndex];
    };

    // 原子性获取锁：只有锁空闲时才设置为当前索引
    if (civ_current_active_location == -1) then {
        civ_current_active_location = _locIndex;
        publicVariable "civ_current_active_location";
        diag_log format ["[CIV] [Spawn] Lock acquired for location %1", _locIndex];
    } else {
        if (civ_current_active_location == _locIndex) then {
            diag_log format ["[CIV] [Spawn] Location %1 already holds lock, continuing.", _locIndex];
        } else {
            // 理论上不会走到这里，但如果超时后锁仍被占用，则强制抢占
            civ_current_active_location = _locIndex;
            publicVariable "civ_current_active_location";
            diag_log format ["[CIV] [Spawn] Location %1 force-acquired lock after timeout.", _locIndex];
        };
    };

    // 二次验证：玩家是否仍在区域内？
    private _playersNow = allPlayers select { _x distance _centerPos < _triggerRadius };
    if (count _playersNow == 0) exitWith {
        diag_log format ["[CIV] [Spawn] No players in location %1 after acquiring lock, aborting.", _locIndex];
        if (civ_current_active_location == _locIndex) then {
            civ_current_active_location = -1;
            publicVariable "civ_current_active_location";
        };
    };

    // 取消待处理清理
    private _pendingVar = format ["civ_pending_cleanup_%1", _locIndex];
    if (missionNamespace getVariable [_pendingVar, false]) then {
        missionNamespace setVariable [_pendingVar, false];
        diag_log format ["[CIV] [Spawn] Cancelled pending cleanup for %1 due to player re-entry", _locIndex];
    };

    // 等待生成启用时间
    if (isNil "civ_spawn_enabled_time") then {
        waitUntil { !isNil "civ_spawn_enabled_time" };
    };
    private _enableTime = missionNamespace getVariable ["civ_spawn_enabled_time", 0];
    if (_enableTime > time) then {
        private _wait = _enableTime - time;
        diag_log format ["[CIV] Delaying spawn for location %1 for %2 seconds", _locIndex, _wait];
        sleep _wait;
    };

    // 防重
    private _spawningKey = format ["civ_spawning_%1", _locIndex];
    private _spawnedKey = format ["civ_spawned_%1", _locIndex];

    if (missionNamespace getVariable [_spawningKey, false]) exitWith {
        diag_log format ["[CIV] [Spawn] Location %1 is already spawning, skipping duplicate request", _locIndex];
        if (civ_current_active_location == _locIndex) then {
            civ_current_active_location = -1;
            publicVariable "civ_current_active_location";
        };
    };
    missionNamespace setVariable [_spawningKey, true];

    if (missionNamespace getVariable [_spawnedKey, false]) exitWith {
        diag_log format ["[CIV] [Spawn] Location %1 already spawned, skipping", _locIndex];
        missionNamespace setVariable [_spawningKey, false];
        if (civ_current_active_location == _locIndex) then {
            civ_current_active_location = -1;
            publicVariable "civ_current_active_location";
        };
    };
    missionNamespace setVariable [_spawnedKey, true];

    // 读取人口
    private _targetPop = missionNamespace getVariable [format ["civ_pop_%1", _locIndex], 0];
    if (_targetPop <= 0) exitWith {
        diag_log format ["[CIV] [Spawn] Target population for location %1 is %2, skipping spawn", _locIndex, _targetPop];
        missionNamespace setVariable [_spawnedKey, false];
        missionNamespace setVariable [_spawningKey, false];
        if (civ_current_active_location == _locIndex) then {
            civ_current_active_location = -1;
            publicVariable "civ_current_active_location";
        };
    };

    private _maxSpawnPerVisit = missionNamespace getVariable ["civ_maxSpawnPerVisit", 50];
    private _spawnCount = _targetPop min _maxSpawnPerVisit;
    private _remaining = _targetPop - _spawnCount;
    missionNamespace setVariable [format ["civ_remaining_%1", _locIndex], _remaining];
    diag_log format ["[CIV] [Spawn] Location %1: total pop %2, spawning %3, remaining %4", _locIndex, _targetPop, _spawnCount, _remaining];

    private _usableBuildings = [_centerPos, 2, _triggerRadius] call fnc_usableBuildings;
    diag_log format ["[CIV] [Spawn] Usable buildings count: %1", count _usableBuildings];

    private _civArray = missionNamespace getVariable ["civ_array", []];
    if (_civArray isEqualTo []) exitWith {
        diag_log "[CIV] [Spawn] civ_array is empty!";
        missionNamespace setVariable [_spawnedKey, false];
        missionNamespace setVariable [_spawningKey, false];
        if (civ_current_active_location == _locIndex) then {
            civ_current_active_location = -1;
            publicVariable "civ_current_active_location";
        };
    };

    waitUntil { sleep 1; !isNil "blufor_helmets" && !isNil "opfor_helmets" };
    duws_blufor_helmets = +blufor_helmets;
    duws_opfor_helmets = +opfor_helmets;
    duws_blufor_vests = +blufor_vests;
    duws_opfor_vests = +opfor_vests;
    duws_blufor_uniforms = +blufor_uniforms;
    duws_opfor_uniforms = +opfor_uniforms;

    fnc_applyEquipment = {
        params ["_unit", "_isZombie", "_unitType", "_unitIndex"];
        if (CIV_PRESENCE != "RAVAGE") exitWith {};
        if (_isZombie) then {
            { _unit setSkill [_x, 1.0]; } forEach ["aimingAccuracy", "aimingShake", "aimingSpeed", "spotDistance", "spotTime", "courage", "reloadSpeed", "commanding", "general"];
        };
        private _uniformSide = nil;
        if (_isZombie && random 1 < 0.7) then {
            private _uniformList = if (random 1 < 0.7) then { duws_blufor_uniforms } else { duws_opfor_uniforms };
            if (count _uniformList > 0) then {
                private _uniform = selectRandom _uniformList;
                _unit forceAddUniform _uniform;
                _uniformSide = if (_uniformList isEqualTo duws_blufor_uniforms) then { "BLU" } else { "OPF" };
            };
        };
        if (random 1 < 0.5) then {
            private _helmet = "";
            if (!isNil "_uniformSide") then {
                private _helmetList = if (_uniformSide == "BLU") then { duws_blufor_helmets } else { duws_opfor_helmets };
                if (count _helmetList > 0) then { _helmet = selectRandom _helmetList; };
            } else {
                if (count duws_all_helmets > 0) then { _helmet = selectRandom duws_all_helmets; };
            };
            if (_helmet != "") then { _unit addHeadgear _helmet; };
        };
        if (random 1 < 0.7) then {
            private _vest = "";
            if (!isNil "_uniformSide") then {
                private _vestList = if (_uniformSide == "BLU") then { duws_blufor_vests } else { duws_opfor_vests };
                if (count _vestList > 0) then { _vest = selectRandom _vestList; };
            } else {
                if (count duws_all_vests > 0) then { _vest = selectRandom duws_all_vests; };
            };
            if (_vest != "") then { _unit addVest _vest; };
        };
    };

    private _outerProbability = if (CIV_PRESENCE == "RAVAGE") then { 1.0 } else { 0.6 };
    private _maxOutdoorDist = _triggerRadius * 0.8;
    private _outdoorRange = 100 min _maxOutdoorDist;

    private _recruitableTypes = if (CIV_PRESENCE == "RAVAGE") then {
        ["C_man_p_beggar_F","C_Man_casual_1_F","C_Man_casual_3_F","C_Man_casual_8_F","C_Man_casual_6_v2_F","C_Man_casual_2_F","C_Man_UtilityWorker_01_F","C_Man_Fisherman_01_F","C_Man_casual_2_F","C_Man_p_shorts_1_F","C_Man_w_worker_F"]
    } else { [] };
    private _zombieTypes = [];
    if (CIV_PRESENCE == "RAVAGE") then {
        _zombieTypes = _civArray select { !(_x in _recruitableTypes) };
        if (_zombieTypes isEqualTo []) then { _zombieTypes = _civArray; };
    };

    private _groups = [];
    private _civToSpawn = 0;
    if (CIV_PRESENCE == "RAVAGE") then {
        _civToSpawn = round (_spawnCount * 0.2);
        if (_civToSpawn < 1 && _spawnCount > 0) then { _civToSpawn = 1; };
    };

    private _killedHandler = {
        params ["_dead", "_killer", "_instigator"];
        private _idx = _dead getVariable ["civ_locIndex", -1];
        if (_idx == -1) exitWith {};
        private _popVar = format ["civ_pop_%1", _idx];
        private _curPop = missionNamespace getVariable [_popVar, 0];
        if (_curPop > 0) then {
            missionNamespace setVariable [_popVar, _curPop - 1];
            private _iconName = format ["civ_icon_%1", _idx];
            _iconName setMarkerText format ["%1", _curPop - 1];
        };
        private _isHostile = _dead getVariable ["isHostile", false];
        if (CIV_PRESENCE != "RAVAGE" && !_isHostile && side _dead != resistance) then {
            [_dead, _killer, _instigator] call fnc_civ_rep_Tomata;
        };
        private _remVar = format ["civ_remaining_%1", _idx];
        private _remaining = missionNamespace getVariable [_remVar, 0];
        if (_remaining > 0) then {
            private _locData = missionNamespace getVariable ["civ_locations", []];
            private _radData = missionNamespace getVariable ["civ_radii", []];
            if (_idx < count _locData && _idx < count _radData) then {
                private _center = getPos (_locData select _idx);
                private _radius = _radData param [_idx, 500];
                private _civArr = missionNamespace getVariable ["civ_array", []];
                if (_civArr isEqualTo []) exitWith {};
                private _players = allPlayers select { alive _x && {_x distance _center < _radius} };
                private _foundPos = [];
                private _attempts = 0;
                while {_attempts < 10 && _foundPos isEqualTo []} do {
                    private _angle = random 360;
                    private _dist = random _radius;
                    private _candidate = _center getPos [_dist, _angle];
                    private _tooClose = false;
                    { if (_candidate distance _x < 80) exitWith { _tooClose = true }; } forEach _players;
                    if (!_tooClose) then { _foundPos = _candidate; };
                    _attempts = _attempts + 1;
                };
                if (_foundPos isEqualTo []) then {
                    private _angle = random 360;
                    private _dist = random _radius;
                    _foundPos = _center getPos [_dist, _angle];
                };
                private _spawnHostile = false;
                if (CIV_PRESENCE != "RAVAGE" && Player_Reputation < 0) then {
                    _spawnHostile = (random 1 < 0.3);
                };
                private _unitType = "";
                private _newGroup = grpNull;
                private _newUnit = objNull;
                if (_spawnHostile) then {
                    private _weaponPool = [["hgun_PDW2000_F","30Rnd_9x21_Mag"],["arifle_AKS_F","30Rnd_545x39_Mag_F"],["SMG_05_F","30Rnd_9x21_Mag_SMG_02"],["sgun_HunterShotgun_01_F","2Rnd_12Gauge_Pellets"],["sgun_HunterShotgun_01_sawedoff_F","2Rnd_12Gauge_Pellets"],["srifle_DMR_06_hunter_F","10Rnd_762x51_Mag"],["hgun_P07_F","16Rnd_9x21_Mag"],["hgun_Pistol_01_F","10Rnd_9x21_Mag"]];
                    _unitType = selectRandom _civArr;
                    _newGroup = [_foundPos, resistance, [_unitType]] call BIS_fnc_spawnGroup;
                    _newUnit = leader _newGroup;
                    private _weaponEntry = selectRandom _weaponPool;
                    private _weapon = _weaponEntry select 0;
                    private _magazine = _weaponEntry select 1;
                    for "_i" from 1 to 3 do { _newUnit addMagazineGlobal _magazine; };
                    _newUnit addWeapon _weapon;
                    _newUnit setBehaviour "COMBAT";
                    _newUnit setCombatMode "RED";
                    removeAllActions _newUnit;
                    [_newUnit] remoteExec ["removeAllActions", 0];
                    _newUnit setVariable ["isHostile", true, true];
                    if (count _players > 0) then {
                        private _nearestPlayer = [_players, _newUnit] call BIS_fnc_nearestPosition;
                        _newUnit reveal [_nearestPlayer, 4];
                        _newUnit doWatch _nearestPlayer;
                        _newUnit doTarget _nearestPlayer;
                        _newUnit commandFire _nearestPlayer;
                        private _wp = _newGroup addWaypoint [getPos _nearestPlayer, 0];
                        _wp setWaypointType "SAD";
                        _wp setWaypointSpeed "NORMAL";
                    };
                } else {
                    _unitType = selectRandom _civArr;
                    _newGroup = createGroup [CIVILIAN, true];
                    _newUnit = _newGroup createUnit [_unitType, _foundPos, [], 0, "NONE"];
                };
                _newUnit setVariable ["civ_locIndex", _idx];
                [_newUnit] call fnc_addCivilianMoney;
                _newUnit addEventHandler ["Killed", missionNamespace getVariable "CIV_KILLED_HANDLER"];
                if (_idx < count _locData && _idx < count _radData) then {
                    private _centerPos = getPos (_locData select _idx);
                    private _radius = _radData select _idx;
                    private _randomPos = [_centerPos, 0, _radius, 3, 0, 0.2, 0] call BIS_fnc_findSafePos;
                    if (_randomPos isEqualTo [0,0,0]) then { _randomPos = _centerPos; };
                    while {count (waypoints _newGroup) > 0} do { deleteWaypoint ((waypoints _newGroup) select 0); };
                    private _wp = _newGroup addWaypoint [_randomPos, 10];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointSpeed "NORMAL";
                    _wp setWaypointBehaviour "AWARE";
                    _wp setWaypointTimeout [30, 60, 90];
                    private _wp2 = _newGroup addWaypoint [_centerPos, 20];
                    _wp2 setWaypointType "CYCLE";
                    _wp2 setWaypointSpeed "NORMAL";
                    _wp2 setWaypointBehaviour "AWARE";
                };
                if (!_spawnHostile && CIV_PRESENCE != "RAVAGE") then {
                    [_newUnit] remoteExec ["fnc_addAskEnemyAction", 0, true];
                    [_newUnit] remoteExec ["fnc_civ_healAction", 0, true];
                    [_newUnit] remoteExec ["fnc_civ_stopCommand", 0, true];
                    [_newUnit] remoteExec ["fnc_civ_recruitAction", 0, true];
                    [_newUnit] remoteExec ["fnc_civ_lootAction", 0, true];
                    [_newUnit] remoteExec ["fnc_civ_addDevelopInformantAction", 0, true];
                    [_newUnit] remoteExec ["fnc_civ_fast_travel_add_action", 0, true];
                    [_newUnit] remoteExec ["fnc_civ_askForAid", 0, true];
                    [_newUnit] remoteExec ["fnc_civ_askForToolkit", 0, true];
                };
                missionNamespace setVariable [_remVar, _remaining - 1];
            };
        };
    };
    missionNamespace setVariable ["CIV_KILLED_HANDLER", _killedHandler];

    for "_i" from 1 to _spawnCount do {
        private _building = selectRandom _usableBuildings;
        private _pos = [0,0,0];
        if (isNull _building) then {
            _pos = [_centerPos, 10, _maxOutdoorDist, 3, 0, 0.5, 0] call BIS_fnc_findSafePos;
            if (_pos isEqualTo [0,0,0]) then { _pos = _centerPos; };
        } else {
            if (random 1 < _outerProbability) then {
                _pos = [_building, 5, _outdoorRange, 3, 0, 0.3, 0] call BIS_fnc_findSafePos;
                if (_pos isEqualTo [0,0,0]) then { _pos = getPos _building; };
            } else {
                private _positions = [_building] call BIS_fnc_buildingPositions;
                if (count _positions > 0) then {
                    private _randPos = floor random count _positions;
                    _pos = _building buildingPos _randPos;
                } else {
                    _pos = [_building, 5, _outdoorRange, 3, 0, 0.3, 0] call BIS_fnc_findSafePos;
                    if (_pos isEqualTo [0,0,0]) then { _pos = getPos _building; };
                };
            };
        };

        private _unitType = "";
        private _isZombie = false;
        if (CIV_PRESENCE == "RAVAGE") then {
            if (_i <= _civToSpawn) then {
                _unitType = selectRandom _recruitableTypes;
                _isZombie = false;
            } else {
                _unitType = selectRandom _zombieTypes;
                _isZombie = true;
            };
        } else {
            _unitType = selectRandom _civArray;
            _isZombie = false;
        };

        private _group = createGroup [CIVILIAN, true];
        private _unit = _group createUnit [_unitType, _pos, [], 0, "NONE"];
        _unit setVariable ["civ_locIndex", _locIndex];
        [_unit] call fnc_addCivilianMoney;
        [_unit, _isZombie, _unitType, _i] call fnc_applyEquipment;
        _unit addEventHandler ["Killed", missionNamespace getVariable "CIV_KILLED_HANDLER"];

        if (CIV_PRESENCE == "RAVAGE" && !_isZombie) then {
            [_unit] remoteExec ["fnc_addRecruitAction", 0, true];
        };
        if (CIV_PRESENCE == "RAVAGE" && _isZombie) then {
            [_unit, 2.2] remoteExec ["setAnimSpeedCoef", 0, true];
        };
        if (CIV_PRESENCE != "RAVAGE" && side _unit == CIVILIAN) then {
            [_unit] remoteExec ["fnc_addAskEnemyAction", 0, true];
            [_unit] remoteExec ["fnc_civ_healAction", 0, true];
            [_unit] remoteExec ["fnc_civ_stopCommand", 0, true];
            [_unit] remoteExec ["fnc_civ_recruitAction", 0, true];
            [_unit] remoteExec ["fnc_civ_lootAction", 0, true];
            [_unit] remoteExec ["fnc_civ_addDevelopInformantAction", 0, true];
            [_unit] remoteExec ["fnc_civ_fast_travel_add_action", 0, true];
            [_unit] remoteExec ["fnc_civ_askForAid", 0, true];
            [_unit] remoteExec ["fnc_civ_askForToolkit", 0, true];
        };
        _groups pushBack _group;
        sleep 0.2;
    };

    if (CIV_PRESENCE == "RAVAGE") then {
        [localize "STR_DUWS_T_OVERLORD", ([localize "STR_DUWS_T_civpopR"] call fnc_cs)] remoteExec ["BIS_fnc_showSubtitle", 0];
        sleep 2;
        ["biohazard", [localize "STR_DUWS_T_civrescuetitle", localize "STR_DUWS_T_civrescue"]] remoteExec ["BIS_fnc_showNotification", 0];
    } else {
        private _townName = text _location;
        private _enterMsg = format [localize "STR_DUWS_T_townenter", _townName];
        [localize "STR_DUWS_T_OVERLORD", ([localize "STR_DUWS_T_civpop"] call fnc_cs)] remoteExec ["BIS_fnc_showSubtitle", 0];
        ["info", [_enterMsg, localize "STR_DUWS_T_towninteract"]] remoteExec ["BIS_fnc_showNotification", 0];
    };
    [] remoteExec ["fnc_broadcastRadioChatter", 0];

    [_groups, _usableBuildings] spawn fnc_civ_wp_Tomata;

    if (CIV_PRESENCE != "RAVAGE" && Player_Reputation < 0 && _spawnCount > 1) then {
        private _totalGroups = count _groups;
        private _hostileCount = (abs Player_Reputation * 3) min _totalGroups;
        private _maxHostile = floor (0.7 * _totalGroups);
        _hostileCount = _hostileCount min _maxHostile;
        private _weaponPool = [["hgun_PDW2000_F","30Rnd_9x21_Mag"],["arifle_AKS_F","30Rnd_545x39_Mag_F"],["SMG_05_F","30Rnd_9x21_Mag_SMG_02"],["sgun_HunterShotgun_01_F","2Rnd_12Gauge_Pellets"],["sgun_HunterShotgun_01_sawedoff_F","2Rnd_12Gauge_Pellets"],["srifle_DMR_06_hunter_F","10Rnd_762x51_Mag"],["hgun_P07_F","16Rnd_9x21_Mag"],["hgun_Pistol_01_F","10Rnd_9x21_Mag"]];
        for "_i" from 0 to (_hostileCount - 1) do {
            private _group = _groups select _i;
            if (!isNull _group) then {
                {
                    removeAllActions _x;
                    [_x] remoteExec ["removeAllActions", 0];
                    private _weaponEntry = selectRandom _weaponPool;
                    private _weapon = _weaponEntry select 0;
                    private _magazine = _weaponEntry select 1;
                    _x addMagazineGlobal _magazine;
                    _x addMagazineGlobal _magazine;
                    _x addMagazineGlobal _magazine;
                    _x addWeapon _weapon;
                    _x setVariable ["isHostile", true, true];
                    _x removeAllEventHandlers "Killed";
                    _x addEventHandler ["Killed", missionNamespace getVariable "CIV_KILLED_HANDLER"];
                } forEach units _group;
                private _newGroup = createGroup resistance;
                (units _group) joinSilent _newGroup;
                deleteGroup _group;
                _groups set [_i, _newGroup];
            };
        };
        [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_hoscivpop"] remoteExec ["BIS_fnc_showSubtitle", 0];
        [] remoteExec ["fnc_broadcastRadioChatter", 0];
    };

    if (CIV_PRESENCE != "RAVAGE" && Player_Reputation < 0 && _spawnCount > 0) then {
        private _eastUnits = [];
        { if (side _x == resistance && _x getVariable ["civ_locIndex", -1] == _locIndex) then { _eastUnits pushBack _x }; } forEach allUnits;
        private _suicideCount = ceil (count _eastUnits * 0.1);
        if (_suicideCount > 0) then {
            private _civUnits = [];
            { if (side _x == CIVILIAN && !(_x getVariable ["isSuicideBomber", false]) && _x getVariable ["civ_locIndex", -1] == _locIndex) then { _civUnits pushBack _x }; } forEach allUnits;
            _civUnits = _civUnits call BIS_fnc_arrayShuffle;
            for "_i" from 0 to (_suicideCount - 1) do {
                if (_i >= count _civUnits) exitWith {};
                private _unit = _civUnits select _i;
                private _oldGroup = group _unit;
                private _newGroup = createGroup CIVILIAN;
                [_unit] joinSilent _newGroup;
                _newGroup deleteGroupWhenEmpty true;
                removeAllActions _unit;
                [_unit] remoteExec ["removeAllActions", 0];
                _unit setVariable ["isSuicideBomber", true, true];
                _unit setVariable ["isHostile", false, true];
                [_unit] spawn fnc_civ_suicideBomberBehaviour;
                private _groupList = missionNamespace getVariable [format ["civ_groups_%1", _locIndex], []];
                _groupList pushBack _newGroup;
                missionNamespace setVariable [format ["civ_groups_%1", _locIndex], _groupList];
            };
        };
    };

    if (CIV_PRESENCE == "RAVAGE") then {
        private _players = call BIS_fnc_listPlayers;
        {
            private _group = _x;
            while {(count (waypoints _group)) > 0} do { deleteWaypoint ((waypoints _group) select 0); };
            _group setBehaviour "COMBAT";
            _group setCombatMode "RED";
            _group setFormation "WEDGE";
            { { if (side _x == WEST) then { _unit reveal [_x, 4]; }; } forEach units _group; } forEach _players;
            if (count _players > 0) then {
                private _groupPos = getPos (leader _group);
                private _nearestPlayer = _players select 0;
                private _minDist = _groupPos distance _nearestPlayer;
                { private _dist = _groupPos distance _x; if (_dist < _minDist) then { _minDist = _dist; _nearestPlayer = _x; }; } forEach _players;
                private _wp = _group addWaypoint [getPos _nearestPlayer, 0];
                _wp setWaypointType "SAD";
                _wp setWaypointCompletionRadius 50;
                _wp setWaypointTimeout [10, 20, 30];
                private _wpCycle = _group addWaypoint [getPos _nearestPlayer, 100];
                _wpCycle setWaypointType "CYCLE";
            };
        } forEach _groups;
    };

    private _groupList = missionNamespace getVariable [format ["civ_groups_%1", _locIndex], []];
    _groupList append _groups;
    missionNamespace setVariable [format ["civ_groups_%1", _locIndex], _groupList];
    diag_log format ["[CIV] [Spawn] Spawned %1 civilians at location %2 (target population %3)", count _groups, _locIndex, _targetPop];

    missionNamespace setVariable [_spawningKey, false];
    diag_log format ["[CIV] [Spawn] Spawning flag cleared for location %1", _locIndex];

    [_locIndex, _centerPos, _triggerRadius] spawn {
        params ["_locIndex", "_centerPos", "_triggerRadius"];
        private _threadVar = format ["civ_monitor_%1", _locIndex];
        missionNamespace setVariable [_threadVar, false];
        sleep 1;
        missionNamespace setVariable [_threadVar, true];
        private _noPlayerCount = 0;
        private _maxNoPlayer = 2;
        while {missionNamespace getVariable [_threadVar, false]} do {
            sleep 40;
            if (!(missionNamespace getVariable [format ["civ_spawned_%1", _locIndex], false])) exitWith {
                missionNamespace setVariable [_threadVar, false];
            };
            private _playersInArea = allPlayers select { _x distance _centerPos < _triggerRadius };
            if (count _playersInArea == 0) then {
                _noPlayerCount = _noPlayerCount + 1;
                if (_noPlayerCount >= _maxNoPlayer) then {
                    [_locIndex, "cleanup"] spawn fnc_civ_handler;
                    missionNamespace setVariable [_threadVar, false];
                };
            } else {
                _noPlayerCount = 0;
            };
        };
    };
};