// Server-side kill bookkeeping for the WBK civilian mode.
//
// Executed by the registry rather than stored as one function: this file defines several.
// Broadcasts stay in server_fnc_init.sqf beside the load, so the manifest remains the one
// place to see what reaches clients.

fnc_wbk_survivorKilled_server = {
    params ["_dead", "_killer", "_instigator"];
    private _idx = _dead getVariable ["civ_locIndex", -1];
    if (_idx == -1) exitWith {};
    
    private _remainingVar = format ["civ_remaining_%1", _idx];

    // 检查是否有剩余人口可以补充
    private _remaining = missionNamespace getVariable [_remainingVar, 0];
    if (_remaining > 0) then {
        private _isZombie = _dead getVariable ["isZombie", false];
        private _newUnit = objNull;
        private _newGroup = grpNull;
        private _spawnPos = [_dead, 10, 50, 3, 0, 0.2, 0] call BIS_fnc_findSafePos;
        if (_spawnPos isEqualTo [0,0,0]) then { _spawnPos = getPos _dead; };
        
        if (_isZombie) then {
            // 生成僵尸
            private _zombieType = "";
            if (random 1 < 0.9) then {
                _zombieType = selectRandom ["Zombie_Special_OPFOR_Boomer", "Zombie_Special_OPFOR_Leaper_1", "Zombie_Special_OPFOR_Leaper_2", "Zombie_Special_OPFOR_Screamer", "WBK_SpecialZombie_Corrupted_3"];
            } else {
                _zombieType = selectRandom ["WBK_SpecialZombie_Smasher_3", "WBK_SpecialZombie_Smasher_Hellbeast_3", "WBK_SpecialZombie_Smasher_Acid_3", "WBK_Goliaph_3"];
            };
            _newGroup = createGroup EAST;
            _newUnit = _newGroup createUnit [_zombieType, _spawnPos, [], 0, "NONE"];
            _newUnit setBehaviour "COMBAT";
            _newUnit setCombatMode "RED";
            _newUnit setVariable ["isZombie", true, true];
            _newUnit addEventHandler ["Killed", {
                params ["_dead", "_killer", "_instigator"];
                [_dead, _killer, _instigator] remoteExec ["fnc_wbk_zombieKilled_server", 2];
            }];
        } else {
            // 生成幸存者
            private _survivorType = selectRandom ["C_man_p_beggar_F", "C_Man_casual_1_F", "C_Man_casual_3_F", "C_Man_casual_8_F", "C_Man_casual_6_v2_F", "C_Man_casual_2_F", "C_Man_UtilityWorker_01_F", "C_Man_Fisherman_01_F", "C_Man_p_shorts_1_F", "C_Man_w_worker_F"];
            _newGroup = createGroup RESISTANCE;
            _newUnit = _newGroup createUnit [_survivorType, _spawnPos, [], 0, "NONE"];
            // 添加装备等
            if (random 1 < 0.7) then {
                private _uniformList = if (random 1 < 0.7) then { blufor_uniforms } else { opfor_uniforms };
                if (count _uniformList > 0) then { _newUnit forceAddUniform (selectRandom _uniformList); };
            };
            if (random 1 < 0.5) then {
                private _helmetList = if (random 1 < 0.7) then { blufor_helmets } else { opfor_helmets };
                if (count _helmetList > 0) then { _newUnit addHeadgear (selectRandom _helmetList); };
            };
            if (random 1 < 0.7) then {
                private _vestList = if (random 1 < 0.7) then { blufor_vests } else { opfor_vests };
                if (count _vestList > 0) then { _newUnit addVest (selectRandom _vestList); };
            };
            _newUnit setBehaviour "CARELESS";
            _newUnit setCombatMode "BLUE";
            [_newUnit] remoteExec ["fnc_addRecruitAction", 0, _newUnit];
            _newUnit addEventHandler ["Killed", {
                params ["_dead", "_killer", "_instigator"];
                [_dead, _killer, _instigator] remoteExec ["fnc_wbk_survivorKilled_server", 2];
            }];
        };
        
        _newUnit setVariable ["civ_locIndex", _idx];
        // 将新单位加入城镇的组列表
        private _groups = missionNamespace getVariable [format ["civ_groups_%1", _idx], []];
        _groups pushBack _newGroup;
        missionNamespace setVariable [format ["civ_groups_%1", _idx], _groups];
        
        // 减少剩余人口
        missionNamespace setVariable [_remainingVar, _remaining - 1];
        if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["Replacement spawned at location %1, remaining now %2", _idx, _remaining - 1]] call fnc_log; };
    };
    
    if (duws_log_level >= 4) then { ["DEBUG", "WBK", format ["Survivor killed at location %1", _idx]] call fnc_log; };
};

