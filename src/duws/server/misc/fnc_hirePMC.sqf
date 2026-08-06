if (!isServer) exitWith {};

params ["_caller"];
if (isNull _caller) exitWith {};

private _cooldownVar = "DUWS_hirePMC_lastUse";
private _lastUse = _caller getVariable [_cooldownVar, -900];
private _cooldownRemaining = 900 - (diag_tickTime - _lastUse);
// Hints, where the squad arriving below is a card: a refusal answers the one player who
// clicked and the hire is news for the team (docs/info/player_facing_text.md).
if (_cooldownRemaining > 0) exitWith {
    private _minutes = floor (_cooldownRemaining / 60);
    private _seconds = floor (_cooldownRemaining % 60);
    private _msg = format [localize "STR_DUWS_T_HIRE_PMC_COOLDOWN", _minutes, _seconds];
    [_msg] remoteExec ["hint", _caller];
};

if !([_caller, 15] call fnc_coins_spend) exitWith {
    private _msg = localize "STR_DUWS_T_NOT_ENOUGH_MONEY_15";
    [_msg] remoteExec ["hint", _caller];
};

_caller setVariable [_cooldownVar, diag_tickTime, true];

private _count = 6;

private _hqPos = missionNamespace getVariable ["PosOfBLUHQ", getPos _caller];

private _spawnPos = [];
for "_i" from 1 to 20 do {
    private _angle = random 360;
    private _dist = 30 + random 70;
    private _candidate = _hqPos getPos [_dist, _angle];
    private _safe = [_candidate, 0, 20, 5, 0, 0.2, 0] call BIS_fnc_findSafePos;
    if !(_safe isEqualTo [0,0,0]) exitWith { _spawnPos = _safe; };
};
if (_spawnPos isEqualTo []) then { _spawnPos = _hqPos getPos [50, random 360]; };

waitUntil { !isNil "civ_array" && {count civ_array > 0} };
private _civArray = +civ_array;

private _unitClasses = [];
for "_i" from 1 to _count do {
    _unitClasses pushBack (selectRandom _civArray);
};

private _group = [_spawnPos, WEST, _unitClasses, [], [], [0.7, 0.8]] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
private _units = units _group;

private _uniforms = [
    "U_I_G_resistanceLeader_F",
    "U_BG_Guerilla2_1",
    "U_BG_Guerilla2_2",
    "U_BG_Guerilla2_3",
    "U_Rangemaster",
    "U_I_L_Uniform_01_tshirt_skull_F",
    "U_I_L_Uniform_01_tshirt_black_F",
    "U_C_ArtTShirt_01_v4_F",
    "U_C_ArtTShirt_01_v5_F",
    "U_C_FormalSuit_01_tshirt_black_F"
];
private _vests = [
    "V_TacVestIR_blk",
    "V_I_G_resistanceLeader_F",
    "V_TacVest_blk",
    "V_PlateCarrier2_blk",
    "V_PlateCarrier2_blk"
];
private _backpacks = [
    "B_AssaultPack_blk",
    "B_RadioBag_01_black_F",
    "B_Messenger_black_F"
];
private _headgear = [
    "H_Watchcap_blk",
    "H_Watchcap_khk",
    "H_Watchcap_camo",
    "H_Booniehat_khk_hs",
    "H_Cap_Lyfe",
    "H_Cap_MaldenTours",
    "H_Cap_blk_CMMG",
    "H_Cap_blk_ION",
    "H_HelmetB_light_black",
    "H_PASGT_basic_black_F"
];
private _facewear = [
    "G_Aviator",
    "G_Shades_Black",
    "G_Shades_Red",
    "G_Shades_Blue",
    "G_Tactical_Black",
    "G_Tactical_Clear"
];
private _primaryWeapons = [
    "SMG_03C_black",
    "SMG_03C_khaki",
    "SMG_03C_TR_black",
    "SMG_03C_TR_khaki",
    "srifle_GM6_F",
    "srifle_LRR_F",
    "srifle_EBR_F",
    "arifle_Mk20_plain_F",
    "arifle_Mk20_GL_plain_F",
    "arifle_Mk20C_plain_F",
    "SMG_02_F",
    "arifle_SPAR_01_blk_F",
    "arifle_SPAR_01_GL_blk_F",
    "arifle_SPAR_02_blk_F",
    "arifle_SPAR_03_blk_F"
];
private _launchers = [
    "launch_RPG7_F",
    "launch_I_Titan_short_F",
    "launch_B_Titan_F"
];
private _launcherAmmo = createHashMapFromArray [
    ["launch_RPG7_F", "RPG7_F"],
    ["launch_I_Titan_short_F", "Titan_AT"],
    ["launch_B_Titan_F", "Titan_AT"]
];

