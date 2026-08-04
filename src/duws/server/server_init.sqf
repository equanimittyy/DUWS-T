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

// Faction resolution answers the confirmation screen, which shows the player the classname each
// side will field for every role and is the last point they can change one -- so it cannot wait
// for the commit. Served in a loop rather than once: stepping back from the environment screen
// re-enters faction selection, and the screen asks again with the new pick. Both faction inits and
// all three AutoDetect wrappers are written to survive being called again.
// The condition below reads globals only: fnc_waitLogged calls the block in its own scope, so a
// private captured here would be undefined by the time it is evaluated. duws_faction_preview_ready
// doubles as the served marker, which is what the screen waits on anyway.
while {!createzone_server} do {
	while {!(["BOOT", "duws_faction_preview_request (confirmation screen opened)",
		{duws_faction_preview_request > duws_faction_preview_ready || createzone_server}, 600] call fnc_waitLogged)} do {};
	if (createzone_server) exitWith {};
	private _serving = duws_faction_preview_request;

	// wait for CUSTOM FACTIONS to be pasted
	["INFO", "BOOT", "Server waiting for BLU faction Data Temp"] call fnc_log;
	if (BLUFOR_FactionFile_X == "CUSTOM") then { while {!(["FACTION", "BLUfactionDataTemp pasted", {BLUfactionDataTemp != ""}, 300] call fnc_waitLogged)} do {}; };
	if (OPFOR_FactionFile_X == "CUSTOM") then { while {!(["FACTION", "OPFfactionDataTemp pasted", {OPFfactionDataTemp != ""}, 300] call fnc_waitLogged)} do {}; };

	// BLUFOR
	["INFO", "BOOT", format ["BLUFOR Faction init on server: %1", BLUFOR_FactionFile_X]] call fnc_log;

	if (BLUFOR_FactionFile_X == "CUSTOM") then {
		["blufor"] call fnc_custom_faction_init;
		while {!(["FACTION", "BLUfactionData populated", {count BLUfactionData > 0}, 300] call fnc_waitLogged)} do {};
	} else {
		[] call fnc_BLUFOR_faction_init;
	};
	["INFO", "BOOT", format ["Blufor Faction init on server complete.  Rifleman: %1", blufor_SOLDIER_X]] call fnc_log;
	["INFO", "BOOT", format ["Blufor Faction init on server complete.  blufor RQST VEHICLE 01: %1", (["VEHICLE"] call fnc_faction_rqst_list) param [0, "none"]]] call fnc_log;

	// OPFOR. Unguarded: the "opfor already resolved" check that used to wrap this pinned the first
	// resolution, which is wrong once stepping back can re-pick the faction.
	["INFO", "BOOT", format ["OPFOR Faction init on server: %1", OPFOR_FactionFile_X]] call fnc_log;

	if (OPFOR_FactionFile_X == "CUSTOM") then {
		["opfor"] call fnc_custom_faction_init;
		while {!(["FACTION", "OPFfactionData populated", {count OPFfactionData > 0}, 300] call fnc_waitLogged)} do {};
	} else {
		[] call fnc_OPFOR_faction_init;
	};
	["INFO", "BOOT", format ["Opfor Warcom Faction init on server complete.  Rifleman: %1", opfor_SOLDIER_X]] call fnc_log;
	["INFO", "BOOT", format ["Opfor Warcom Faction init on server complete.  Spec Ops: %1", opfor_SPECOPS_X]] call fnc_log;

	// Publish every role global the screen will show. AutoDetect broadcasts its own and a CUSTOM
	// paste ships its assignment list, but a static faction file only assigns server-side and the
	// OPFOR file is never run on a client at all -- so without this the screen would paint whatever
	// that machine happened to hold rather than what the server just resolved.
	{
		private _side = _x;
		{ missionNamespace setVariable [_x select 0, missionNamespace getVariable [_x select 0, ""], true]; }
			forEach ([_side] call fnc_faction_schema);
	} forEach ["blufor", "opfor"];

	// Answers the request by number, so the screen can tell this round's rows from the last one's.
	duws_faction_preview_ready = _serving;
	publicVariable "duws_faction_preview_ready";
};

// HQ build stays behind the commit so Back navigation still finds nothing built to unwind.
// Everything below consumes only PosOfBLUHQ (set at placement) until this gate; verified no
// HQ-object read sits before it.
while {!(["BOOT", "createzone_server (setup screens committed)", {createzone_server}, 300] call fnc_waitLogged)} do {};

// HQ placement runs after the confirmation screen now, so this cannot gate the resolution loop
// above: the screen waits on a resolution that would be waiting on a placement the player has not
// been offered yet. Kept as a guard here, where PosOfBLUHQ is about to be read for real.
while {!(["BOOT", "chosen_hq_placement (player is placing HQ)", {chosen_hq_placement}, 300] call fnc_waitLogged)} do {};

// The player's edits from the confirmation screen, laid over what resolution produced.
[] call fnc_faction_apply_locked;

// Squads compose from the role globals, so they are built after the edits land rather than
// beside the resolution that produced them.
[] call fnc_BLUFOR_squad_init;
["INFO", "BOOT", format ["blufor RECON_TEAM: %1", str blufor_RECON_TEAM_X]] call fnc_log;
[] call fnc_OPFOR_squad_init;
["INFO", "BOOT", format ["opfor INF_TEAM: %1", str opfor_INFTEAM_X]] call fnc_log;

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
                // A card, not a hint, and deliberately the exception to the surface rule in
                // docs/info/player_facing_text.md: that rule sends a one-player message to the hint
                // box, and this is addressed at one player. CP arriving speaks the card vocabulary
                // its siblings cpaddedmission and apaddedmission already own -- moving it would make
                // kill income the only income that looks like a refusal. It is also the payoff for
                // half an hour of fighting, and it fires on the economy tick, so it is neither
                // frequent enough to be noise nor small enough to bury in the corner.
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
// Paced, not idle: generation signs off by typing MISSION INITIALIZATION COMPLETE across every
// screen and hinting the settings summary (warcom/fnc_init_OPFOR_WARCOM.sqf), both fired the instant
// mission_init_complete goes up, and the intro's first act is to black the screen over them. Flying
// as soon as the clients were ready cut the typing off about a second into a six-second run.
sleep 15;

// The pause above does not replace this: the intro remoteExecs a seat onto each client, so every
// player must be holding client_init's fnc_remoteBoard before it flies. Bounded and not retried --
// one client stuck short of that line must not hold the flight for everybody else. The count test is
// load-bearing: findIf over an empty allPlayers returns -1, so an empty list would pass on sight.
["BOOT", "duws_intro_ready on every player",
    {count allPlayers > 0
        && {(allPlayers findIf {!(_x getVariable ["duws_intro_ready", false])}) isEqualTo -1}}, 60] call fnc_waitLogged;
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
