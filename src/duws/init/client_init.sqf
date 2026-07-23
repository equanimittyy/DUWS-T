diag_log format ["Client_init: %1", profileName];
fnc_hirePartisans_clientMap = compile preprocessFileLineNumbers "duws\functions\misc\fnc_hirePartisans_clientMap.sqf";
publicVariable "fnc_hirePartisans_clientMap";
///////////////////////
// DUWS_T Client INIT
///////////////////////
setGroupIconsVisible [true,false]; //now everyone can see enemies on map
// BLACK SCREEN
titleCut ["", "BLACK FADED", 999];
waitUntil {sleep 0.1;!isNull player};
// Host waits for Server init
//if (isServer) then {
	waitUntil {sleep 0.1;serverinit_complete};
//};
player addRating 10000000;
// KEEP DIPSHITS FROM DROWNING
[] spawn {
	while {!WARCOM_init_done} do {
		player setOxygenRemaining 1;
		sleep 10;
	};
};
// 客户端登机函数（建议放在 client_init.sqf 中）
fnc_remoteBoard = {
    params ["_heliNetId", "_seatType", "_player"];
    if (_player != player) exitWith {}; // 确保是自己
    private _heli = objectFromNetId _heliNetId;
    if (isNull _heli) exitWith { diag_log "[INTRO] Remote board: helicopter not found."; };
    switch (_seatType) do {
        case "cargo": {
            player assignAsCargo _heli;
            player moveInCargo _heli;
        };
        case "gunner": {
            player assignAsGunner _heli;
            player moveInGunner _heli;
        };
        case "commander": {
            player assignAsCommander _heli;
            player moveInCommander _heli;
        };
    };
    diag_log format ["[INTRO] Client %1 boarded helicopter as %2", name player, _seatType];
};
publicVariable "fnc_remoteBoard";
// Set GameMaster
if (!isMultiplayer) then {
	game_master = vehiclevarname player;
};

#include "..\includes\supports_init.hpp"
#include "..\includes\squad_number_init.hpp"

// VERSION specific inits
switch (VERSION_X) do {
	case "MODERN": {
		// Create "firedNear" event for players
		// - if enemy present, play music
		// [] spawn fnc_dyn_music_init;
		
		// AMBIANCE LOOP
		[] spawn fnc_ambient_musicloop;
	};
};

// JIP SCREEN, open map
if (isMultiplayer) then {
	
	if (((vehiclevarname player) != "player1" && !WARCOM_init_done) || WARCOM_init_done) then {
		//titleCut ["", "BLACK FADED", 999];
		diag_log format ["%1 Init %2", profileName,(vehiclevarname player)];
		titleCut ["", "BLACK IN", 10];
		forceMap true;
		mapAnimAdd [3, 1, [5000,5000]];
		mapAnimCommit;
		sleep 3;
		openMap [true, true];
	};

};

//////////////////////
// GAMEMASTER DIALOG
//////////////////////
if (((vehiclevarname player) in game_master) && !HQ_pos_found_generated) then {

	// Faction + HQ placement + custom-faction paste + environment menu are owned
	// by fnc_startup_faction_flow (called at the enviro spawn point below) so the
	// environment screen's Back button can re-enter them to re-pick faction/HQ.

	//  ZONE SETTINGS DIALOG
	if (!zones_created) then {

		//titleCut ["", "BLACK FADED", 999];

		// SHOW THE STARTUP ENVIRO MENU
		if (!zones_created) then {
			sleep 0.1;
			[] call fnc_startup_faction_flow;
			waitUntil {sleep 0.1;chosen_settings};  // WAIT UNTIL THE PLAYER HAS CHOSEN THE SETTINGS
			//titleCut ["", "BLACK IN", 10];
		};
	};
};

// Open Map for Gamemaster (Random Zones)
if ((vehiclevarname player) in game_master && !manually_chosen) then {
	//titleCut ["", "BLACK FADED", 999];
	titleCut ["", "BLACK IN", 10];
	forceMap true;
	mapAnimAdd [3, 1, PosOfBLUHQ];
	mapAnimCommit;
	sleep 3;
	openMap [true, true];
};

waitUntil {isPlayer Player};