private _basicAmmoArray = [] call fnc_basic_ammo_lists;
private _opticsList = _basicAmmoArray select 4; // _basic_optics
if (isNil "_opticsList") then { _opticsList = [] };

private _fnc_addAttachments = {
    params ["_unit", "_weapon"];
    private _num = floor random 4;
    for "_i" from 1 to _num do {
        private _attach = selectRandom _opticsList;
        _unit addPrimaryWeaponItem _attach;
    };
};

{
    _x forceAddUniform (selectRandom _uniforms);

    _x addVest (selectRandom _vests);

    private _primary = selectRandom _primaryWeapons;
    _x addWeapon _primary;
    private _primaryMags = getArray (configFile >> "CfgWeapons" >> _primary >> "magazines");
    if (count _primaryMags > 0) then {
        for "_j" from 1 to 5 do { _x addMagazineGlobal (_primaryMags select 0); };
    };
    [_x, _primary] call _fnc_addAttachments;

    private _helmet = selectRandom _headgear;
    _x addHeadgear _helmet;

    if (random 1 < 0.7) then {
        _x addGoggles (selectRandom _facewear);
    };

    _x linkItem "ItemMap";
    _x linkItem "ItemGPS";
    _x linkItem "ItemRadio";
    _x linkItem "ItemCompass";
    _x linkItem "ItemWatch";
    
    private _hasLauncher = false;
    if (random 1 < 0.5) then {
        private _launcher = selectRandom _launchers;
        private _launcherMag = _launcherAmmo getOrDefault [_launcher, ""];
        if (_launcherMag != "") then {
            for "_j" from 1 to 4 do { _x addMagazine _launcherMag; };
        };
        _x addWeapon _launcher;
        _hasLauncher = true;
    };
    
    // Backpack on 50%, or always if this operator got a launcher.
    private _needBackpack = _hasLauncher || (random 1 < 0.5);
    if (_needBackpack) then {
        private _backpack = selectRandom _backpacks;
        _x addBackpackGlobal _backpack;
    };
    
    for "_j" from 1 to 2 do { _x addItemToUniform "FirstAidKit"; };
    for "_j" from 1 to 2 do { _x addMagazine "HandGrenade"; };
    _x addMagazine "SmokeShell";

    _x enableFatigue false;
    _x setSkill 0.8;
} forEach _units;

// Re-check in case the per-operator pass left a launcher carrier without a backpack.
{
    private _hasLauncher = (secondaryWeapon _x != "") ||
                           {(primaryWeapon _x) isKindOf ["Launcher", configFile >> "CfgWeapons"]} ||
                           {(handgunWeapon _x) isKindOf ["Launcher", configFile >> "CfgWeapons"]};
    if (_hasLauncher && backpack _x == "") then {
        _x addBackpackGlobal (selectRandom _backpacks);
    };
    // Top up every weapon: spawned launchers otherwise carry no rounds.
    [_x] call fnc_rearmUnit;
} forEach _units;

{
    [_x] joinSilent (group _caller);
    [_x] joinSilent (group _caller);
    [_x] joinSilent (group _caller);
} forEach _units;

private _successMsg = format [localize "STR_DUWS_T_HIRE_PMC_SUCCESS", _count];
["info", [localize "STR_DUWS_T_HIRE_PMC_TITLE", _successMsg]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
[localize "STR_DUWS_T_OVERLORD", ([localize "STR_DUWS_T_HIRE_PMC_SUCCESS2"] call fnc_cs)] remoteExec ["fnc_duws_dialogue", 0];

private _hintMsg = format [localize "STR_DUWS_T_HIRE_PMC_HINT", _count];
[_hintMsg] remoteExec ["hint", _caller];