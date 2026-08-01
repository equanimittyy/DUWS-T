if (!isServer) exitWith {};

["INFO", "GEAR", "Starting fixed enemy gear scan (global function + delayed init)."] call fnc_log;

// 初始化全局变量
if (isNil "DUWS_enemyUniforms") then { DUWS_enemyUniforms = []; };
if (isNil "DUWS_enemyVests") then { DUWS_enemyVests = []; };
if (isNil "DUWS_enemyHeadgear") then { DUWS_enemyHeadgear = []; };
if (isNil "DUWS_enemyBackpacks") then { DUWS_enemyBackpacks = []; };
if (isNil "DUWS_enemyPrimaryWeapons") then { DUWS_enemyPrimaryWeapons = []; };
if (isNil "DUWS_enemySecondaryWeapons") then { DUWS_enemySecondaryWeapons = []; };
if (isNil "DUWS_enemyHandguns") then { DUWS_enemyHandguns = []; };
if (isNil "DUWS_enemyNVGs") then { DUWS_enemyNVGs = []; };

// 去重用哈希表（全局可见）
if (isNil "DUWS_enemyGear_scannedUnits") then { DUWS_enemyGear_scannedUnits = createHashMap; };

// 夜视镜判断（全局函数）
if (isNil "DUWS_fnc_isNVG") then {
    DUWS_fnc_isNVG = {
        (toLowerANSI _this find "nvg" != -1) || {getText (configFile >> "CfgWeapons" >> _this >> "simulation") == "nvgoggles"}
    };
};

// 定义全局提取函数（关键修复）
if (isNil "DUWS_fnc_extractEnemyGear") then {
    // Returns whether this unit taught the tables anything, which is what lets the spawn handler
    // below retire itself. Each category broadcasts only when it actually gained an entry: the
    // unconditional publish this replaces sent all eight arrays to every client for every enemy
    // scanned, long after they had stopped changing.
    DUWS_fnc_extractEnemyGear = {
        params ["_unit"];
        if (isNull _unit || {!alive _unit}) exitWith {false};

        private _netId = netId _unit;
        if (DUWS_enemyGear_scannedUnits getOrDefault [_netId, false]) exitWith {false};
        DUWS_enemyGear_scannedUnits set [_netId, true];

        private _added = false;
        private _uni = uniform _unit; if (_uni != "" && {!(_uni in DUWS_enemyUniforms)}) then { DUWS_enemyUniforms pushBack _uni; publicVariable "DUWS_enemyUniforms"; _added = true; };
        private _vest = vest _unit; if (_vest != "" && {!(_vest in DUWS_enemyVests)}) then { DUWS_enemyVests pushBack _vest; publicVariable "DUWS_enemyVests"; _added = true; };
        private _hg = headgear _unit; if (_hg != "" && {!(_hg in DUWS_enemyHeadgear)}) then { DUWS_enemyHeadgear pushBack _hg; publicVariable "DUWS_enemyHeadgear"; _added = true; };
        private _bp = backpack _unit; if (_bp != "" && {!(_bp in DUWS_enemyBackpacks)}) then { DUWS_enemyBackpacks pushBack _bp; publicVariable "DUWS_enemyBackpacks"; _added = true; };
        private _pw = primaryWeapon _unit; if (_pw != "" && {!(_pw in DUWS_enemyPrimaryWeapons)}) then { DUWS_enemyPrimaryWeapons pushBack _pw; publicVariable "DUWS_enemyPrimaryWeapons"; _added = true; };
        private _sw = secondaryWeapon _unit; if (_sw != "" && {!(_sw in DUWS_enemySecondaryWeapons)}) then { DUWS_enemySecondaryWeapons pushBack _sw; publicVariable "DUWS_enemySecondaryWeapons"; _added = true; };
        private _hw = handgunWeapon _unit; if (_hw != "" && {!(_hw in DUWS_enemyHandguns)}) then { DUWS_enemyHandguns pushBack _hw; publicVariable "DUWS_enemyHandguns"; _added = true; };

        {
            if (_x != "" && {_x call DUWS_fnc_isNVG} && {!(_x in DUWS_enemyNVGs)}) then { DUWS_enemyNVGs pushBack _x; publicVariable "DUWS_enemyNVGs"; _added = true; };
        } forEach assignedItems _unit;

        _added
    };
};

// 公开这些全局函数/变量，确保 JIP 和事件处理程序可用
publicVariable "DUWS_fnc_extractEnemyGear";
publicVariable "DUWS_fnc_isNVG";
publicVariable "DUWS_enemyGear_scannedUnits";

// 一次性扫描（等待 WARCOM 初始化完成，并额外延迟 15 秒确保单位已生成）
[] spawn {
    waitUntil { sleep 5; !isNil "WARCOM_init_done" && {WARCOM_init_done} };
    ["INFO", "GEAR", "WARCOM init done, waiting 15s for units to spawn..."] call fnc_log;
    sleep 15;

    ["INFO", "GEAR", "Performing initial gear collection from all EAST units."] call fnc_log;
    {
        if (side _x == EAST && {alive _x} && {_x isKindOf "CAManBase"}) then {
            [_x] call DUWS_fnc_extractEnemyGear;
        };
    } forEach allUnits;

    ["INFO", "GEAR", format ["enemy gear collected. Uniforms=%1 Vests=%2 Headgear=%3 Backpacks=%4",
        count DUWS_enemyUniforms, count DUWS_enemyVests, count DUWS_enemyHeadgear, count DUWS_enemyBackpacks]] call fnc_log;
};

// 事件监听：后续新单位
// The tables converge within the campaign's first minutes -- every EAST unit after that draws from
// the same faction lists -- so without a stop this handler goes on spawning a script per soldier
// for the rest of the session to learn nothing. Retired once this many consecutive units file
// nothing new, which is long enough to survive a faction the campaign meets late.
#define GEAR_CONVERGED_AFTER 200

DUWS_enemyGear_dryStreak = 0;
DUWS_enemyGear_scanEH = addMissionEventHandler ["EntityCreated", {
    params ["_entity"];
    if (!isServer) exitWith {};
    if (isNull _entity) exitWith {};
    // Class filter before the spawn, not inside it. This fires for every entity in the mission
    // -- vehicles, crates, and one weapon holder per rifle dropped in a firefight -- and the
    // handler runs unscheduled, so spawning a script per entity only to discover it is not a
    // soldier puts that allocation on the frame. Side stays inside: it comes from the group and
    // is not worth trusting this early, whereas the class is fixed at creation.
    if !(_entity isKindOf "CAManBase") exitWith {};
    [_entity] spawn {
        params ["_entity"];
        sleep 0.5;
        if (isNull _entity || {!alive _entity}) exitWith {};
        if (side _entity != EAST) exitWith {};
        // A unit already scanned reports nothing new, which is correct: re-seeing one is as much
        // evidence of convergence as meeting a fresh soldier in known kit.
        if ([_entity] call DUWS_fnc_extractEnemyGear) exitWith { DUWS_enemyGear_dryStreak = 0 };
        DUWS_enemyGear_dryStreak = DUWS_enemyGear_dryStreak + 1;
        if (DUWS_enemyGear_dryStreak >= GEAR_CONVERGED_AFTER) then {
            removeMissionEventHandler ["EntityCreated", DUWS_enemyGear_scanEH];
            ["INFO", "GEAR", format ["gear tables unchanged over %1 consecutive units; scan retired",
                GEAR_CONVERGED_AFTER]] call fnc_log;
        };
    };
}];