// Runs once, the first time a player comes within 50 m of HQ -- the caller owns that trigger.

if (!isServer) exitWith {};
sleep 10;
// 获取 HQ 位置
private _hqPos = missionNamespace getVariable ["PosOfBLUHQ", []];
if (_hqPos isEqualTo []) exitWith { ["ERROR", "GEAR", "PosOfBLUHQ not defined, abort."] call fnc_log; };

// 收集 HQ 附近 500 米内的所有蓝方 AI 单位（排除玩家）
private _nearbyUnits = nearestObjects [_hqPos, ["CAManBase"], 500] select {
    alive _x && side _x == WEST && !isPlayer _x
};

["INFO", "GEAR", format ["Found %1 BLUFOR AI units near HQ.", count _nearbyUnits]] call fnc_log;

private _loadouts = [];

{
    private _unit = _x;
    private _className = typeOf _unit;
    private _displayName = getText (configFile >> "CfgVehicles" >> _className >> "displayName");
    private _loadout = getUnitLoadout _unit;
    
    _loadouts pushBack [_className, _displayName, _loadout];
    
} forEach _nearbyUnits;

// 去重（根据类名）
private _uniqueLoadouts = [];
{
    private _className = _x select 0;
    if !(_className in (_uniqueLoadouts apply {_x select 0})) then {
        _uniqueLoadouts pushBack _x;
    };
} forEach _loadouts;

blufor_quickChange_loadouts_scanned = _uniqueLoadouts;
publicVariable "blufor_quickChange_loadouts_scanned";

["INFO", "GEAR", format ["Collected %1 unique unit types.", count _uniqueLoadouts]] call fnc_log;

// ========== 新增：将扫描到的装备动态加入虚拟军火库 ==========
private _addedWeapons = [];
private _addedMagazines = [];
private _addedItems = [];
private _addedBackpacks = [];

// 辅助函数：递归提取 loadout 数组中的所有字符串类名
private _extractStrings = {
    params ["_data", "_resultArray"];
    if (typeName _data == "STRING") then {
        if (_data != "") then { _resultArray pushBackUnique _data };
    } else {
        if (typeName _data == "ARRAY") then {
            { [_x, _resultArray] call _extractStrings } forEach _data;
        };
    };
};

{
    _x params ["_className", "_displayName", "_loadout"];
    private _allClasses = [];
    [_loadout, _allClasses] call _extractStrings;
    
    // 分类添加到虚拟军火库
    {
        private _class = _x;
        // 跳过空字符串
        if (_class == "") then { continue };
        
        // 检查是否为武器
        if (isClass (configFile >> "CfgWeapons" >> _class)) then {
            private _itemType = [_class] call BIS_fnc_itemType;
            _itemType params ["_category", "_subcategory"];
            switch (_category) do {
                case "Weapon": {
                    if !(_class in _addedWeapons) then {
                        [missionNamespace, [_class], true] call BIS_fnc_addVirtualWeaponCargo;
                        _addedWeapons pushBack _class;
                        if (duws_log_level >= 4) then { ["DEBUG", "GEAR", format ["Added weapon: %1", _class]] call fnc_log; };
                    };
                };
                case "Equipment": {
                    // 头盔、背心、制服、眼镜等
                    if !(_class in _addedItems) then {
                        [missionNamespace, [_class], true] call BIS_fnc_addVirtualItemCargo;
                        _addedItems pushBack _class;
                        if (duws_log_level >= 4) then { ["DEBUG", "GEAR", format ["Added equipment: %1", _class]] call fnc_log; };
                    };
                };
                default {
                    if !(_class in _addedItems) then {
                        [missionNamespace, [_class], true] call BIS_fnc_addVirtualItemCargo;
                        _addedItems pushBack _class;
                        if (duws_log_level >= 4) then { ["DEBUG", "GEAR", format ["Added item: %1", _class]] call fnc_log; };
                    };
                };
            };
        } else {
            // 检查是否为弹药
            if (isClass (configFile >> "CfgMagazines" >> _class)) then {
                if !(_class in _addedMagazines) then {
                    [missionNamespace, [_class], true] call BIS_fnc_addVirtualMagazineCargo;
                    _addedMagazines pushBack _class;
                    if (duws_log_level >= 4) then { ["DEBUG", "GEAR", format ["Added magazine: %1", _class]] call fnc_log; };
                };
            } else {
                // 检查是否为背包
                if (isClass (configFile >> "CfgVehicles" >> _class) && {getNumber (configFile >> "CfgVehicles" >> _class >> "isBackpack") == 1}) then {
                    if !(_class in _addedBackpacks) then {
                        [missionNamespace, [_class], true] call BIS_fnc_addVirtualBackpackCargo;
                        _addedBackpacks pushBack _class;
                        if (duws_log_level >= 4) then { ["DEBUG", "GEAR", format ["Added backpack: %1", _class]] call fnc_log; };
                    };
                } else {
                    // 其他物品（如 FirstAidKit、Medikit 等）
                    if !(_class in _addedItems) then {
                        [missionNamespace, [_class], true] call BIS_fnc_addVirtualItemCargo;
                        _addedItems pushBack _class;
                        if (duws_log_level >= 4) then { ["DEBUG", "GEAR", format ["Added misc item: %1", _class]] call fnc_log; };
                    };
                };
            };
        };
    } forEach _allClasses;
} forEach _uniqueLoadouts;

["INFO", "GEAR", format ["arsenal updated: %1 weapons, %2 magazines, %3 items, %4 backpacks added",
    count _addedWeapons, count _addedMagazines, count _addedItems, count _addedBackpacks]] call fnc_log;
// ========== 新增部分结束 ==========