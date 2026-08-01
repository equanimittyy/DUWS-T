// Locality: server -- see callers.
// Logging first: the registry self-check and every milestone below need fnc_log, and a
// failure in server_var_init/server_fnc_init is exactly what has to be visible.
[] call compile preprocessFileLineNumbers "duws\shared\functions\fnc_log_init.sqf";
["INFO", "BOOT", format ["Server_init: %1", profileName]] call fnc_log;
["INFO", "BOOT", format ["server_init start, player %1", profileName]] call fnc_log;

// DEFINE SERVER VARIABLES and FUNCTIONS
[] call compile preprocessFileLineNumbers "duws\server\server_var_init.sqf";
["INFO", "BOOT", "server_var_init done"] call fnc_log;
[] call compile preprocessFileLineNumbers "duws\server\server_fnc_init.sqf";
["INFO", "BOOT", "server_fnc_init done"] call fnc_log;
setGroupIconsVisible [true,false]; //now everyone can see enemies on map
// Init the URBAN LOCATION FINDER
[] spawn fnc_moreUrban_locations;

// Create centers
createCenter sideLogic;
createcenter sideLogic;
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
while {!(["BOOT", "chosen_hq_placement (player is placing HQ)", {chosen_hq_placement}, 300] call fnc_waitLogged)} do {};

// Faction init + HQ build are deferred to final commit (createzone_server) so
// the setup screens' Back navigation can re-pick faction/HQ with nothing yet
// built. Everything below consumes only PosOfBLUHQ (set at placement) until
// this gate; verified no faction-array or HQ-object read sits before it.
while {!(["BOOT", "createzone_server (setup screens committed)", {createzone_server}, 300] call fnc_waitLogged)} do {};

// wait for CUSTOM FACTIONS to be pasted
["INFO", "BOOT", "Server waiting for BLU faction Data Temp"] call fnc_log;
if (BLUFOR_Faction_X == "CUSTOM") then { while {!(["FACTION", "BLUfactionDataTemp pasted", {BLUfactionDataTemp != ""}, 300] call fnc_waitLogged)} do {}; };
if (OPFOR_Faction_X == "CUSTOM") then { while {!(["FACTION", "OPFfactionDataTemp pasted", {OPFfactionDataTemp != ""}, 300] call fnc_waitLogged)} do {}; };

// BLUFOR
["INFO", "BOOT", format ["BLUFOR Faction init on server: %1", BLUFOR_Faction_X]] call fnc_log;

if (BLUFOR_Faction_X == "CUSTOM") then {
	["blufor"] call fnc_custom_faction_init;
	while {!(["FACTION", "BLUfactionData populated", {count BLUfactionData > 0}, 300] call fnc_waitLogged)} do {};
} else {
	[] call fnc_BLUFOR_faction_init;
};
["INFO", "BOOT", format ["Blufor Faction init on server complete.  Rifleman: %1", blufor_SOLDIER_X]] call fnc_log;
["INFO", "BOOT", format ["Blufor Faction init on server complete.  blufor RQST VEHICLE 01: %1", (["VEHICLE"] call fnc_faction_rqst_list) param [0, "none"]]] call fnc_log;

// create the BLUFOR squads
[] call fnc_BLUFOR_squad_init;
["INFO", "BOOT", format ["blufor RECON_TEAM: %1", str blufor_RECON_TEAM_X]] call fnc_log;


// OPFOR
if (opfor_SOLDIER_X == "") then {
	["INFO", "BOOT", format ["OPFOR Faction init on server: %1", OPFOR_Faction_X]] call fnc_log;

	if (OPFOR_Faction_X == "CUSTOM") then {
		["opfor"] call fnc_custom_faction_init;
		while {!(["FACTION", "OPFfactionData populated", {count OPFfactionData > 0}, 300] call fnc_waitLogged)} do {};
	} else {
		[] call fnc_OPFOR_faction_init;
	};
	["INFO", "BOOT", format ["Opfor Warcom Faction init on server complete.  Rifleman: %1", opfor_SOLDIER_X]] call fnc_log;
	["INFO", "BOOT", format ["Opfor Warcom Faction init on server complete.  Spec Ops: %1", opfor_SPECOPS_X]] call fnc_log;

	// create the BLUFOR squads
	[] call fnc_OPFOR_squad_init;
	["INFO", "BOOT", format ["opfor INF_TEAM: %1", str opfor_INFTEAM_X]] call fnc_log;

};

