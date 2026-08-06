
if (!isServer) exitWith {};

// Kept in sync with the exclusion list in fnc_create_ammo_lists.sqf.
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

private _hqPos = missionNamespace getVariable ["PosOfBLUHQ", []];
if (_hqPos isEqualTo []) exitWith { ["ERROR", "GEAR", "PosOfBLUHQ not defined, abort."] call fnc_log; };

private _nearbyUnits = nearestObjects [_hqPos, ["CAManBase"], 500] select {
    alive _x && side _x == WEST
};

["INFO", "GEAR", format ["Found %1 BLUFOR units near HQ.", count _nearbyUnits]] call fnc_log;

private _allGear = [];

{
    private _loadout = getUnitLoadout _x;
    // getUnitLoadout nests classnames inside arrays; recurse to pull every string out.
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

["INFO", "GEAR", format ["Extracted %1 unique gear classnames.", count _allGear]] call fnc_log;

{
    private _class = _x;

    if (_class in _excludedItems) then { continue };

    if (_class isKindOf "Bag_Base") then {
        if ([_class] call _isBackpackWithCapacity) then {
            [missionNamespace, _class, true, false] call BIS_fnc_addVirtualBackpackCargo;
        };
    } else {
        [missionNamespace, _class, true, false] call BIS_fnc_addVirtualItemCargo;
        [missionNamespace, _class, true, false] call BIS_fnc_addVirtualMagazineCargo;
        if (isClass(configFile >> "CfgWeapons" >> _class)) then {
            [missionNamespace, _class, true, false] call BIS_fnc_addVirtualWeaponCargo;
        };
    };
} forEach _allGear;

["INFO", "GEAR", "Nearby units gear added to arsenal."] call fnc_log;
