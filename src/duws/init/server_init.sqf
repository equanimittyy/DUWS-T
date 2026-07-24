diag_log format ["Server_init: %1", profileName];

// DEFINE SERVER VARIABLES and FUNCTIONS
[] call compile preprocessFileLineNumbers "duws\init\server_var_init.sqf";
[] call compile preprocessFileLineNumbers "duws\init\server_fnc_init.sqf";
setGroupIconsVisible [true,false]; //now everyone can see enemies on map
// Init the URBAN LOCATION FINDER
[] spawn fnc_moreUrban_locations;

// Create centers
createCenter sideLogic;
createcenter sideLogic;
LogicGroup = createGroup SideLogic;
createCenter west;
createCenter east;
createCenter resistance;
createCenter civilian;

// Set relationships
west setFriend [east, 0];
west setFriend [resistance, 0];
east setFriend [west, 0];
east setFriend [resistance, 0];
resistance setFriend [west, 0];
resistance setFriend [east, 0];
civilian setFriend [west, 1];
civilian setFriend [east, 1];

// CHECK FACTION FILES
[] call fnc_factions_check;

sleep 1;

// Send "complete" to client
serverinit_complete = true;
publicVariable "serverinit_complete";

// wait for HQ placement
waitUntil {sleep 0.1;chosen_hq_placement};

// Faction init + HQ build are deferred to final commit (createzone_server) so
// the setup screens' Back navigation can re-pick faction/HQ with nothing yet
// built. Everything below consumes only PosOfBLUHQ (set at placement) until
// this gate; verified no faction-array or HQ-object read sits before it.
waitUntil {sleep 0.1;createzone_server};

// wait for CUSTOM FACTIONS to be pasted
diag_log format ["Server waiting for BLU faction Data Temp"];
if (BLUFOR_Faction_X == "CUSTOM") then {waitUntil {sleep 0.1;BLUfactionDataTemp != ""}};
if (OPFOR_Faction_X == "CUSTOM") then {waitUntil {sleep 0.1;OPFfactionDataTemp != ""}};

///////////////////////
// INIT THE FACTIONS
///////////////////////

// BLUFOR
diag_log format ["BLUFOR Faction init on server: %1", BLUFOR_Faction_X];

if (BLUFOR_Faction_X == "CUSTOM") then {
	["blufor"] call fnc_custom_faction_init;
	waitUntil {sleep 0.1;count BLUfactionData > 0};
} else {
	[] call fnc_BLUFOR_faction_init;
};
diag_log format ["Blufor Faction init on server complete.  Rifleman: %1", blufor_SOLDIER_X];
diag_log format ["Blufor Faction init on server complete.  blufor RQST VEHICLE 01: %1", blufor_RQST_VEHICLE_01_X];

// create the BLUFOR squads
[] call fnc_BLUFOR_squad_init;
diag_log format ["blufor RECON_TEAM: %1", str blufor_RECON_TEAM_X];


// OPFOR
if (opfor_SOLDIER_X == "") then {
	diag_log format ["OPFOR Faction init on server: %1", OPFOR_Faction_X];

	if (OPFOR_Faction_X == "CUSTOM") then {
		["opfor"] call fnc_custom_faction_init;
		waitUntil {sleep 0.1;count OPFfactionData > 0};
	} else {
		[] call fnc_OPFOR_faction_init;
	};
	diag_log format ["Opfor Warcom Faction init on server complete.  Rifleman: %1", opfor_SOLDIER_X];
	diag_log format ["Opfor Warcom Faction init on server complete.  Spec Ops: %1", opfor_SPECOPS_X];

	// create the BLUFOR squads
	[] call fnc_OPFOR_squad_init;
	diag_log format ["opfor INF_TEAM: %1", str opfor_INFTEAM_X];

};

///////////////////////////
// Init the Ammobox lists
///////////////////////////
[] spawn fnc_create_ammo_lists;

////////////////////
// Init the BLU HQ
////////////////////
diag_log format ["bluHQ Position: %1", str PosOfBLUHQ];
[] spawn fnc_bluHQinit;

// Initialize the Dynamic Groups framework
["Initialize"] call BIS_fnc_dynamicGroups; 

