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
    ["ERROR", "WBK", format ["Invalid location index %1", _locIndex]] call fnc_log;
};
private _location = _locations select _locIndex;
private _centerPos = getPos _location;
private _triggerRadius = _radii param [_locIndex, 500];
if (_centerPos isEqualTo [0,0,0]) exitWith {
    if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["Location %1 has zero position", _locIndex]] call fnc_log; };
};
if (_mode == "cleanup") exitWith {
    if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["[Cleanup] Requested for location %1, will execute in 60 seconds", _locIndex]] call fnc_log; };
    private _pendingVar = format ["civ_pending_cleanup_%1", _locIndex];
    missionNamespace setVariable [_pendingVar, true];

    private _threadVar = format ["civ_monitor_%1", _locIndex];
    missionNamespace setVariable [_threadVar, false];
    if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["Cleanup stopped monitor for %1", _locIndex]] call fnc_log; };

    sleep 60;

    if (!(missionNamespace getVariable [_pendingVar, false])) exitWith {
        if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["[Cleanup] Pending cleanup cancelled for %1", _locIndex]] call fnc_log; };
    };

    private _playersInArea = allPlayers select { _x distance _centerPos < _triggerRadius };
    if (count _playersInArea > 0) exitWith {
        ["ERROR", "WBK", format ["[Cleanup] Cleanup aborted for %1 because players are still in area", _locIndex]] call fnc_log;
        missionNamespace setVariable [_pendingVar, false];
    };

    if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["[Cleanup] Executing cleanup for location %1", _locIndex]] call fnc_log; };

    private _spawnedKey = format ["civ_spawned_%1", _locIndex];
    if (!(missionNamespace getVariable [_spawnedKey, false])) exitWith {
        if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["[Cleanup] Location %1 not spawned, ignoring", _locIndex]] call fnc_log; };
        missionNamespace setVariable [_pendingVar, false];
        [_locIndex] call fnc_civ_mode_releaseLock;
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
    if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["[Cleanup] Deleted %1 units via allUnits scan", _deletedUnits]] call fnc_log; };

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
    if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["[Cleanup] Deleted %1 groups from civ_groups list", _deletedGroups]] call fnc_log; };
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
    if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["[Cleanup] Deleted %1 corpses within radius", _deletedCorpses]] call fnc_log; };

    missionNamespace setVariable [_spawnedKey, false];
    missionNamespace setVariable [format ["civ_remaining_%1", _locIndex], nil];
    missionNamespace setVariable [_pendingVar, false];
    if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["[Cleanup] Spawned key set to false, remaining cleared for %1", _locIndex]] call fnc_log; };

    // 释放互斥锁
    [_locIndex] call fnc_civ_mode_releaseLock;
    if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["[Cleanup] Lock released for location %1", _locIndex]] call fnc_log; };

    if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["[Cleanup] Finished for location %1", _locIndex]] call fnc_log; };
};

if (_mode == "spawn") then {
    private _spawningKey = format ["civ_spawning_%1", _locIndex];

    ([_locIndex, _centerPos, _triggerRadius, "WBK"] call fnc_civ_mode_spawnGate) params ["_gateOk", "_targetPop"];
    if (!_gateOk) exitWith {};

    // Zombies, not civilians: this mode keeps the one-shot fill and the kill-replacement pool the
    // civilian towns dropped, because a horde that thins out as it is cut down is the mode. It
    // takes the density setting unscaled: the default lands within a handful of the retired
    // per-visit cap, so the crowd size a WBK town opens with is unchanged.
    private _density = missionNamespace getVariable ["civ_density", 15];
    private _spawnCount = [_density, _locIndex] call fnc_civ_liveTarget;
    private _remaining = (_targetPop - _spawnCount) max 0;
    missionNamespace setVariable [format ["civ_remaining_%1", _locIndex], _remaining];
    if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["[Spawn] Location %1: total pop %2, spawning %3, remaining %4", _locIndex, _targetPop, _spawnCount, _remaining]] call fnc_log; };

    private _usableBuildings = [_centerPos, 2, _triggerRadius] call fnc_usableBuildings;
    if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["[Spawn] Usable buildings count: %1", count _usableBuildings]] call fnc_log; };

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
    if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["[Spawn] Spawning %1 survivors and %2 zombies", _survivorCount, _zombieCount]] call fnc_log; };

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
                    [_reward, "wbk_survivor_rescued"] remoteExec ["fnc_cp_adjust", 2];
                    private _title = localize _titleKey;
                    private _msg = format [localize _msgKey, _reward];
                    ["repup", [_title, _msg]] remoteExec ["BIS_fnc_showNotification", 0];
                };
            };

            // Replacement is gated on the unspawned pool alone. The population figure it used to
            // consult is now the town's static size, so comparing it against the spawn ceiling
            // gave a constant answer for the whole campaign.
            private _remVar = format ["civ_remaining_%1", _idx];
            private _remaining = missionNamespace getVariable [_remVar, 0];
            if (_remaining > 0) then {
                missionNamespace setVariable [_remVar, _remaining - 1];
                private _locData = missionNamespace getVariable ["civ_locations", []];
                private _radData = missionNamespace getVariable ["civ_radii", []];
                if (_idx < count _locData && _idx < count _radData) then {
                    private _center = getPos (_locData select _idx);
                    private _radius = _radData param [_idx, 500];
                    [_center, _radius, _isZombie, _idx] call WBK_fnc_spawnReplacement;
                };
            };
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
                [_newUnit] remoteExec ["fnc_addRecruitAction", 0, _newUnit];
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
            [_x] remoteExec ["fnc_addRecruitAction", 0, _x];
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

    [localize "STR_DUWS_T_OVERLORD", ([localize "STR_DUWS_T_civpopR"] call fnc_cs)] remoteExec ["fnc_duws_dialogue", 0];
    sleep 2;
    ["biohazard", [localize "STR_DUWS_T_civrescuetitle", localize "STR_DUWS_T_civrescue"]] remoteExec ["BIS_fnc_showNotification", 0];
    if (duws_log_level >= 4) then { ["DEBUG", "WBK", "[Spawn] WBK broadcast messages sent"] call fnc_log; };

    if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["[Spawn] Spawned %1 groups at location %2 (target population %3)", count _allGroups, _locIndex, _targetPop]] call fnc_log; };

    missionNamespace setVariable [_spawningKey, false];
    if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["[Spawn] Spawning flag cleared for location %1", _locIndex]] call fnc_log; };

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