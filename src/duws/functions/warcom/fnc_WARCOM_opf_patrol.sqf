if (!isServer) exitWith {};
WARCOM_opf_patrol_type = "";
diag_log format ["WARCOM_opfor_ap_patrol: %1", WARCOM_opfor_ap];

sleep 20;  // Give time for WARCOM variables to init

// Type of patrol
[] spawn {
    WARCOM_opf_patrol_type = opfor_INFTEAM_X;

    waitUntil {sleep 30; WARCOM_opfor_ap>40};          
    WARCOM_opf_patrol_type = opfor_INFSQUAD_X;
        
    waitUntil {sleep 30; WARCOM_opfor_ap>65};          
    WARCOM_opf_patrol_type = opfor_INFWEPSQUAD_X;

    switch (VERSION_X) do {
        case "MODERN": {
            waitUntil {sleep 30; WARCOM_opfor_ap>100};
            while {WARCOM_opfor_ap<136} do {
                WARCOM_opf_patrol_type = 
                    [selectRandomWeighted [
                        opfor_ARMED_CAR1_X,1.0,
                        opfor_APC1_X,1.0,
                        opfor_APC2_X,1.0,
                        opfor_AA_APC_X,0.5
                    ]];
                sleep 30;
            };
            while {true} do {
                sleep 30;          
                if (HeavyArmor == 1) then {
                    WARCOM_opf_patrol_type = 
                        [selectRandomWeighted [
                            opfor_MBT_TANK1_X,1.0,
                            opfor_ARMED_CAR1_X,1.0,
                            opfor_APC1_X,1.0,
                            opfor_APC2_X,1.0,
                            opfor_AA_APC_X,0.5
                        ]];
                } else {
                    WARCOM_opf_patrol_type = 
                        [selectRandomWeighted [
                            opfor_ARMED_CAR1_X,1.0,
                            opfor_APC1_X,1.0,
                            opfor_APC2_X,1.0,
                            opfor_AA_APC_X,0.5
                        ]];
                };  
            };
        };
    };
};

sleep 200;  // wait for "Type of Patrol" to get the proper AP

// ===== 补给卡车巡逻专用全局变量（在任务命名空间中持久）=====
if (isNil "WARCOM_opf_lastSupplyTime") then {
    WARCOM_opf_lastSupplyTime = 0; // 上次生成时间（游戏时间）
    WARCOM_opf_supplyIntervalMin = 2700; // 最小间隔45分钟
    WARCOM_opf_supplyIntervalMax = 5400; // 最大间隔90分钟
};
// ============================================================

// Patrol main Infinite loop
opfor_patrol_count = 0;