enableSaving [false, false];

//////////////////////////////////////////////
/////  WAIT FOR HQ SPAWNS
//////////////////////////////////////////////

diag_log "SERVER HQ_pos_found_generated";
waitUntil {sleep 0.1;HQ_pos_found_generated};

// use weapons instead items, some factions bork on items
diag_log "SERVER opfor_ammobox_weapons";
waitUntil {sleep 0.1;(count opfor_ammobox_weapons) > 0};


////////////////////////////////////
//  INIT OPFOR Faction & WARCOM
////////////////////////////////////
diag_log format ["WARCOM INIT"];
[] spawn fnc_init_OPFOR_WARCOM;


/////////////////////////////////
// CREATE MAIN TASK/OBJECTIVE
/////////////////////////////////
[] spawn fnc_capture_zones_task;


///////////////////////////////////////////////////////
// Create the array of zone sizes for DESPAWN CLEANUP
///////////////////////////////////////////////////////
[] spawn fnc_zone_spawn_sizes;


// WEATHER INIT
if (dynamic_weather_enable) then {
	[] spawn fnc_weather;
};

/////////////////////////////////
//  MAP OBJECT CLEANING SCRIPT
/////////////////////////////////
[
	10*60,   // seconds to delete dead bodies (0 means don't delete)
	5*60,    // seconds to delete dead vehicles (0 means don't delete)
	30*60,   // seconds to delete immobile vehicles (0 means don't delete)
	10*60,   // seconds to delete dropped weapons (0 means don't delete)
	0,       // seconds to delete planted explosives (0 means don't delete)
	10*60    // seconds to delete dropped smokes/chemlights (0 means don't delete)
] spawn fnc_repetitive_cleanup;

// Cleanup unused players slots.
for[{_x = 2},{_x <= 36},{_x = _x + 1}] do {
    _thePlayer = missionNamespace getVariable format["player%1", _x];
    if(!isNil("_thePlayer")) then {
        if(!isPlayer _thePlayer) then {
            deleteVehicle _thePlayer;
        };
    };
};

waituntil {sleep 1;WARCOM_init_done;};
// prepopulate the Mission Locator
[] spawn fnc_missionLocator;

// SET OPFOR AI AIM to 0.2
// SET OPFOR/BLUFOR VEHICLES/UNITS REARM/REFUEL EVERY 10min
[] spawn fnc_AI_Master_Control;

// Init the Zeus objects
if (ZeusStatus != 0) then {
	[] spawn fnc_zeus_objects_init;
};

// Set the date/time AFTER setting the current weather
setDate [2035, 8, 3, time_of_day, 0];
	
	
// Speed up Time
if (time_Multiplier > 1) then {
	setTimeMultiplier time_Multiplier;
};
	
