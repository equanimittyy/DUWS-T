/*
    fnc_civ_handler_wbk.sqf
    WBK 模式平民统一处理函数（生成 + 清理）
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
    diag_log format ["[WBK] Invalid location index %1", _locIndex];
};
private _location = _locations select _locIndex;
private _centerPos = getPos _location;
private _triggerRadius = _radii param [_locIndex, 500];
if (_centerPos isEqualTo [0,0,0]) exitWith {
    diag_log format ["[WBK] Location %1 has zero position", _locIndex];
};
private _locationName = if (text _location != "") then { text _location } else { format ["Unnamed%1", _locIndex] };

// ============================================
// 清理模式（延迟 60 秒）
// ============================================
if (_mode == "cleanup") exitWith {
    diag_log format ["[WBK] [Cleanup] Requested for location %1, will execute in 60 seconds", _locIndex];
    private _currentPop = missionNamespace getVariable [format ["civ_pop_%1", _locIndex], 0];
    if (_currentPop > 1) then {
        private _message = format [localize "STR_DUWS_T_CIV_CLEANUP_WARNING", _locationName];
        [_message] remoteExec ["hint", 0];
    };
    private _pendingVar = format ["civ_pending_cleanup_%1", _locIndex];
    missionNamespace setVariable [_pendingVar, true];

    private _threadVar = format ["civ_monitor_%1", _locIndex];
    missionNamespace setVariable [_threadVar, false];
    diag_log format ["[WBK] Cleanup stopped monitor for %1", _locIndex];

    sleep 60;

    if (!(missionNamespace getVariable [_pendingVar, false])) exitWith {
        diag_log format ["[WBK] [Cleanup] Pending cleanup cancelled for %1", _locIndex];
    };

    private _playersInArea = allPlayers select { _x distance _centerPos < _triggerRadius };
    if (count _playersInArea > 0) exitWith {
        diag_log format ["[WBK] [Cleanup] Cleanup aborted for %1 because players are still in area", _locIndex];
        missionNamespace setVariable [_pendingVar, false];
    };

    diag_log format ["[WBK] [Cleanup] Executing cleanup for location %1", _locIndex];

    private _spawnedKey = format ["civ_spawned_%1", _locIndex];
    if (!(missionNamespace getVariable [_spawnedKey, false])) exitWith {
        diag_log format ["[WBK] [Cleanup] Location %1 not spawned, ignoring", _locIndex];
        missionNamespace setVariable [_pendingVar, false];
        if (civ_current_active_location == _locIndex) then {
            civ_current_active_location = -1;
            publicVariable "civ_current_active_location";
        };
    };

    // 删除所有属于该城镇的单位
    private _allUnits = allUnits;
    private _deletedUnits = 0;
    {
        if (_x getVariable ["civ_locIndex", -1] == _locIndex) then {
            deleteVehicle _x;
            _deletedUnits = _deletedUnits + 1;
        };
    } forEach _allUnits;
    diag_log format ["[WBK] [Cleanup] Deleted %1 units via allUnits scan", _deletedUnits];

    // 删除记录的组
    private _groups = missionNamespace getVariable [format ["civ_groups_%1", _locIndex], []];
    private _deletedGroups = 0;
    {
        if (!isNull _x) then {
            { deleteVehicle _x } forEach units _x;
            deleteGroup _x;
            _deletedGroups = _deletedGroups + 1;
        };
    } forEach _groups;
    diag_log format ["[WBK] [Cleanup] Deleted %1 groups from civ_groups list", _deletedGroups];
    missionNamespace setVariable [format ["civ_groups_%1", _locIndex], nil];

    // 删除区域内尸体
    private _allDead = allDeadMen;
    private _deletedCorpses = 0;
    {
        if (_x distance _centerPos < _triggerRadius) then {
            deleteVehicle _x;
            _deletedCorpses = _deletedCorpses + 1;
        };
    } forEach _allDead;
    diag_log format ["[WBK] [Cleanup] Deleted %1 corpses within radius", _deletedCorpses];

    missionNamespace setVariable [_spawnedKey, false];
    missionNamespace setVariable [format ["civ_remaining_%1", _locIndex], nil];
    missionNamespace setVariable [_pendingVar, false];
    diag_log format ["[WBK] [Cleanup] Spawned key set to false, remaining cleared for %1", _locIndex];

    private _iconName = format ["civ_icon_%1", _locIndex];
    private _currentPop = missionNamespace getVariable [format ["civ_pop_%1", _locIndex], 0];
    diag_log format ["[WBK] [Cleanup] Current total population: %1", _currentPop];

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
        // 焦土模式效果
        if (scorched_earth_enabled) then {
            commandpointsblu1 = commandpointsblu1 + 15;
            publicVariable "commandpointsblu1";
            private _bluApPenalty = - (3 + floor random 3);
            WARCOM_blufor_ap = WARCOM_blufor_ap + _bluApPenalty;
            publicVariable "WARCOM_blufor_ap";
            private _repPenalty = - (3 + floor random 3);
            Player_Reputation = Player_Reputation + _repPenalty;
            publicVariable "Player_Reputation";
            private _opfApPenalty = - (3 + floor random 3);
            WARCOM_opfor_ap = WARCOM_opfor_ap + _opfApPenalty;
            publicVariable "WARCOM_opfor_ap";
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
        diag_log format ["[WBK] [Cleanup] Lock released for location %1", _locIndex];
    };

    diag_log format ["[WBK] [Cleanup] Finished for location %1, final pop: %2", _locIndex, _currentPop];
};

// ============================================
// 生成模式
// ============================================
if (_mode == "spawn") then {
    diag_log format ["[WBK] [Spawn] Function called for location %1", _locIndex];

    // 互斥等待：只有锁空闲或本城镇已持锁才能继续
    private _timeout = diag_tickTime + 600; // 10分钟超时
    waitUntil {
        sleep 2;
        (civ_current_active_location == -1 || civ_current_active_location == _locIndex) || diag_tickTime > _timeout
    };
    if (diag_tickTime > _timeout) then {
        diag_log format ["[WBK] [Spawn] Location %1 wait timeout, forcing spawn.", _locIndex];
    };

    // 原子性获取锁：只有锁空闲时才设置为当前索引
    if (civ_current_active_location == -1) then {
        civ_current_active_location = _locIndex;
        publicVariable "civ_current_active_location";
        diag_log format ["[WBK] [Spawn] Lock acquired for location %1", _locIndex];
    } else {
        if (civ_current_active_location == _locIndex) then {
            diag_log format ["[WBK] [Spawn] Location %1 already holds lock, continuing.", _locIndex];
        } else {
            // 超时后强制抢占
            civ_current_active_location = _locIndex;
            publicVariable "civ_current_active_location";
            diag_log format ["[WBK] [Spawn] Location %1 force-acquired lock after timeout.", _locIndex];
        };
    };

    // 二次验证：玩家是否仍在区域内？
    private _playersNow = allPlayers select { _x distance _centerPos < _triggerRadius };
    if (count _playersNow == 0) exitWith {
        diag_log format ["[WBK] [Spawn] No players in location %1 after acquiring lock, aborting.", _locIndex];
        if (civ_current_active_location == _locIndex) then {
            civ_current_active_location = -1;
            publicVariable "civ_current_active_location";
        };
    };

    // 取消待处理清理
    private _pendingVar = format ["civ_pending_cleanup_%1", _locIndex];
    if (missionNamespace getVariable [_pendingVar, false]) then {
        missionNamespace setVariable [_pendingVar, false];
        diag_log format ["[WBK] [Spawn] Cancelled pending cleanup for %1 due to player re-entry", _locIndex];
    };

    // 等待生成启用时间
    if (isNil "civ_spawn_enabled_time") then {
        waitUntil { !isNil "civ_spawn_enabled_time" };
    };
    private _enableTime = missionNamespace getVariable ["civ_spawn_enabled_time", 0];
    if (_enableTime > time) then {
        private _wait = _enableTime - time;
        diag_log format ["[WBK] Delaying spawn for location %1 for %2 seconds", _locIndex, _wait];
        sleep _wait;
    };

    // 防重
    private _spawningKey = format ["civ_spawning_%1", _locIndex];
    private _spawnedKey = format ["civ_spawned_%1", _locIndex];

    if (missionNamespace getVariable [_spawningKey, false]) exitWith {
        diag_log format ["[WBK] [Spawn] Location %1 is already spawning, skipping duplicate request", _locIndex];
        if (civ_current_active_location == _locIndex) then {
            civ_current_active_location = -1;
            publicVariable "civ_current_active_location";
        };
    };
    missionNamespace setVariable [_spawningKey, true];

    if (missionNamespace getVariable [_spawnedKey, false]) exitWith {
        diag_log format ["[WBK] [Spawn] Location %1 already spawned, skipping", _locIndex];
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
        diag_log format ["[WBK] [Spawn] Target population for location %1 is %2, skipping spawn", _locIndex, _targetPop];
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
    diag_log format ["[WBK] [Spawn] Location %1: total pop %2, spawning %3, remaining %4", _locIndex, _targetPop, _spawnCount, _remaining];

    private _usableBuildings = [_centerPos, 2, _triggerRadius] call fnc_usableBuildings;
    diag_log format ["[WBK] [Spawn] Usable buildings count: %1", count _usableBuildings];

    // WBK 特有单位类型定义
    private _survivorTypes = [
        "C_man_p_beggar_F",
        "C_Man_casual_1_F",
        "C_Man_casual_3_F",
        "C_Man_casual_8_F",
        "C_Man_casual_6_v2_F",
        "C_Man_casual_2_F",
        "C_Man_UtilityWorker_01_F",
        "C_Man_Fisherman_01_F",
        "C_Man_p_shorts_1_F",
        "C_Man_w_worker_F"
    ];

    private _zombieTypesCommon = [
        "Zombie_Special_OPFOR_Boomer",
        "Zombie_Special_OPFOR_Leaper_1",
        "Zombie_Special_OPFOR_Leaper_2",
        "Zombie_Special_OPFOR_Screamer",
        "WBK_SpecialZombie_Corrupted_3"
    ];
    private _zombieTypesRare = [
        "WBK_SpecialZombie_Smasher_3",
        "WBK_SpecialZombie_Smasher_Hellbeast_3",
        "WBK_SpecialZombie_Smasher_Acid_3",
        "WBK_Goliaph_3"
    ];

    missionNamespace setVariable ["WBK_survivorTypes", _survivorTypes];
    missionNamespace setVariable ["WBK_zombieTypesCommon", _zombieTypesCommon];
    missionNamespace setVariable ["WBK_zombieTypesRare", _zombieTypesRare];

    waitUntil { sleep 1; !isNil "blufor_helmets" && !isNil "opfor_helmets" };
    duws_blufor_helmets = +blufor_helmets;
    duws_opfor_helmets = +opfor_helmets;
    duws_blufor_vests = +blufor_vests;
    duws_opfor_vests = +opfor_vests;

    missionNamespace setVariable ["WBK_duws_blufor_helmets", duws_blufor_helmets];
    missionNamespace setVariable ["WBK_duws_opfor_helmets", duws_opfor_helmets];
    missionNamespace setVariable ["WBK_duws_blufor_vests", duws_blufor_vests];
    missionNamespace setVariable ["WBK_duws_opfor_vests", duws_opfor_vests];

    WBK_civWeaponPool = [
        ["hgun_PDW2000_F", "30Rnd_9x21_Mag"],
        ["arifle_AKS_F", "30Rnd_545x39_Mag_F"],
        ["SMG_05_F", "30Rnd_9x21_Mag_SMG_02"],
        ["sgun_HunterShotgun_01_F", "2Rnd_12Gauge_Pellets"],
        ["sgun_HunterShotgun_01_sawedoff_F", "2Rnd_12Gauge_Pellets"],
        ["srifle_DMR_06_hunter_F", "10Rnd_762x51_Mag"],
        ["hgun_P07_F", "16Rnd_9x21_Mag"],
        ["hgun_Pistol_01_F", "10Rnd_9x21_Mag"]
    ];

    private _outerProbability = 0.6;
    private _maxOutdoorDist = _triggerRadius * 0.8;
    private _outdoorRange = 100 min _maxOutdoorDist;

    private _survivorCount = round (_spawnCount * 0.3);
    private _zombieCount = _spawnCount - _survivorCount;
    if (_survivorCount == 0 && _spawnCount > 0) then {
        _survivorCount = 1;
        _zombieCount = _spawnCount - 1;
    };
    diag_log format ["[WBK] [Spawn] Spawning %1 survivors and %2 zombies", _survivorCount, _zombieCount];

    private _survivorUnitTypes = [];
    for "_i" from 1 to _survivorCount do { _survivorUnitTypes pushBack (selectRandom _survivorTypes); };
    private _zombieUnitTypes = [];
    for "_i" from 1 to _zombieCount do {
        if (random 1 < 0.95) then { _zombieUnitTypes pushBack (selectRandom _zombieTypesCommon); }
        else { _zombieUnitTypes pushBack (selectRandom _zombieTypesRare); };
    };

    private _allGroups = [];

    // 死亡事件处理器
    if (isNil "WBK_unitKilledHandler") then {
        WBK_unitKilledHandler = {
            params ["_dead", "_killer", "_instigator"];
            if (!isServer) exitWith {};
            private _idx = _dead getVariable ["civ_locIndex", -1];
            if (_idx == -1) exitWith {};
            private _isZombie = _dead getVariable ["isZombie", false];
            if (_isZombie) then {
                private _type = typeOf _dead;
                private _rareTypes = missionNamespace getVariable ["WBK_zombieTypesRare", []];
                if (_type in _rareTypes) then {
                    private _reward = 10;
                    private _titleKey = "STR_DUWS_T_RARE_ZOMBIE_KILL_TITLE";
                    private _msgKey = "STR_DUWS_T_RARE_ZOMBIE_KILL_MSG";
                    if (_type == "WBK_Goliaph_3") then {
                        _reward = 30;
                        _titleKey = "STR_DUWS_T_GOLIAPH_KILL_TITLE";
                        _msgKey = "STR_DUWS_T_GOLIAPH_KILL_MSG";
                    };
                    commandpointsblu1 = commandpointsblu1 + _reward;
                    publicVariable "commandpointsblu1";
                    private _title = localize _titleKey;
                    private _msg = format [localize _msgKey, _reward];
                    ["repup", [_title, _msg]] remoteExec ["BIS_fnc_showNotification", 0];
                };
            };

            private _popVar = format ["civ_pop_%1", _idx];
            private _remVar = format ["civ_remaining_%1", _idx];
            private _curPop = missionNamespace getVariable [_popVar, 0];
            private _remaining = missionNamespace getVariable [_remVar, 0];
            if (_curPop <= 0) exitWith {};

            private _newPop = _curPop - 1;
            missionNamespace setVariable [_popVar, _newPop];
            private _globalMax = missionNamespace getVariable ["civ_maxSpawnPerVisit", 50];
            if (_newPop > _globalMax && _remaining > 0) then {
                missionNamespace setVariable [_remVar, _remaining - 1];
                private _locData = missionNamespace getVariable ["civ_locations", []];
                private _radData = missionNamespace getVariable ["civ_radii", []];
                if (_idx < count _locData && _idx < count _radData) then {
                    private _center = getPos (_locData select _idx);
                    private _radius = _radData param [_idx, 500];
                    [_center, _radius, _isZombie, _idx] call WBK_fnc_spawnReplacement;
                };
            };

            private _iconName = format ["civ_icon_%1", _idx];
            _iconName setMarkerText format ["%1", missionNamespace getVariable [_popVar, 0]];
        };
        publicVariable "WBK_unitKilledHandler";
    };

    if (isNil "WBK_fnc_spawnReplacement") then {
        WBK_fnc_spawnReplacement = {
            params ["_center", "_radius", "_isZombie", "_idx"];
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
            if (_foundPos isEqualTo []) then { _foundPos = _center getPos [random _radius, random 360]; };

            private _newType = "";
            private _newGroup = grpNull;
            if (_isZombie) then {
                private _common = missionNamespace getVariable ["WBK_zombieTypesCommon", []];
                private _rare = missionNamespace getVariable ["WBK_zombieTypesRare", []];
                if (random 1 < 0.95) then { _newType = selectRandom _common; }
                else { _newType = selectRandom _rare; };
                _newGroup = [_foundPos, INDEPENDENT, [_newType], [], [], [0.5, 0.6]] call BIS_fnc_spawnGroup;
            } else {
                private _survivorList = missionNamespace getVariable ["WBK_survivorTypes", []];
                _newType = selectRandom _survivorList;
                _newGroup = [_foundPos, WEST, [_newType], [], [], [0.5, 0.6]] call BIS_fnc_spawnGroup;
            };
            _newGroup deleteGroupWhenEmpty true;
            private _newUnit = leader _newGroup;
            _newUnit setPos _foundPos;
            _newUnit setVariable ["civ_locIndex", _idx];
            _newUnit setVariable ["isZombie", _isZombie];
            if (_isZombie) then {
                _newUnit setBehaviour "COMBAT";
                _newUnit setCombatMode "RED";
                while {(count (waypoints _newGroup)) > 0} do { deleteWaypoint ((waypoints _newGroup) select 0); };
                private _wp = _newGroup addWaypoint [_center, 0];
                _wp setWaypointType "SAD";
                _wp setWaypointSpeed "NORMAL";
                _wp setWaypointBehaviour "AWARE";
                _wp setWaypointCombatMode "RED";
            } else {
                if (random 1 < 0.5) then {
                    private _helmetList = if (random 1 < 0.7) then { duws_blufor_helmets } else { duws_opfor_helmets };
                    if (count _helmetList > 0) then { _newUnit addHeadgear (selectRandom _helmetList); };
                };
                if (random 1 < 0.7) then {
                    private _vestList = if (random 1 < 0.7) then { duws_blufor_vests } else { duws_opfor_vests };
                    if (count _vestList > 0) then { _newUnit addVest (selectRandom _vestList); };
                };
                _newUnit setBehaviour "AWARE";
                _newUnit setCombatMode "YELLOW";
                [_newUnit] remoteExec ["fnc_addRecruitAction", 0, true];
                if (random 1 < 0.5) then {
                    private _weaponEntry = selectRandom WBK_civWeaponPool;
                    private _weapon = _weaponEntry select 0;
                    private _magazine = _weaponEntry select 1;
                    for "_i" from 1 to 3 do { _newUnit addMagazineGlobal _magazine; };
                    _newUnit addWeapon _weapon;
                    _newUnit setVariable ["hasWeapon", true];
                };
                _wp = _newGroup addWaypoint [_center, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointSpeed "NORMAL";
                _wp setWaypointBehaviour "AWARE";
                _wp setWaypointTimeout [60, 90, 120];
                _wp setWaypointCompletionRadius 15;
            };
            _newUnit addEventHandler ["Killed", WBK_unitKilledHandler];
            private _centerPos = _center;
            private _radius = _radius;
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
            private _groupList = missionNamespace getVariable [format ["civ_groups_%1", _idx], []];
            _groupList pushBack _newGroup;
            missionNamespace setVariable [format ["civ_groups_%1", _idx], _groupList];
        };
        publicVariable "WBK_fnc_spawnReplacement";
    };

    // 生成幸存者组
    if (_survivorCount > 0) then {
        private _survivorGroupCenter = [_centerPos, 0, _triggerRadius * 0.5, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
        if (_survivorGroupCenter isEqualTo [0,0,0]) then { _survivorGroupCenter = _centerPos; };
        private _survivorGroup = [_survivorGroupCenter, WEST, _survivorUnitTypes, [], [], [0.5, 0.6]] call BIS_fnc_spawnGroup;
        _survivorGroup deleteGroupWhenEmpty true;
        _allGroups pushBack _survivorGroup;

        {
            private _pos = [_centerPos, 0, _triggerRadius, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
            if (_pos isEqualTo [0,0,0]) then { _pos = _centerPos };
            _x setPos _pos;
            _x setVariable ["civ_locIndex", _locIndex];
            _x setVariable ["isZombie", false, true];

            if (random 1 < 0.5) then {
                private _helmetList = if (random 1 < 0.7) then { duws_blufor_helmets } else { duws_opfor_helmets };
                if (count _helmetList > 0) then { _x addHeadgear (selectRandom _helmetList); };
            };
            if (random 1 < 0.7) then {
                private _vestList = if (random 1 < 0.7) then { duws_blufor_vests } else { duws_opfor_vests };
                if (count _vestList > 0) then { _x addVest (selectRandom _vestList); };
            };
            _x setBehaviour "AWARE";
            _x setCombatMode "YELLOW";
            [_x] remoteExec ["fnc_addRecruitAction", 0, true];
            if (random 1 < 0.5) then {
                private _weaponEntry = selectRandom WBK_civWeaponPool;
                private _weapon = _weaponEntry select 0;
                private _magazine = _weaponEntry select 1;
                for "_i" from 1 to 3 do { _x addMagazineGlobal _magazine; };
                _x addWeapon _weapon;
                _x setVariable ["hasWeapon", true];
            };
            _x addEventHandler ["Killed", WBK_unitKilledHandler];
        } forEach (units _survivorGroup);
    };

    // 生成僵尸组
    if (_zombieCount > 0) then {
        private _zombieGroupCenter = [_centerPos, 0, _triggerRadius, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
        if (_zombieGroupCenter isEqualTo [0,0,0]) then { _zombieGroupCenter = _centerPos; };
        private _zombieGroup = [_zombieGroupCenter, INDEPENDENT, _zombieUnitTypes, [], [], [0.5, 0.6]] call BIS_fnc_spawnGroup;
        _zombieGroup deleteGroupWhenEmpty true;
        _allGroups pushBack _zombieGroup;

        {
            private _pos = [_centerPos, 0, _triggerRadius, 5, 0, 0.5, 0] call BIS_fnc_findSafePos;
            if (_pos isEqualTo [0,0,0]) then { _pos = _centerPos };
            _x setPos _pos;
            _x setVariable ["civ_locIndex", _locIndex];
            _x setVariable ["isZombie", true, true];
            _x setBehaviour "COMBAT";
            _x setCombatMode "RED";
            _x addEventHandler ["Killed", WBK_unitKilledHandler];
        } forEach (units _zombieGroup);
    };

    missionNamespace setVariable [format ["civ_groups_%1", _locIndex], _allGroups];

    // 设置路点
    private _zombieGroups = _allGroups select { side (leader _x) == INDEPENDENT };
    {
        while {(count (waypoints _x)) > 0} do { deleteWaypoint ((waypoints _x) select 0); };
        private _wp = _x addWaypoint [_centerPos, 0];
        _wp setWaypointType "SAD";
        _wp setWaypointSpeed "NORMAL";
        _wp setWaypointBehaviour "AWARE";
        _wp setWaypointCombatMode "RED";
    } forEach _zombieGroups;

    private _survivorGroups = _allGroups select { side (leader _x) == WEST };
    {
        _wp = _x addWaypoint [_centerPos, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "NORMAL";
        _wp setWaypointBehaviour "AWARE";
        _wp setWaypointTimeout [60, 90, 120];
        _wp setWaypointCompletionRadius 15;
    } forEach _survivorGroups;

    [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_civpopR"] remoteExec ["BIS_fnc_showSubtitle", 0];
    sleep 2;
    ["biohazard", [localize "STR_DUWS_T_civrescuetitle", localize "STR_DUWS_T_civrescue"]] remoteExec ["BIS_fnc_showNotification", 0];
    [] remoteExec ["fnc_broadcastRadioChatter", 0];
    diag_log "[WBK] [Spawn] WBK broadcast messages sent";

    diag_log format ["[WBK] [Spawn] Spawned %1 groups at location %2 (target population %3)", count _allGroups, _locIndex, _targetPop];

    missionNamespace setVariable [_spawningKey, false];
    diag_log format ["[WBK] [Spawn] Spawning flag cleared for location %1", _locIndex];

    // 后台监控线程
    [_locIndex, _centerPos, _triggerRadius] spawn {
        params ["_locIndex", "_centerPos", "_triggerRadius"];
        private _threadVar = format ["civ_monitor_%1", _locIndex];
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
                    [_locIndex, "cleanup"] spawn fnc_civ_handler_wbk;
                    missionNamespace setVariable [_threadVar, false];
                };
            } else {
                _noPlayerCount = 0;
            };
        };
    };
};