[] spawn {
    while {true} do {
        // ===== 原有普通巡逻生成逻辑 =====
        // As soon as extended Campaign (DOMINATION) starts, stop creating patrols 
        if (DUWS_MODE == "DOMINATION") exitWith {};
        // make sure opfor is controlling at least 2 zones 
        // and opfor_patrol_count <= (total zones / 2) + 1   (5 zones = 3 patrol spawns max)
        
        if (count WARCOM_zones_controled_by_OPFOR > 1 && opfor_patrol_count <= (floor ((count serv_zones_array) / 2)) + 1) then { 
            sleep 2;
          
            // find a zone where to spawn OPF wave *** BEGIN
            _found = false;
            _randomZone = [];
            _failSafe = 0;
            while {!_found} do {
                _randomZone = WARCOM_zones_controled_by_OPFOR call BIS_fnc_selectRandom;
                {
                    if (_randomZone distance _x > 1500) then {
                        _found=true;
                    } else {
                        _found=false;
                    };
                } forEach allPlayers;
                sleep 0.2;
                _failSafe = _failSafe + 1;
                if (_failsafe > 10) then {sleep 300; _failsafe = 0;}
            };
            // find a zone *** end 
          
          
            // Find a safe location FAR FROM ZONE CENTER (keeps buggy zone selection from surprising BLUFOR)
            //_randomZone = [(_randomZone select 0)+100,(_randomZone select 1)+100];
            _spawnLoc = [_randomzone, 400,600,10,0,0.3,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;

            _group = [];
            if (WARCOM_opfor_ap>100) then {
                _group = [_spawnLoc, EAST, WARCOM_opf_patrol_type,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
                sleep 5;
                _addgroup = [_spawnLoc, EAST, opfor_INFTEAM_X,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
                _addgroup deleteGroupWhenEmpty true;
                sleep 5;
                (units _addgroup) joinSilent _group;
                _groupLeader = leader _group;
                _veh = vehicle _groupLeader;
                _group addVehicle _veh;
                _group deleteGroupWhenEmpty true;
            } else { 
                _group = [_spawnLoc, EAST, WARCOM_opf_patrol_type,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
                _group deleteGroupWhenEmpty true;
            };
            
            sleep 10; // give squads a chance to mount up
            [_group] spawn fnc_WARCOM_wp_opf_patrol;

            // SPAWN VEHICLE
            switch (VERSION_X) do {
                case "MODERN": {
                    // spawn car
                    if (WARCOM_opfor_ap>99) then {
                        [OPFOR_Faction_X,"car",_spawnLoc, 500] spawn fnc_random_veh_opf_patrol; // 修复：补充半径参数
                    };
                    // spawn armored
                    if (WARCOM_opfor_ap>149) then {
                        [OPFOR_Faction_X,"armored",_spawnLoc, 500] spawn fnc_random_veh_opf_patrol;
                    };
                    // spawn air 
                    if (WARCOM_opfor_ap>199) then {
                        [OPFOR_Faction_X,"air",_spawnLoc, 500] spawn fnc_random_veh_opf_patrol;
                    };
                };
            };

            opfor_patrol_count = opfor_patrol_count + 1;
        };
        
        // ===== 修复后的补给卡车生成逻辑 =====
        private _lastSupply = missionNamespace getVariable ["WARCOM_opf_lastSupplyTime", 0];
        private _min = missionNamespace getVariable ["WARCOM_opf_supplyIntervalMin", 2700];
        private _max = missionNamespace getVariable ["WARCOM_opf_supplyIntervalMax", 5400];
        
        if (time - _lastSupply >= (_min + random (_max - _min))) then {
            if (count WARCOM_zones_controled_by_OPFOR > 0) then {
                // 寻找一个远离玩家的区域
                private _found = false;
                private _randomZone = [];
                private _failSafe = 0;
                while {!_found && _failSafe < 20} do {
                    _randomZone = selectRandom WARCOM_zones_controled_by_OPFOR;
                    private _nearPlayers = false;
                    {
                        if (_randomZone distance _x < 1500) exitWith { _nearPlayers = true };
                    } forEach allPlayers;
                    if (!_nearPlayers) then { _found = true };
                    sleep 0.2;
                    _failSafe = _failSafe + 1;
                };
                if (_found) then {
                    private _spawnLoc = [_randomZone, 400, 600, 10, 0, 0.3, 0, [], []] call BIS_fnc_findSafePos;
                    private _created = [_spawnLoc, 0, opfor_AMMO_TRUCK_X, EAST] call BIS_fnc_spawnVehicle;
                    private _vehicle = _created select 0;
                    private _group = _created select 2;
                    _group deleteGroupWhenEmpty true;
                    [_group] spawn fnc_WARCOM_wp_opf_patrol;
                    [localize "STR_DUWS_T_allseer", ([localize "STR_DUWS_T_ammospotted"] call fnc_cs)] remoteExec ["BIS_fnc_showSubtitle", 0];
                    [] remoteExec ["fnc_broadcastRadioChatter", 0];
                };
                // 无论是否成功生成，更新计时器（避免频繁尝试）
                missionNamespace setVariable ["WARCOM_opf_lastSupplyTime", time];
            };
        };
        // =======================================

        sleep floor (random [2700,3800,5400]); // 普通巡逻延迟 Rand 45-90 min
          
        // Wait until BLUFOR has captured a zone. Prevents patrol spam
        waitUntil {sleep 30; count WARCOM_zones_controled_by_BLUFOR > 0};   
    };
};