[] spawn fnc_create_ammo_lists;

["INFO", "BOOT", format ["bluHQ Position: %1", str PosOfBLUHQ]] call fnc_log;
[] spawn fnc_bluHQinit;

// Initialize the Dynamic Groups framework
["Initialize"] call BIS_fnc_dynamicGroups; 

enableSaving [false, false];

while {!(["BOOT", "HQ_pos_found_generated", {HQ_pos_found_generated}, 300] call fnc_waitLogged)} do {};

// use weapons instead items, some factions bork on items
while {!(["BOOT", "opfor_ammobox_weapons built", {(count opfor_ammobox_weapons) > 0}, 180] call fnc_waitLogged)} do {};


["INFO", "BOOT", "WARCOM INIT"] call fnc_log;
[] spawn fnc_init_OPFOR_WARCOM;


[] spawn fnc_capture_zones_task;


[] spawn fnc_zone_spawn_sizes;


// WEATHER INIT
if (dynamic_weather_enable) then {
	[] spawn fnc_weather;
};

// One lifetime for every category the sweep collects; 0 turns it off. The default lives in
// the parameter, not here, so the two cannot drift apart.
[["DUWS_CleanupLifetime", 900] call BIS_fnc_getParamValue] spawn fnc_repetitive_cleanup;

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
	
