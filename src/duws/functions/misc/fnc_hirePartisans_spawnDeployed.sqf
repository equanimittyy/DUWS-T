// fnc_hirePartisans_spawnDeployed.sqf
// 服务器执行：在指定位置生成游击队并加入高级指挥
if (!isServer) exitWith {};

params ["_caller", "_clickPos", "_count"];
if (isNull _caller) exitWith {};

private _spawnPos = [_clickPos, 0, 30, 5, 0, 0.2, 0] call BIS_fnc_findSafePos;
if (_spawnPos isEqualTo [0,0,0]) then { _spawnPos = _clickPos; };

waitUntil { !isNil "civ_array" && {count civ_array > 0} };
private _civArray = +civ_array;

private _unitClasses = [];
for "_i" from 1 to _count do {
    _unitClasses pushBack (selectRandom _civArray);
};

private _group = [_spawnPos, WEST, _unitClasses, [], [], [0.5, 0.6]] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
private _units = units _group;

// ----- 装备逻辑 -----
private _hqPos = missionNamespace getVariable ["PosOfBLUHQ", getPos _caller];
private _nearbyBlu = nearestObjects [_hqPos, ["CAManBase"], 200] select { side _x == WEST && alive _x };
private _scannedWeapons = [];
private _scannedVests = [];
{
    { _scannedWeapons pushBackUnique _x } forEach (weapons _x);
    private _vest = vest _x;
    if (_vest != "") then { _scannedVests pushBackUnique _vest };
} forEach _nearbyBlu;

private _civWeaponPool = [
    ["hgun_PDW2000_F", "30Rnd_9x21_Mag"],
    ["arifle_AKS_F", "30Rnd_545x39_Mag_F"],
    ["SMG_05_F", "30Rnd_9x21_Mag_SMG_02"],
    ["sgun_HunterShotgun_01_F", "2Rnd_12Gauge_Pellets"],
    ["sgun_HunterShotgun_01_sawedoff_F", "2Rnd_12Gauge_Pellets"],
    ["srifle_DMR_06_hunter_F", "10Rnd_762x51_Mag"],
    ["hgun_P07_F", "16Rnd_9x21_Mag"],
    ["hgun_Pistol_01_F", "10Rnd_9x21_Mag"]
];

private _weaponClasses = [];
{ _weaponClasses pushBack (_x select 0) } forEach _civWeaponPool;
{ _weaponClasses pushBackUnique _x } forEach _scannedWeapons;
_weaponClasses = _weaponClasses arrayIntersect _weaponClasses;

private _launcherClasses = _scannedWeapons select { _x isKindOf ["Launcher", configFile >> "CfgWeapons"] };
private _vestClasses = _scannedVests arrayIntersect _scannedVests;
if (count _vestClasses == 0) then { _vestClasses = ["V_TacVest_blk"] };

{
    if (count _vestClasses > 0 && random 1 < 0.8) then {
        _x addVest (selectRandom _vestClasses);
    };

    private _primaryPool = _weaponClasses select { !(_x isKindOf ["Launcher", configFile >> "CfgWeapons"]) };
    if (count _primaryPool == 0) then { _primaryPool = ["hgun_P07_F"] };
    private _primaryWeapon = selectRandom _primaryPool;
    _x addWeapon _primaryWeapon;
    private _magazines = getArray (configFile >> "CfgWeapons" >> _primaryWeapon >> "magazines");
    if (count _magazines > 0) then {
        for "_j" from 1 to 3 do { _x addMagazineGlobal (_magazines select 0); };
    };

    if (count _launcherClasses > 0 && random 1 < 0.3) then {
        private _launcher = selectRandom _launcherClasses;
        _x addWeapon _launcher;
        private _launcherMags = getArray (configFile >> "CfgWeapons" >> _launcher >> "magazines");
        if (count _launcherMags > 0) then {
            _x addMagazineGlobal (_launcherMags select 0);
        };
    };

    _x enableFatigue false;
} forEach _units;

// 确保有发射器的单位装备背包（平民风格）
{
    private _hasLauncher = (secondaryWeapon _x != "") ||
                           {(primaryWeapon _x) isKindOf ["Launcher", configFile >> "CfgWeapons"]} ||
                           {(handgunWeapon _x) isKindOf ["Launcher", configFile >> "CfgWeapons"]};
    if (_hasLauncher && backpack _x == "") then {
        _x addBackpackGlobal (selectRandom [
            "B_CivilianBackpack_01_Everyday_Black_F",
            "B_CivilianBackpack_01_Everyday_Vrana_F",
            "B_CivilianBackpack_01_Everyday_Astra_F",
            "B_CivilianBackpack_01_Everyday_IDAP_F",
            "B_CivilianBackpack_01_Sport_Red_F",
            "B_CivilianBackpack_01_Sport_Green_F",
            "B_CivilianBackpack_01_Sport_Blue_F"
        ]);
    };
} forEach _units;

// 补充弹药
{ [_x] call fnc_rearmUnit; } forEach _units;

// ----- 加入高级指挥（HC）-----
private _playerName = vehiclevarname _caller;
private _var = format["%1HC", _playerName];
private _HCgroups = missionNamespace getVariable [_var, []];

DUWS_number_partisan = (missionNamespace getVariable ["DUWS_number_partisan", 0]) + 1;
missionNamespace setVariable ["DUWS_number_partisan", DUWS_number_partisan];
_group setGroupId [format ["Partisans %1", DUWS_number_partisan]];

_HCgroups pushBack _group;
missionNamespace setVariable [_var, _HCgroups, true];

[[_group], {
    params ["_group"];
    if (isNull _group) exitWith {};
    player hcSetGroup [_group, ""];
}] remoteExec ["call", _caller];

private _successMsg = format [localize "STR_DUWS_T_HIRE_PARTISANS_SUCCESS", _count];
["info", [localize "STR_DUWS_T_HIRE_PARTISANS_TITLE", _successMsg]] remoteExec ["BIS_fnc_showNotification", 0];
[localize "STR_DUWS_T_OVERLORD", _successMsg] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];

private _hintMsg = format [localize "STR_DUWS_T_HIRE_PARTISANS_HINT", _count];
[_hintMsg] remoteExec ["hint", _caller];