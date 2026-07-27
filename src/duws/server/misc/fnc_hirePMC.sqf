// fnc_hirePMC.sqf
// 功能：雇佣私人军事承包商小组（6名精英干员），消耗15个Money_roll，冷却15分钟
// 参数: _caller - 执行动作的玩家
// 执行端: 服务器
if (!isServer) exitWith {};

params ["_caller"];
if (isNull _caller) exitWith {};

// ========== 冷却检查（15分钟 = 900秒） ==========
private _cooldownVar = "DUWS_hirePMC_lastUse";
private _lastUse = _caller getVariable [_cooldownVar, -900];
private _cooldownRemaining = 900 - (diag_tickTime - _lastUse);
if (_cooldownRemaining > 0) exitWith {
    private _minutes = floor (_cooldownRemaining / 60);
    private _seconds = floor (_cooldownRemaining % 60);
    private _msg = format [localize "STR_DUWS_T_HIRE_PMC_COOLDOWN", _minutes, _seconds];
    ["info", [localize "STR_DUWS_T_HIRE_PMC_TITLE", _msg]] remoteExec ["BIS_fnc_showNotification", _caller];
};

// 检查并扣除 15 个 Money_roll
private _moneyCount = { _x == "Money_roll" } count (magazines _caller);
if (_moneyCount < 15) exitWith {
    private _msg = localize "STR_DUWS_T_NOT_ENOUGH_MONEY_15";
    ["info", [localize "STR_DUWS_T_HIRE_PMC_TITLE", _msg]] remoteExec ["BIS_fnc_showNotification", _caller];
};
for "_i" from 1 to 15 do { _caller removeMagazineGlobal "Money_roll"; };

// 记录使用时间
_caller setVariable [_cooldownVar, diag_tickTime, true];

// 固定生成6名干员
private _count = 6;

// 获取 HQ 位置
private _hqPos = missionNamespace getVariable ["PosOfBLUHQ", getPos _caller];

// 在基地附近寻找安全位置
private _spawnPos = [];
for "_i" from 1 to 20 do {
    private _angle = random 360;
    private _dist = 30 + random 70;
    private _candidate = _hqPos getPos [_dist, _angle];
    private _safe = [_candidate, 0, 20, 5, 0, 0.2, 0] call BIS_fnc_findSafePos;
    if !(_safe isEqualTo [0,0,0]) exitWith { _spawnPos = _safe; };
};
if (_spawnPos isEqualTo []) then { _spawnPos = _hqPos getPos [50, random 360]; };

// 等待平民数组加载
waitUntil { !isNil "civ_array" && {count civ_array > 0} };
private _civArray = +civ_array;

// 生成单位类名数组（6个平民类名）
private _unitClasses = [];
for "_i" from 1 to _count do {
    _unitClasses pushBack (selectRandom _civArray);
};

// 使用 BIS_fnc_spawnGroup 生成干员组
private _group = [_spawnPos, WEST, _unitClasses, [], [], [0.7, 0.8]] call BIS_fnc_spawnGroup; // 高技能
_group deleteGroupWhenEmpty true;
private _units = units _group;

// ========== 定义装备池 ==========
// 制服
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
// 背心
private _vests = [
    "V_TacVestIR_blk",
    "V_I_G_resistanceLeader_F",
    "V_TacVest_blk",
    "V_PlateCarrier2_blk",
    "V_PlateCarrier2_blk"
];
// 背包
private _backpacks = [
    "B_AssaultPack_blk",
    "B_RadioBag_01_black_F",
    "B_Messenger_black_F"
];
// 头盔
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
// 面部装备
private _facewear = [
    "G_Aviator",
    "G_Shades_Black",
    "G_Shades_Red",
    "G_Shades_Blue",
    "G_Tactical_Black",
    "G_Tactical_Clear"
];
// 主武器池
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
// 发射器池
private _launchers = [
    "launch_RPG7_F",
    "launch_I_Titan_short_F",
    "launch_B_Titan_F"
];
// 发射器弹药映射
private _launcherAmmo = createHashMapFromArray [
    ["launch_RPG7_F", "RPG7_F"],
    ["launch_I_Titan_short_F", "Titan_AT"],
    ["launch_B_Titan_F", "Titan_AT"]
];