///////////////////////////////////////////////
// Game Master: wait for Zones to start init 
// or JIP: update map screen
///////////////////////////////////////////////
if (((vehiclevarname player) in game_master)) then {
	waitUntil {sleep 0.1;count serv_zones_array > 0};
	//titleCut ["", "BLACK FADED", 999];
} else {
	if (!WARCOM_init_done) then {
		hintsilent "Waiting for serverinit_complete";
		waitUntil {sleep 0.1;serverinit_complete};
		waitUntil {
			hintsilent localize "STR_DUWS_T_waithostsetup";
			sleep 5;
			HQ_pos_found_generated && chosen_settings
		};
	};
};

////////////////////////
//  WAIT FOR WARCOM 
////////////////////////
waituntil {sleep 1;WARCOM_init_done;};

// Draw the HQ icon on map
[] spawn fnc_draw_HQicon;


//////////////////////////
//  JIP CODE
//////////////////////////

if (isMultiplayer) then {

	// change the shown CP for request dialog
	"commandpointsblu1" addPublicVariableEventHandler {ctrlSetText [1000, format["%1",commandpointsblu1]]; };
	
	///////////////////////////////////////////
	// Initialize the BLUFOR FACTION for JIP
	///////////////////////////////////////////
	diag_log format ["BLUFOR Faction init for JIP: %1", BLUFOR_Faction_X];
	if (BLUFOR_Faction_X == "CUSTOM") then {
		waitUntil {sleep 0.1;count BLUfactionData > 0};
		{
			call compile _x;
		} forEach BLUfactionData;
	} else {
		[] call fnc_BLUFOR_FactionFile_X;
	};
	sleep 1;
	diag_log format ["Blufor Faction init for JIP complete.  Rifleman: %1", blufor_SOLDIER_X];

};