if (CIV_PRESENCE == "RAVAGE") then {
    [] spawn fnc_night_horde_event;
};
// NO VCOM WAYPOINTS
VCM_ADVANCEDMOVEMENT = false;
publicVariable "VCM_ADVANCEDMOVEMENT";
//击杀奖励机制
if (isServer) then {
    if (isNil "playerKillCount") then { playerKillCount = createHashMap; };
    // CP owed for kills by players who have already left, banked until the next sweep.
    departedKillCP = 0;
    addMissionEventHandler ["EntityKilled", {
        params ["_killed", "_killer", "_instigator"];

        // Killhouse bodies never pay. The drill spawns hostile OPFOR on demand and already
        // awards a fixed sum per completed run, so counting them here would turn an
        // unlimited training course into an unlimited CP source. Plain (non-public)
        // setVariable is enough: the tag is written and read on the server.
        if (_killed getVariable ["killhouse_enemy", false]) exitWith {};

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

        // Only hostiles pay: EntityKilled fires for civilians, friendlies and empty
        // vehicles too, and paying for civilian kills rewards exactly what the town
        // reputation charge penalises. 0.6 is the engine's hostile/friendly cutoff, and the mission
        // sets every playable side pair to 0, so INDEPENDENT zombies still count.
        if ((side _shooter) getFriend (side _killed) >= 0.6) exitWith {};

        // Every kill attributed to this player counts the same; the tally converts to CP
        // on the periodic sweep below, not here.
        private _uid = getPlayerUID _shooter;
        playerKillCount set [_uid, (playerKillCount getOrDefault [_uid, 0]) + 1];
    }];

    // A rejoining player starts from zero: the tally is keyed by UID and outlives the
    // session that earned it, so without this a returning player resumes an old count.
    addMissionEventHandler ["PlayerConnected", {
        params ["", "_uid"];
        playerKillCount set [_uid, 0];
    }];

    // A leaver's whole batches are banked here and paid on the next sweep; the remainder
    // dies with the entry rather than waiting for a session that may never return.
    addMissionEventHandler ["PlayerDisconnected", {
        params ["", "_uid"];
        private _kills = playerKillCount getOrDefault [_uid, 0];
        departedKillCP = departedKillCP + (floor (_kills / kill_cp_kills)) * kill_cp_award;
        playerKillCount deleteAt _uid;
    }];

    // Kill income is paid in one periodic sweep rather than per kill: a tally the player
    // watches build reads as campaign economy, where a payout per body reads as a score
    // feed. Each player is told only about their own award, so the credit stays personal.
    // Defined here beside the handlers that fill the tally, but driven by the campaign
    // economy tick in server/misc/fnc_zonesundercontrol.sqf -- a second timer of the same
    // nominal period still accrues its own scheduler slop and walks out of phase.
    fnc_kill_income_sweep = {
        {
            private _uid = getPlayerUID _x;
            private _kills = playerKillCount getOrDefault [_uid, 0];
            private _batches = floor (_kills / kill_cp_kills);
            if (_batches > 0) then {
                private _award = _batches * kill_cp_award;
                // Server-side caller: call runs inline, where remoteExec [...,2] would
                // land a frame later.
                [_award, "kill_income"] call fnc_cp_adjust;
                playerKillCount set [_uid, _kills - _batches * kill_cp_kills];
                ["CPaddedattrition", [_award]] remoteExec ["BIS_fnc_showNotification", _x, false];
            };
        } forEach allPlayers;

        if (departedKillCP > 0) then {
            [departedKillCP, "kill_income_departed"] call fnc_cp_adjust;
            departedKillCP = 0;
        };
    };
};
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
            ["INFO", "GEAR", "Player detected within 50m of HQ. Scanning nearby units' gear..."] call fnc_log;
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
            ["INFO", "GEAR", "Player detected within 50m of HQ. Scanning nearby units..."] call fnc_log;
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
        ["INFO", "SUPPORT", "Public variable detected, launching destruction."] call fnc_log;
        [] spawn fnc_apocalypse_buildings;
    };
};
// 在 server_init.sqf 末尾附近添加
[] spawn {
    waitUntil { sleep 1; WARCOM_init_done }; // 等待 WARCOM 初始化完成，确保单位已生成
    sleep 5; // 稍等片刻，让单位稳定
    [] execVM "duws\server\misc\fnc_collectEquipmentFromUnits.sqf"; // 执行装备收集
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
// Zones and civilians both finish well after HQ placement, so the intro must not fly players
// in while the campaign is still being built around them.
while {!(["BOOT", "mission_init_complete (zones built, civilians registered)",
    {mission_init_complete}, 300] call fnc_waitLogged)} do {};
// 再等待十几秒，确保所有玩家已连接并同步
sleep 15;
["INFO", "BOOT", "Starting helicopter intro sequence..."] call fnc_log;
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
// These cooldowns stamp diag_tickTime, which counts from Arma process start, not mission
// start. Resuming an autosave in a fresh Arma session restarts that clock, so every stamp
// then sits in the future and wedges its action for as long as the old session had run.
// A stamp ahead of the clock has no other cause, so drop it and let each function's own
// "never used" default apply. Stamps far in the past are just unused actions -- not faults.
// GM_Heal_LastUsedTime is deliberately absent: it stamps mission time, which savegames restore.
if (isNil "DUWS_cooldownMonitor_running") then {
    DUWS_cooldownMonitor_running = true;
    publicVariable "DUWS_cooldownMonitor_running";

    [] spawn {
        private _cooldownVars = [
            "DUWS_enemyDisguise_lastUse",
            "DUWS_disguise_lastUse",
            "DUWS_hirePartisans_lastUse",
            "DUWS_hirePMC_lastUse"
        ];

        while {true} do {
            {
                private _player = _x;
                if (!isNull _player) then {
                    {
                        if ((_player getVariable [_x, 0]) > diag_tickTime) then {
                            _player setVariable [_x, nil, true];
                            if (duws_log_level >= 4) then { ["DEBUG", "SUPPORT", format ["Cleared future %1 stamp on %2", _x, name _player]] call fnc_log; };
                        };
                    } forEach _cooldownVars;
                };
            } forEach (call BIS_fnc_listPlayers);

            sleep 60; // 每分钟检查一次
        };
    };
};
// ======================================================
[] spawn fnc_createKillhouse;
if (!isServer) exitWith {};
