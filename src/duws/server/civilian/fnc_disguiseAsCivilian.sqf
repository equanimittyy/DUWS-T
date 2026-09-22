if (!isServer) exitWith {};

params ["_player"];
if (isNull _player) exitWith {};

// Refusals take DISGUISE_CANT_*, breaks take DISGUISE_BROKEN_* -- the two read as whole
// sentences from different frames, so a key never serves both paths.
fnc_disguise_hintFail = {
    params ["_player", "_reasonKey"];
    [localize _reasonKey] remoteExec ["hint", _player];
};
publicVariable "fnc_disguise_hintFail";

// Civilian by config, not by the scanned wardrobe: the uniform's linked unit carries side 3
// (TCivilian), so any civilian shirt passes -- including modded clothes and classes no spawned
// local happened to wear.
fnc_disguise_isCivUniform = {
    params ["_uniform"];
    if (_uniform == "") exitWith { false };
    private _unit = getText (configFile >> "CfgWeapons" >> _uniform >> "ItemInfo" >> "uniformClass");
    if (_unit == "") exitWith { false };
    getNumber (configFile >> "CfgVehicles" >> _unit >> "side") == 3
};

// Vests and headgear are CfgWeapons items with no side field, so they cannot be classed civilian
// by config the way the uniform is. An accessory reads civilian when the slot is empty, when a
// local civilian is seen wearing the class (the population scan, mod-adaptive), or when it is on a
// curated allowlist below.
fnc_disguise_isCivGear = {
    params ["_item", "_scanned", "_whitelist"];
    _item == "" || {_item in _scanned} || {_item in _whitelist}
};

// The kit rule the civilian activation refuses on and the shared monitor breaks on, as the suffix of
// its CANT_/BROKEN_ key, or "" when the kit passes. One function, so the two cannot drift: if they
// did, the disguise would activate and then break on the first tick.
fnc_disguise_civFault = {
    params ["_player"];
    if (primaryWeapon _player != "" || secondaryWeapon _player != "" || handgunWeapon _player != "") exitWith { "WEAPON" };
    private _assigned = assignedItems _player;
    if ("NVGoggles" in _assigned || "NVGoggles_OPFOR" in _assigned || "NVGoggles_INDEP" in _assigned) exitWith { "NVG" };
    if (uniform _player == "") exitWith { "NAKED" };
    if !([uniform _player] call fnc_disguise_isCivUniform) exitWith { "UNIFORM" };
    // Accessories must read civilian too, or a military plate carrier or helmet under a civilian
    // shirt would still pass.
    if !([vest _player, missionNamespace getVariable ["DUWS_civVests", []], DUWS_disguise_civVestWhitelist] call fnc_disguise_isCivGear) exitWith { "VEST" };
    if !([headgear _player, missionNamespace getVariable ["DUWS_civHeadgear", []], DUWS_disguise_civHeadgearWhitelist] call fnc_disguise_isCivGear) exitWith { "HEADGEAR" };
    if !([backpack _player, missionNamespace getVariable ["DUWS_civBackpacks", []], DUWS_disguise_civBackpackWhitelist] call fnc_disguise_isCivGear) exitWith { "BACKPACK" };
    if (vehicle _player != _player && {!(typeOf vehicle _player in DUWS_disguise_civVehicles)}) exitWith { "VEHICLE" };
    ""
};

fnc_disguise_enemyNear = {
    params ["_player", "_radius"];
    ((_player nearEntities [["CAManBase"], _radius]) findIf { side _x == EAST && alive _x }) >= 0
};

// Every OPFOR site, revealed or not: a hidden site streams in live, and a player who comes near reveals
// it anyway. Towns are in neither registry, so an OPFOR-held town stays safe.
fnc_disguise_atEnemySite = {
    params ["_pos", "_margin"];
    private _opforZones = missionNamespace getVariable ["WARCOM_zones_controled_by_OPFOR", []];
    private _atZone = (zone_meta_array findIf {
        (_pos distance2D (_x select 1)) < ((_x select 2) + _margin)
        && {private _key = str (_x select 1); (_opforZones findIf {str _x == _key}) >= 0}
    }) >= 0;
    _atZone || {(DUWS_hardpoints findIf {
        (_x select 3) isEqualTo "opfor" && {(_pos distance2D (_x select 1)) < _margin}
    }) >= 0}
};