// CP Death Penalty EventHandler (killhouse 内免罚)
PlayerKilledEH = player addEventHandler ["killed", {
    private _inKillhouse = false;
    private _khX = missionNamespace getVariable ["killhouse_centerX", nil];
    private _khY = missionNamespace getVariable ["killhouse_centerY", nil];
    private _khZ = missionNamespace getVariable ["killhouse_centerZ", nil];
    if (!isNil "_khX" && !isNil "_khY" && !isNil "_khZ") then {
        private _deathPos = getPosWorld (_this select 0); // 死亡单位位置
        if (_deathPos distance [_khX, _khY, _khZ] < 300) then {
            _inKillhouse = true;
        };
    };
    if (!_inKillhouse) then {
        commandpointsblu1 = commandpointsblu1 - DUWSMP_CP_death_cost;
        publicVariable "commandpointsblu1";
    };
    [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_playerdown"] remoteExec ["BIS_fnc_showSubtitle", 0];
}];

// ENABLE STAMINA (forced on)
player_fatigue = 1;
player enableStamina true;
// init the extras for REQUEST players (squad leads)
if ((vehiclevarname player) in Request_Players) then {
	player setUnitTrait ["Medic",true];
	player setUnitTrait ["Engineer",true];
	player setUnitTrait ["uavHacker",true];
	// wait until blu captures at least one zone
	[] spawn fnc_zones_bonus;
	// INIT the max support variable
	support_count = 0;
	//INIT HC module
	diag_log "HC init";
	[] spawn fnc_hc_init;
};

/////////////////////////////
// INIT the operative list
////////////////////////////

[] spawn fnc_operator_init;


// INIT Markers if difficulty < veteran
_difficulty_setting = difficulty;
[] call fnc_kndr_unit_markers;
if (_difficulty_setting < 2 || (difficultyOption "mapContentFriendly") == 1) then { 
	if (isMultiplayer) then {
		["players"] spawn fnc_player_markers;
	};
};

// INIT Earplugs
AddEarplugsEH = player addEventHandler ["GetinMan", {
    toggle_earplugs = player addaction [localize "STR_DUWS_T_2rc0nvug",fnc_earplugs, "", 0, true, true, "", "_this == player"];
}];
RemoveEarplugsEH = player addEventHandler ["GetoutMan", {
    player removeAction toggle_earplugs;
if (soundVolume == 0.3) then {hint localize "STR_DUWS_T_gut0c4f8"};
	5 fadesound 1;
}];

// Create Diary/Help entry on the Map
[] spawn fnc_duws_help;

// INIT R3F Logistics
//execVM "modules\R3F_LOG\init.sqf";

// Add HQ actions for REQUEST Players
[bluHQ_object] spawn fnc_HQaddactions;

if ((vehiclevarname player) in game_master) then {
	sleep 10;
} else {
	sleep 10;
};

////////////////////////
// TELEPORT PLAYER
////////////////////////

hint localize "STR_DUWS_T_zu4bxt24";

// ========== 换装：从基地守卫中随机复制战斗单位装备（白名单版）==========
[] spawn {
    waitUntil { sleep 0.5; !isNil "PosOfBLUHQ" && {count PosOfBLUHQ > 0} };
    sleep 8;  // 等待基地守卫、巡逻队生成完毕

    // 读取基地守卫兵种池（由 fnc_BluHQinit 设置并广播）
    private _guardTypes = missionNamespace getVariable ["HQ_redeploy_guardTypes", [
        blufor_SOLDIER_X, blufor_SOLDIER_LAT_X, blufor_SOLDIER_GL_X,
        blufor_SOLDIER_TL_X, blufor_SOLDIER_SL_X, blufor_SOLDIER_AR_X,
        blufor_MARKSMAN_X
    ]];

    private _nearbyUnits = nearestObjects [PosOfBLUHQ, ["CAManBase"], 150] select {
        side _x == WEST && alive _x && !isPlayer _x
    };

    // 只保留兵种池内的战斗单位
    private _combatUnits = _nearbyUnits select { typeOf _x in _guardTypes };

    if (count _combatUnits > 0) then {
        private _template = selectRandom _combatUnits;
        player setUnitLoadout (getUnitLoadout _template);
    } else {
        systemChat "未找到可复制的战斗单位，保留默认装备。";
    };
};

sleep 5;
_currVolume = musicVolume;
titleCut ["", "BLACK FADED", 999];
sleep 5;

// close map
forceMap false;
sleep 1;
openMap [false, false];
// ========== 丧尸模式强制客户端薄雾 ==========
if (CIV_PRESENCE == "RAVAGE") then {
    // 等待玩家完全就绪
    waitUntil {!isNull player};
    // 设置薄雾：强度0.5，衰减0.1，基准高度10
    0 setFog [0.5, 0.1, 10];
    0 setOvercast 0.8;
    forceWeatherChange;
    diag_log "[CLIENT INIT] RAVAGE mode: Client-side fog forced.";
};if (CIV_PRESENCE == "WBK") then {
    // 等待玩家完全就绪
    waitUntil {!isNull player};
    // 设置薄雾：强度0.5，衰减0.1，基准高度10
    0 setFog [0.5, 0.1, 10];
    0 setOvercast 0.8;
    forceWeatherChange;
    diag_log "[CLIENT INIT] WBK mode: Client-side fog forced.";
};
// 等待末日模式变量同步
waitUntil {!isNil "apocalypse_mode"};

// 定义应用滤镜的函数（以便重生后调用）
DUWS_fnc_applyApocalypseFilter = {
    // 清除可能存在的旧效果（使用唯一ID）
    private _idCC = 15001;
    private _idGrain = 15002;
    private _idBlur = 15003;
    
    ppEffectDestroy _idCC;
    ppEffectDestroy _idGrain;
    ppEffectDestroy _idBlur;
    
    // 1. 色彩校正（强末日色调）
    private _cc = ppEffectCreate ["ColorCorrections", _idCC];
    _cc ppEffectEnable true;
    _cc ppEffectAdjust [
        0.7,        // 亮度降低
        1.2,        // 高对比度
        0.0,        // 偏移
        [0,0,0,0],  // 起始混合
        [1.0,0.5,0.2,0.9], // 强橙红色调（A=0.9表示强度很高）
        [0.9,0.9,0.9,0.0]  // 高度去饱和度（几乎黑白，但保留一点色调）
    ];
    _cc ppEffectCommit 0;

    // 2. 轻微模糊边缘模拟暗角（或使用ChromAberration？但此处用动态模糊简单替代）
    private _blur = ppEffectCreate ["DynamicBlur", _idBlur];
    _blur ppEffectEnable true;
    _blur ppEffectAdjust [0.02];
    _blur ppEffectCommit 0;

    diag_log "[Apocalypse] Aggressive filters applied.";
};

// 如果开启末日模式，立即应用滤镜
if (apocalypse_mode) then {
    call DUWS_fnc_applyApocalypseFilter;
};

// 监听公共变量变化（以便 JIP 或中途开启时应用）
"apocalypse_mode" addPublicVariableEventHandler {
    if (_this select 1) then {
        call DUWS_fnc_applyApocalypseFilter;
    } else {
        // 如果关闭，可清除滤镜（可选）
        ppEffectDestroy 15001;
        ppEffectDestroy 15002;
        ppEffectDestroy 15003;
    };
};

// =============================================
if (CIV_PRESENCE == "RAVAGE") then {
    ["biohazard", [localize "STR_DUWS_T_ravage", localize "STR_DUWS_T_ZOMBIE_NOREP"]] remoteExec ["BIS_fnc_showNotification", 0];
};
if (CIV_PRESENCE == "WBK") then {
    ["biohazard", [localize "STR_DUWS_T_wbk", localize "STR_DUWS_T_WBK_NOREP"]] remoteExec ["BIS_fnc_showNotification", 0];
};
// 焦土模式开局提醒
if (!isNil "scorched_earth_enabled" && scorched_earth_enabled && (vehiclevarname player) == "player1") then {
    ["SE", [localize "STR_DUWS_T_scorched_earth_effect1", localize "STR_DUWS_T_scorched_earth_effect3"]] remoteExec ["BIS_fnc_showNotification", 0];
};
// 等待索降完成标志
waitUntil { sleep 0.2; !isNil "intro_heli_done" };

// 如果玩家尚未完成索降流程（即 intro_completed 未设置为 true），则传送
if !(player getVariable ["intro_completed", false]) then {
    private _safePos = [PosOfBLUHQ, 0, 30, 3, 0, 0.2, 0] call BIS_fnc_findSafePos;
    if (_safePos isEqualTo [0,0,0]) then {
        _safePos = PosOfBLUHQ getPos [random 10, random 360];
    };
    player setPos _safePos;
	[["", "BLACK IN", 2]] remoteExec ["titleCut", player];
    player setVariable ["intro_completed", true];
    diag_log format ["[JIP] Teleported %1 to base.", name player];
};

// 空降完成后，播放音乐和欢迎信息
playMusic ["EventTrack01a_F_EPA", 0];
hintsilent format[localize "STR_DUWS_T_ix8g2neb",worldName,profileName];

// 确保天气渲染正常（强制更新）
forceWeatherChange;

player setVariable["Saved_Loadout", getUnitLoadout player];
player setdamage 0;	
player allowDamage true;
// Zeus disconnect fix and Add SITREP to Gamemaster	
if ((vehiclevarname player) in game_master || !isMultiplayer) then {
	// Zeus disconnect fix
	[Curator] remoteExec ["unassignCurator",2];
	sleep 2;
	[player, Curator] remoteExec ["assignCurator",2];
	[] spawn {
		sleep 10;
		_sitrep = [player,"sitrep"] call BIS_fnc_addCommMenuItem;
	};
};

if (hasInterface) then {
    // 初始化变量（使用 diag_tickTime）
    player setVariable ["shotCount", 0];
    player setVariable ["shotTimer", diag_tickTime];
    player setVariable ["flare_lastTime", -999];

    // 监听玩家开火（滑动窗口 1 秒）
    player addEventHandler ["Fired", {
        params ["_unit"];
        private _now = diag_tickTime;
        private _last = _unit getVariable ["shotTimer", _now];
        if (_now - _last < 1) then {
            _unit setVariable ["shotCount", (_unit getVariable ["shotCount", 0]) + 1];
        } else {
            _unit setVariable ["shotCount", 1];
        };
        _unit setVariable ["shotTimer", _now];
    }];

    // 主循环
    [] spawn {
        while {true} do {
            sleep 10;
            if (!alive player) then { continue };

            // 仅在夜间触发（20:00 - 05:00）
            if ((daytime > 20) or (daytime < 5)) then {
                private _now = diag_tickTime;
                private _last = player getVariable ["flare_lastTime", -999];
                
                // 冷却时间 60 秒（基于 diag_tickTime）
                if (_now - _last < 60) then { continue };

                // 获取附近 200 米内的敌人和友军（假设敌方 EAST，友军 WEST）
                private _nearUnits = nearestObjects [player, ["CAManBase"], 200];
                private _enemies = _nearUnits select { side _x == EAST && alive _x };
                private _friendlies = _nearUnits select { side _x == WEST && alive _x };

                // 开火次数
                private _shots = player getVariable ["shotCount", 0];

                // 触发条件：1秒内开火 ≥4 次，且敌人数量 > 友军数量
                if (_shots >= 4 && (count _enemies) > (count _friendlies)) then {
                    // 记录触发时间并重置计数
                    player setVariable ["flare_lastTime", _now];
                    player setVariable ["shotCount", 0];
					playSound "Sound_Shot_UGL";
					sleep 3;
					playSound "Sound_Shot_UGL";
					sleep 2;
					playSound "Sound_Shot_UGL";
                    // 生成照明弹：玩家周围 40 米内随机水平位置，高度 50~100 米
                    private _flarePos = player getPos [random 40, random 360];
                    _flarePos set [2, 100 + random 50];
                    [_flarePos] remoteExec ["my_fnc_createFlare", 2];
                    
                };
            };
        };
    };
};
sleep 20;
// 在客户端添加基础装备
fnc_disguise_addGear = {
    { player addItem _x; player assignItem _x; } forEach ["ItemMap", "ItemGPS", "ItemRadio", "ItemCompass", "ItemWatch"];
};
publicVariable "fnc_disguise_addGear";
// ========== 为玩家添加伪装长按动作（带防重，不自动移除） ==========
if (CIV_PRESENCE != "RAVAGE" && CIV_PRESENCE != "WBK") then {
    if (isNil {player getVariable "DUWS_disguise_actionAdded"}) then {
        [
            player,
            localize "STR_DUWS_T_DISGUISE_CIV",
            "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_hack_ca.paa",
            "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_hack_ca.paa",
            "alive _target && vehicle _target == _target",
            "alive _target && vehicle _target == _target",
            {
                params ["_target", "_caller", "_actionId", "_arguments"];
                [localize "STR_DUWS_T_DISGUISE_START"] remoteExec ["hint", _caller];
                [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_DISGUISE_START_SUB"] remoteExec ["BIS_fnc_showSubtitle", _caller];
            },
            {},
            {
                params ["_target", "_caller", "_actionId", "_arguments"];
                [_caller] remoteExec ["fnc_disguiseAsCivilian", 2];
            },
            {},
            [],
            3,
            0,
            false,  // 改为 false，完成后不移除动作
            false
        ] call BIS_fnc_holdActionAdd;
        player setVariable ["DUWS_disguise_actionAdded", true];
    };
};
// 伪装专用：本地设置俘虏状态
fnc_disguise_setCaptiveLocal = {
    params ["_state"];
    player setCaptive _state;
    diag_log format ["[DISGUISE] Client setCaptive %1 for %2", _state, name player];
};
publicVariable "fnc_disguise_setCaptiveLocal";

// ========== 为玩家添加伪装成敌人长按动作 ==========
if (isNil {player getVariable "DUWS_enemyDisguise_actionAdded"}) then {
    [
        player,
        localize "STR_DUWS_T_ENEMY_DISGUISE_ACTION",
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_unbind_ca.paa",
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_unbind_ca.paa",
        "alive _target && vehicle _target == _target",
        "alive _target && vehicle _target == _target",
        {
            params ["_target", "_caller", "_actionId", "_arguments"];
            [localize "STR_DUWS_T_ENEMY_DISGUISE_START"] remoteExec ["hint", _caller];
            [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_ENEMY_DISGUISE_START_SUB"] remoteExec ["BIS_fnc_showSubtitle", _caller];
        },
        {},
        {
            params ["_target", "_caller", "_actionId", "_arguments"];
            [_caller] remoteExec ["fnc_disguiseAsEnemy", 2];
        },
        {},
        [],
        3,
        0,
        false,
        false
    ] call BIS_fnc_holdActionAdd;
    player setVariable ["DUWS_enemyDisguise_actionAdded", true];
};
