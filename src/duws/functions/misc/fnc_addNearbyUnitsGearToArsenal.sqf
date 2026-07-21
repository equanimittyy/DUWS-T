/*
    fnc_addNearbyUnitsGearToArsenal.sqf
    功能：扫描 HQ 附近 500 米内的所有蓝方人员，将身上的装备添加到虚拟军火库。
    执行端：服务器
    依赖：需在 fnc_create_ammo_lists.sqf 中定义了 _excludedItems 并公开为 DUWS_excludedItems，
          或在此处重新定义排除列表。
*/

if (!isServer) exitWith {};

// ===== 排除列表（与 fnc_create_ammo_lists.sqf 保持一致）=====
private _excludedItems = [
    "I_UAV_01_backpack_F",
    "B_UAV_01_backpack_F",
    "O_UAV_01_backpack_F",
    "O_UAV_06_backpack_F",
    "I_UAV_06_backpack_F",
    "B_UAV_06_backpack_F",
    "B_UAV_06_medical_backpack_F",
    "I_UAV_06_medical_backpack_F",
    "O_UAV_06_medical_backpack_F",
    "C_IDAP_UAV_06_medical_backpack_F",
    "C_IDAP_UAV_06_antimine_backpack_F",
    "C_UAV_06_medical_backpack_F",
    "I_E_UAV_01_backpack_F",
    "I_E_UAV_06_backpack_F",
    "I_E_UAV_06_medical_backpack_F",
    "B_Mortar_01_support_F",
    "O_Mortar_01_support_F",
    "I_Mortar_01_support_F",
    "I_Mortar_01_weapon_F",
    "B_Mortar_01_weapon_F",
    "O_Mortar_01_weapon_F",
    "B_Patrol_Respawn_bag_F"
];

// 辅助函数：检查背包是否有容量
_isBackpackWithCapacity = {
    params ["_class"];
    private _cfg = configFile >> "CfgVehicles" >> _class;
    if (isClass _cfg) then {
        private _load = getNumber (_cfg >> "maximumLoad");
        _load > 0
    } else {
        false
    };
};

// 获取 HQ 位置
private _hqPos = missionNamespace getVariable ["PosOfBLUHQ", []];
if (_hqPos isEqualTo []) exitWith { diag_log "[Arsenal] PosOfBLUHQ not defined, abort."; };

// 收集 HQ 附近 500 米内的所有蓝方人员
private _nearbyUnits = nearestObjects [_hqPos, ["CAManBase"], 500] select {
    alive _x && side _x == WEST
};

diag_log format ["[Arsenal] Found %1 BLUFOR units near HQ.", count _nearbyUnits];

// 收集所有装备类名（去重）
private _allGear = [];

{
    private _loadout = getUnitLoadout _x;
    // 递归提取所有字符串类名
    private _extractStrings = {
        params ["_data"];
        if (typeName _data == "STRING") then {
            if (_data != "") then { _allGear pushBackUnique _data };
        } else {
            if (typeName _data == "ARRAY") then {
                { [_x] call _extractStrings } forEach _data;
            };
        };
    };
    [_loadout] call _extractStrings;
} forEach _nearbyUnits;

diag_log format ["[Arsenal] Extracted %1 unique gear classnames.", count _allGear];

// 过滤并添加到虚拟军火库
{
    private _class = _x;

    // 排除列表过滤
    if (_class in _excludedItems) then { continue };

    if (_class isKindOf "Bag_Base") then {
        // 背包：检查容量
        if ([_class] call _isBackpackWithCapacity) then {
            [missionNamespace, _class, true, false] call BIS_fnc_addVirtualBackpackCargo;
        };
    } else {
        // 其他物品（武器、弹药、装备等）
        [missionNamespace, _class, true, false] call BIS_fnc_addVirtualItemCargo;
        [missionNamespace, _class, true, false] call BIS_fnc_addVirtualMagazineCargo;
        if (isClass(configFile >> "CfgWeapons" >> _class)) then {
            [missionNamespace, _class, true, false] call BIS_fnc_addVirtualWeaponCargo;
        };
    };
} forEach _allGear;

diag_log "[Arsenal] Nearby units gear added to arsenal.";