// ========== 获取附件池 ==========
private _basicAmmoArray = [] call fnc_basic_ammo_lists;
private _opticsList = _basicAmmoArray select 4; // _basic_optics
if (isNil "_opticsList") then { _opticsList = [] };

// 随机添加附件的函数
private _fnc_addAttachments = {
    params ["_unit", "_weapon"];
    private _num = floor random 4;
    for "_i" from 1 to _num do {
        private _attach = selectRandom _opticsList;
        _unit addPrimaryWeaponItem _attach;
    };
};

// ========== 为每个干员配置装备 ==========
{
    // 1. 制服（100%）
    _x forceAddUniform (selectRandom _uniforms);
    
    // 2. 背心（100%）
    _x addVest (selectRandom _vests);
    
    // 3. 主武器（100%）
    private _primary = selectRandom _primaryWeapons;
    _x addWeapon _primary;
    // 添加弹药（5个弹匣）
    private _primaryMags = getArray (configFile >> "CfgWeapons" >> _primary >> "magazines");
    if (count _primaryMags > 0) then {
        for "_j" from 1 to 5 do { _x addMagazineGlobal (_primaryMags select 0); };
    };
    // 随机添加附件
    [_x, _primary] call _fnc_addAttachments;
    
    // 4. 头盔（100%概率）
    private _helmet = selectRandom _headgear;
    _x addHeadgear _helmet;
    
    // 5. 面部装备（70%概率）
    if (random 1 < 0.7) then {
        _x addGoggles (selectRandom _facewear);
    };
    
    // 6. 基础装备（地图、GPS、无线电、指南针、手表）
    _x linkItem "ItemMap";
    _x linkItem "ItemGPS";
    _x linkItem "ItemRadio";
    _x linkItem "ItemCompass";
    _x linkItem "ItemWatch";
    
    // 7. 发射器（50%概率）
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
    
    // 8. 背包（50%概率，但如果装备了发射器则必须装备背包）
    private _needBackpack = _hasLauncher || (random 1 < 0.5);
    if (_needBackpack) then {
        private _backpack = selectRandom _backpacks;
        _x addBackpackGlobal _backpack;
    };
    
    // 9. 急救包（2个）
    for "_j" from 1 to 2 do { _x addItemToUniform "FirstAidKit"; };
    // 10. 手榴弹（2个）
    for "_j" from 1 to 2 do { _x addMagazine "HandGrenade"; };
    // 11. 烟雾弹（1个）
    _x addMagazine "SmokeShell";
    
    // 禁用疲劳
    _x enableFatigue false;
    _x setSkill 0.8;
} forEach _units;

// ========== 确保有发射器的干员一定有背包（保险）并补充弹药 ==========
{
    private _hasLauncher = (secondaryWeapon _x != "") ||
                           {(primaryWeapon _x) isKindOf ["Launcher", configFile >> "CfgWeapons"]} ||
                           {(handgunWeapon _x) isKindOf ["Launcher", configFile >> "CfgWeapons"]};
    if (_hasLauncher && backpack _x == "") then {
        _x addBackpackGlobal (selectRandom _backpacks);
    };
    // 补充所有武器弹药（修复发射器空弹问题）
    [_x] call fnc_rearmUnit;
} forEach _units;

// ========== 所有干员加入玩家小组 ==========
{
    [_x] joinSilent (group _caller);
    [_x] joinSilent (group _caller);
    [_x] joinSilent (group _caller);
} forEach _units;

// 广播成功通知
private _successMsg = format [localize "STR_DUWS_T_HIRE_PMC_SUCCESS", _count];
["info", [localize "STR_DUWS_T_HIRE_PMC_TITLE", _successMsg]] remoteExec ["BIS_fnc_showNotification", 0];
[localize "STR_DUWS_T_OVERLORD", ([localize "STR_DUWS_T_HIRE_PMC_SUCCESS2"] call fnc_cs)] remoteExec ["fnc_duws_dialogue", 0];

private _hintMsg = format [localize "STR_DUWS_T_HIRE_PMC_HINT", _count];
[_hintMsg] remoteExec ["hint", _caller];