// CIV and WARCRIMES Spawn
if (CIV_PRESENCE != "NONE") then {
	// START THE WARCRIMES SCRIPT
	[] spawn fnc_warcrimes_script;
};
if (CIV_PRESENCE == "RAVAGE") then {
    [] spawn fnc_night_horde_event;
};
// NO VCOM WAYPOINTS
VCM_ADVANCEDMOVEMENT = false;
publicVariable "VCM_ADVANCEDMOVEMENT";
//连杀奖励机制
if (isServer) then {
    if (isNil "playerKillCount") then { playerKillCount = createHashMap; };
    addMissionEventHandler ["EntityKilled", {
        params ["_killed", "_killer", "_instigator"];

        // ========== 识别真正的击杀玩家（支持组员击杀） ==========
        private _shooter = objNull;
        if (isPlayer _instigator) then {
            _shooter = _instigator;
        };
        if (isNull _shooter && {isPlayer _killer}) then {
            _shooter = _killer;
        };
        if (isNull _shooter) then {
            {
                if (_killer in (units group _x)) exitWith {
                    _shooter = _x;
                };
            } forEach allPlayers;
        };
        if (isNull _shooter) exitWith {};
        // =====================================================

        private _type = typeOf _killed;
        private _points = 0;
        private _titleKey = "";
        private _msgKey = "";
        private _subtitleKey = "";

        // ========== 原有载具类型判断（完全保留） ==========
        // 辅助函数：检查单位类型是否匹配给定的变量（可能是字符串或数组）
        private _fnc_match = {
            params ["_type", "_varName"];
            private _value = missionNamespace getVariable [_varName, []];
            if (_value isEqualType "") then {
                _type isKindOf _value
            } else {
                if (_value isEqualType []) then {
                    ({_type isKindOf _x} count _value) > 0
                } else {
                    false
                }
            };
        };

        private _carClasses = [
            "C_Truck_02_covered_F",
            "C_Truck_02_transport_F",
            "C_Van_01_transport_F",
            "I_G_Van_01_transport_F",
            "C_Van_02_transport_F",
            "C_Offroad_02_unarmed_F",
            "C_Offroad_01_F",
            "B_Truck_01_ammo_F",
            "C_Truck_02_box_F",
            "C_Offroad_01_repair_F",
            "I_G_Offroad_01_repair_F",
            "C_Van_02_service_F",
            "I_G_Offroad_01_armed_F",
            "I_G_Offroad_01_lat_F",
            "I_C_Offroad_02_LMG_F",
            "I_C_Offroad_02_lat_F"
        ];
        private _apcClasses = [
            "I_C_Offroad_02_LMG_F",
            "I_C_Offroad_01_AT_F",
            "I_C_Offroad_02_LMG_F"
        ];
        private _tankClasses = [
            "I_C_Offroad_02_AT_F"
        ];
        private _heliClasses = [
            "C_Heli_Light_01_civil_F",
            "I_Heli_light_03_unarmed_F"
        ];
        private _planeClasses = [
            "I_C_Plane_Civil_01_F"
        ];

        if ( [_type, "opfor_COVERED_TRUCK_X"] call _fnc_match ||
             [_type, "opfor_TRANS_TRUCK_X"] call _fnc_match ||
             [_type, "opfor_AMMO_TRUCK_X"] call _fnc_match ||
             [_type, "opfor_REPAIR_TRUCK_X"] call _fnc_match ||
             [_type, "opfor_ARMED_CAR1_X"] call _fnc_match ||
             ({_type isKindOf _x} count _carClasses) > 0 ) then {
            _points = 1;
            _titleKey = "STR_DUWS_T_KILL_CAR_TITLE";
            _msgKey = "STR_DUWS_T_KILL_CAR_MSG";
            _subtitleKey = "STR_DUWS_T_KILL_CAR_SUBTITLE";
        } else {
            if ( [_type, "opfor_APC1_X"] call _fnc_match ||
                 [_type, "opfor_APC2_X"] call _fnc_match ||
                 [_type, "opfor_AA_APC_X"] call _fnc_match ||
                 ({_type isKindOf _x} count _apcClasses) > 0 ) then {
                _points = 3;
                _titleKey = "STR_DUWS_T_KILL_APC_TITLE";
                _msgKey = "STR_DUWS_T_KILL_APC_MSG";
                _subtitleKey = "STR_DUWS_T_KILL_APC_SUBTITLE";
            } else {
                if ( [_type, "opfor_MBT_TANK1_X"] call _fnc_match ||
                     ({_type isKindOf _x} count _tankClasses) > 0 ) then {
                    _points = 5;
                    _titleKey = "STR_DUWS_T_KILL_TANK_TITLE";
                    _msgKey = "STR_DUWS_T_KILL_TANK_MSG";
                    _subtitleKey = "STR_DUWS_T_KILL_TANK_SUBTITLE";
                } else {
                    if ( [_type, "opfor_TRANS_HELI_X"] call _fnc_match ||
                         [_type, "opfor_ATTACK_HELI_X"] call _fnc_match ||
                         ({_type isKindOf _x} count _heliClasses) > 0 ) then {
                        _points = 5;
                        _titleKey = "STR_DUWS_T_KILL_HELI_TITLE";
                        _msgKey = "STR_DUWS_T_KILL_HELI_MSG";
                        _subtitleKey = "STR_DUWS_T_KILL_HELI_SUBTITLE";
                    } else {
                        if ( [_type, "opfor_MISC_AIR_X"] call _fnc_match ||
                             ({_type isKindOf _x} count _planeClasses) > 0 ) then {
                            _points = 8;
                            _titleKey = "STR_DUWS_T_KILL_PLANE_TITLE";
                            _msgKey = "STR_DUWS_T_KILL_PLANE_MSG";
                            _subtitleKey = "STR_DUWS_T_KILL_PLANE_SUBTITLE";
                        };
                    };
                };
            };
        };
        // =================================================

        // ========== 击杀计数（用于连杀奖励） ==========
        private _playerUID = getPlayerUID _shooter;
        private _currentKills = playerKillCount getOrDefault [_playerUID, 0];
        _currentKills = _currentKills + 1;
        playerKillCount set [_playerUID, _currentKills];
        // =============================================

        // ========== 发放载具奖励（完全独立） ==========
        if (_points > 0) then {
            commandpointsblu1 = commandpointsblu1 + _points;
            publicVariable "commandpointsblu1";

            private _name = name _shooter;
            private _messageTitle = localize _titleKey;
            private _messageBody = format [localize _msgKey, _name, _points];

            ["killstreak", [_messageTitle, _messageBody]] remoteExec ["BIS_fnc_showNotification", 0];
            [_name, localize _subtitleKey] remoteExec ["BIS_fnc_showSubtitle", 0];
            [] remoteExec ["fnc_broadcastRadioChatter", 0];
        };
        // ============================================

        // ========== 连杀奖励（每10击杀 +1CP，独立于载具类型） ==========
        if (_currentKills % 10 == 0) then {
            private _extraPoints = 1;
            commandpointsblu1 = commandpointsblu1 + _extraPoints;
            publicVariable "commandpointsblu1";
            private _name = name _shooter;
            private _msg = format [localize "STR_DUWS_T_KILL_STREAK_MSG", _name, _currentKills, _extraPoints];
            ["killstreak", [localize "STR_DUWS_T_KILL_STREAK_TITLE", _msg]] remoteExec ["BIS_fnc_showNotification", 0];
            [_name, localize "STR_DUWS_T_killconfirm"] remoteExec ["BIS_fnc_showSubtitle", 0];
            [] remoteExec ["fnc_broadcastRadioChatter", 0];
        };
        // ============================================================
    }];
};
if (isServer) then {
    // 全局冷却（可选，按需保留或调整）
    missionNamespace setVariable ["global_flare_lastTime", -999];

    my_fnc_createFlare = {
        params ["_pos"];
        private _now = diag_tickTime;
        private _lastGlobal = missionNamespace getVariable ["global_flare_lastTime", -999];
        if (_now - _lastGlobal < 240) exitWith {}; // 240秒全局冷却
        missionNamespace setVariable ["global_flare_lastTime", _now];

        // 1. 创建红色照明弹（可见弹体）
        private _flare = "F_40mm_Red" createVehicle _pos;
        // 添加轻微随机飘落速度，模拟真实感
        _flare setVelocity [random [-1,0,1], random [-1,0,1], random [-1,0]];

        // 2. 创建红色光源，并绑定到照明弹上
        private _light = "#lightpoint" createVehicle _pos;
        _light attachTo [_flare, [0,0,0]];  // 光源随照明弹一起运动

        // 设置光源颜色为红色
        _light setLightColor [1, 0.2, 0.2];      // 主光源颜色（亮红）
        _light setLightAmbient [1, 0.2, 0.2];    // 环境光颜色（偏红）
        
        // 亮度参数（可大幅调高）
        _light setLightBrightness 200;            // 基础亮度
        _light setLightIntensity 1000;            // 强度
        
        // 衰减设置：光传很远，亮度衰减缓慢
        _light setLightAttenuation [0, 0, 0, 0.0035, 0, 250]; // [起始, 常数, 线性, 二次, 硬限起始, 硬限结束]
        
        // 添加光晕
        _light setLightUseFlare true;
        _light setLightFlareSize 20;
        _light setLightFlareMaxDistance 500;
        
        // 白天可见
        _light setLightDayLight true;

        [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_opforflare"] remoteExec ["BIS_fnc_showSubtitle", 0];
        sleep 6;
        [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_opforflare2"] remoteExec ["BIS_fnc_showSubtitle", 0];
        // 3. 40秒后删除光源（照明弹此时已燃尽）
        [_light] spawn {
            params ["_light"];
            sleep 40;
            if (!isNull _light) then { deleteVehicle _light; };
        };

    };
    publicVariable "my_fnc_createFlare";
};
[] spawn fnc_dynamicAtmosphere_init;
// 启动线人系统
[] spawn fnc_civ_informant_system;
// 服务器端（如 server_init.sqf）
{ 
    [_x] remoteExec ["addRating", _x];
} forEach allPlayers;

[] spawn {
    waitUntil { sleep 1; !isNil "PosOfBLUHQ" && {count allPlayers > 0} };
    private _hqPos = PosOfBLUHQ;
    private _executed = false;
    
    while {!_executed} do {
        // 检查是否有玩家距离 HQ 小于 50 米
        private _anyPlayerNear = false;
        {
            if (isPlayer _x && {alive _x} && {_x distance _hqPos < 50}) exitWith {
                _anyPlayerNear = true;
            };
        } forEach (call BIS_fnc_listPlayers);
        
        if (_anyPlayerNear) then {
            diag_log "[Arsenal] Player detected within 50m of HQ. Scanning nearby units' gear...";
            [] call fnc_addNearbyUnitsGearToArsenal;
            _executed = true;
        } else {
            sleep 5; // 每 5 秒检查一次
        };
    };
};
// 触发快速换装数据扫描（当有玩家首次靠近 HQ 50 米内）
[] spawn {
    waitUntil { sleep 1; !isNil "PosOfBLUHQ" && {count allPlayers > 0} };
    private _hqPos = PosOfBLUHQ;
    private _executed = false;
    
    while {!_executed} do {
        private _anyPlayerNear = false;
        {
            if (isPlayer _x && {alive _x} && {_x distance _hqPos < 50}) exitWith {
                _anyPlayerNear = true;
            };
        } forEach (call BIS_fnc_listPlayers);
        
        if (_anyPlayerNear) then {
            diag_log "[QuickChange] Player detected within 50m of HQ. Scanning nearby units...";
            [] call fnc_scanNearbyUnitsForQuickChange;
            _executed = true;
        } else {
            sleep 5;
        };
    };
};
"apocalypse_mode" addPublicVariableEventHandler {
    params ["_var", "_value"];
    if (_value) then {
        diag_log "[Apocalypse] Public variable detected, launching destruction.";
        [] spawn fnc_apocalypse_buildings;
    };
};
// 在 server_init.sqf 末尾附近添加
[] spawn {
    waitUntil { sleep 1; WARCOM_init_done }; // 等待 WARCOM 初始化完成，确保单位已生成
    sleep 5; // 稍等片刻，让单位稳定
    [] execVM "duws\functions\misc\fnc_collectEquipmentFromUnits.sqf"; // 执行装备收集
};
[] spawn {
    scriptName "Add to InitServer.sqf -> Prevent AI Abandoning Vehicles";
    while{true} do {
        
        {
            // Sets whether or not cargo or turret units should get out of vehicle when in combat. If true, vehicle will stop and units will dismount.
            _x setUnloadInCombat [true, false];        // vehicle setUnloadInCombat [allowCargo, allowTurrets]
            // If true, units will remain in a vehicle with broken tracks/wheels; they will still eject if the vehicle is drowning, about to explode or upside down for a while.
            _x allowCrewInImmobile [true, true];            // vehicle allowCrewInImmobile allow / vehicle allowCrewInImmobile [brokenWheels, upsideDown]
            _x setVariable ["vehAiLockInit",true];
        }forEach  ( vehicles select { !(_x getVariable ["vehAiLockInit",false]) } );
        
        sleep 300.00;    // every 5 minutes
    };
};
// ==================== 直升机入场脚本启动 ====================
// 等待玩家完成参数选择和 HQ 放置
waitUntil { sleep 1.0; chosen_settings };
waitUntil { sleep 1.0; HQ_pos_found_generated };
// 再等待十几秒，确保所有玩家已连接并同步
sleep 15;
diag_log "[SERVER] Starting helicopter intro sequence...";
[] spawn fnc_intro_heli;
// 仅在非僵尸/非WBK模式下扫描平民装备
if (CIV_PRESENCE != "RAVAGE" && CIV_PRESENCE != "WBK" && CIV_PRESENCE != "NONE") then {
    [] spawn fnc_scanCivilianGear;
};
// 延迟一段时间后调用扫描，确保阵营变量已初始化
[] spawn {
    sleep 15;  // 等待阵营初始化完成
    [] spawn fnc_scanEnemyGear;
};
// ========== 伪装冷却异常监控（服务器端，防重，多人兼容） ==========
if (isNil "DUWS_cooldownMonitor_running") then {
    DUWS_cooldownMonitor_running = true;
    publicVariable "DUWS_cooldownMonitor_running";
    
    [] spawn {
        // 等待游戏稳定运行
        waitUntil { sleep 10; time > 10 };
        
        while {true} do {
            {
                private _player = _x;
                if (isNull _player) then { continue };
                if (!alive _player) then { continue };
                
                // ----------------- 敌人伪装冷却（最大 600 秒）-----------------
                private _lastEnemy = _player getVariable ["DUWS_enemyDisguise_lastUse", -610];
                private _enemyRemaining = 610 - (diag_tickTime - _lastEnemy);
                if (_enemyRemaining > 610 || _enemyRemaining < -610) then {
                    _player setVariable ["DUWS_enemyDisguise_lastUse", diag_tickTime - 305, true];
                    diag_log format ["[COOLDOWN] Server fixed enemy disguise for %1", name _player];
                };
                
                // ----------------- 平民伪装冷却（最大 300 秒）-----------------
                private _lastCiv = _player getVariable ["DUWS_disguise_lastUse", -310];
                private _civRemaining = 310 - (diag_tickTime - _lastCiv);
                if (_civRemaining > 310 || _civRemaining < -310) then {
                    _player setVariable ["DUWS_disguise_lastUse", diag_tickTime - 155, true];
                    diag_log format ["[COOLDOWN] Server fixed civilian disguise for %1", name _player];
                };
                
                // ----------------- 雇佣游击队冷却（最大 1800 秒）-----------------
                private _lastPartisan = _player getVariable ["DUWS_hirePartisans_lastUse", -1810];
                private _partisanRemaining = 1810 - (diag_tickTime - _lastPartisan);
                if (_partisanRemaining > 1810 || _partisanRemaining < -1810) then {
                    _player setVariable ["DUWS_hirePartisans_lastUse", diag_tickTime - 905, true];
                    diag_log format ["[COOLDOWN] Server fixed partisans for %1", name _player];
                };
                
                // ----------------- 雇佣 PMC 冷却（最大 900 秒）-----------------
                private _lastPMC = _player getVariable ["DUWS_hirePMC_lastUse", -910];
                private _pmcRemaining = 910 - (diag_tickTime - _lastPMC);
                if (_pmcRemaining > 910 || _pmcRemaining < -910) then {
                    _player setVariable ["DUWS_hirePMC_lastUse", diag_tickTime - 455, true];
                    diag_log format ["[COOLDOWN] Server fixed PMC for %1", name _player];
                };
                
                // ----------------- GM 休息治疗冷却（最大 600 秒）-----------------
                private _lastGMHeal = missionNamespace getVariable ["GM_Heal_LastUsedTime", -610];
                private _gmRemaining = 610 - (diag_tickTime - _lastGMHeal);
                if (_gmRemaining > 610 || _gmRemaining < -610) then {
                    missionNamespace setVariable ["GM_Heal_LastUsedTime", diag_tickTime - 305];
                    publicVariable "GM_Heal_LastUsedTime";
                    diag_log "[COOLDOWN] Server fixed GM heal cooldown";
                };
                
            } forEach (call BIS_fnc_listPlayers);
            
            sleep 60; // 每分钟检查一次
        };
    };
};
// ======================================================
[] spawn fnc_createKillhouse;
if (!isServer) exitWith {};