// Curated civilian classes the population scan can miss: gear a player loots but no local NPC
// spawns wearing. Vanilla civilians almost never wear a vest, so the press vest is seeded to keep
// a safety/hi-viz style vest valid; add mod safety-vest classes here. Headgear/backpack lean on
// the scan (civilians do wear caps and civilian packs), so their allowlists start empty.
DUWS_disguise_civVestWhitelist = ["V_Press_F"];
DUWS_disguise_civHeadgearWhitelist = [];
DUWS_disguise_civBackpackWhitelist = [];

DUWS_disguise_civVehicles = [
    "C_Van_01_fuel_F", "C_Van_01_box_F", "C_Van_01_transport_F",
    "C_Tractor_01_F", "C_Hatchback_01_sport_F", "C_Hatchback_01_F",
    "C_Offroad_01_covered_F", "C_Offroad_01_comms_F", "C_Offroad_01_repair_F",
    "C_Offroad_01_F", "C_Van_02_transport_F", "C_Van_02_medevac_F",
    "C_Van_02_service_F", "C_Van_02_vehicle_F", "C_Offroad_02_unarmed_F",
    "C_Truck_02_fuel_F", "C_Truck_02_box_F", "C_Truck_02_covered_F",
    "C_Truck_02_transport_F"
];

private _blownAt = _player getVariable ["DUWS_disguise_blownAt", -300];
private _cooldownRemaining = 300 - (diag_tickTime - _blownAt);
if (_cooldownRemaining > 0) exitWith {
    private _minutes = floor (_cooldownRemaining / 60);
    private _seconds = floor (_cooldownRemaining % 60);
    private _msg = format [localize "STR_DUWS_T_DISGUISE_COOLDOWN_FMT", _minutes, _seconds];
    [_msg] remoteExec ["hint", _player];
};

if (_player getVariable ["DUWS_enemyDisguised", false]) exitWith {
    [_player, "STR_DUWS_T_DISGUISE_CANT_OTHER"] call fnc_disguise_hintFail;
};
if ([_player] call fnc_disguise_hunted || {([_player] call fnc_disguise_spotters) isNotEqualTo []}) exitWith {
    [_player, "STR_DUWS_T_DISGUISE_CANT_HUNTED"] call fnc_disguise_hintFail;
};
if ([_player, 50 + random 30] call fnc_disguise_enemyNear) exitWith {
    [_player, "STR_DUWS_T_DISGUISE_CANT_ENEMY_NEAR"] call fnc_disguise_hintFail;
};
if ([getPosATL _player, DISGUISE_CIV_SITE_MARGIN] call fnc_disguise_atEnemySite) exitWith {
    [_player, "STR_DUWS_T_DISGUISE_CANT_SITE"] call fnc_disguise_hintFail;
};

if (CIV_PRESENCE == "NONE") exitWith {
    [_player, "STR_DUWS_T_DISGUISE_CANT_NOCIV"] call fnc_disguise_hintFail;
};
if (CIV_PRESENCE == "RAVAGE" || CIV_PRESENCE == "WBK") exitWith {
    [_player, "STR_DUWS_T_DISGUISE_CANT_ZOMBIE"] call fnc_disguise_hintFail;
};

private _fault = [_player] call fnc_disguise_civFault;
if (_fault != "") exitWith {
    [_player, "STR_DUWS_T_DISGUISE_CANT_" + _fault] call fnc_disguise_hintFail;
};

_player setVariable ["DUWS_disguised", true, true];
_player setCaptive true;
[true] remoteExec ["fnc_disguise_setCaptiveLocal", _player];
_player setVariable ["DUWS_disguise_siteWarned", false];

[localize "STR_DUWS_T_DISGUISE_ACTIVATED_DESC"] remoteExec ["hint", _player];
[localize "STR_DUWS_T_DISGUISE_SUCCESS_HINT"] remoteExec ["hint", _player];

if (!(_player getVariable ["DUWS_disguise_monitorRunning", false])) then {
    _player setVariable ["DUWS_disguise_monitorRunning", true];
    [_player, "civ"] spawn fnc_disguise_monitor;
};
