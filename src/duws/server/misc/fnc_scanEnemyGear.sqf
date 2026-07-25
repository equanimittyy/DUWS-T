// fnc_scanEnemyGear.sqf
// 功能：从现有及后续生成的 EAST 步兵身上直接抓取装备（一次性扫描 + 事件驱动，无性能损耗）
// 执行端：服务器
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
    DUWS_fnc_extractEnemyGear = {
        params ["_unit"];
        if (isNull _unit || {!alive _unit}) exitWith {};

        private _netId = netId _unit;
        if (DUWS_enemyGear_scannedUnits getOrDefault [_netId, false]) exitWith {};
        DUWS_enemyGear_scannedUnits set [_netId, true];

        private _uni = uniform _unit; if (_uni != "") then { DUWS_enemyUniforms pushBackUnique _uni; publicVariable "DUWS_enemyUniforms"; };
        private _vest = vest _unit; if (_vest != "") then { DUWS_enemyVests pushBackUnique _vest; publicVariable "DUWS_enemyVests"; };
        private _hg = headgear _unit; if (_hg != "") then { DUWS_enemyHeadgear pushBackUnique _hg; publicVariable "DUWS_enemyHeadgear"; };
        private _bp = backpack _unit; if (_bp != "") then { DUWS_enemyBackpacks pushBackUnique _bp; publicVariable "DUWS_enemyBackpacks"; };
        private _pw = primaryWeapon _unit; if (_pw != "") then { DUWS_enemyPrimaryWeapons pushBackUnique _pw; publicVariable "DUWS_enemyPrimaryWeapons"; };
        private _sw = secondaryWeapon _unit; if (_sw != "") then { DUWS_enemySecondaryWeapons pushBackUnique _sw; publicVariable "DUWS_enemySecondaryWeapons"; };
        private _hw = handgunWeapon _unit; if (_hw != "") then { DUWS_enemyHandguns pushBackUnique _hw; publicVariable "DUWS_enemyHandguns"; };

        {
            if (_x != "" && {_x call DUWS_fnc_isNVG}) then { DUWS_enemyNVGs pushBackUnique _x; publicVariable "DUWS_enemyNVGs"; };
        } forEach assignedItems _unit;
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
addMissionEventHandler ["EntityCreated", {
    params ["_entity"];
    if (!isServer) exitWith {};
    if (isNull _entity) exitWith {};
    [_entity] spawn {
        params ["_entity"];
        sleep 0.5;
        if (isNull _entity || {!alive _entity}) exitWith {};
        if (side _entity != EAST || {!(_entity isKindOf "CAManBase")}) exitWith {};
        [_entity] call DUWS_fnc_extractEnemyGear;
    };
}];