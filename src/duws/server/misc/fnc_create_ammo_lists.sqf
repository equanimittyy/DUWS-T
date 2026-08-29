if (!isServer) exitWith {};
_excludedItems = [
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

blufor_ammobox_weapons = [];
blufor_ammobox_magazines = [];
blufor_ammobox_items = [];

opfor_ammobox_weapons = [];
opfor_ammobox_magazines = [];
opfor_ammobox_items = [];

// The friendly set the captured-materiel classifier tests against: standard-issue gear is unlimited
// and never pooled. Snapshotted from the assembled virtual cargo once, at the end of this build and
// before any foreign class can reach it -- the client's shelf-stocking on arsenal open adds foreign
// only to its own local cargo, never here. Called at both exits so it covers the non-MODERN path too.
_snapFriendly = {
    // The BIS cargo vars only ever reflect the sampled unit loadouts, so curated classes added to the
    // shelf that no unit wears -- the extra weapons (base MX, DMRs, snipers) and basic items -- are
    // absent from them and read [0]. `_extra` carries those known-added lists so they join the set; it
    // is passed on the MODERN path where those adds happen, and defaults empty for the legacy exit.
    params [["_extra", []]];
    private _u = [];
    {
        _u append flatten (missionNamespace getVariable [_x, []]);
    } forEach ["bis_addVirtualWeaponCargo_cargo", "bis_addVirtualItemCargo_cargo",
        "bis_addVirtualMagazineCargo_cargo", "bis_addVirtualBackpackCargo_cargo"];
    _u append _extra;
    // Strings only: flatten pulls magazine counts (numbers) out of the loadouts too; drop them so the
    // set holds classnames alone.
    private _s = _u select { _x isEqualType "" };
    // Loadouts carry preset weapons (e.g. arifle_MX_ACO_pointer_F); the arsenal lists each as its base
    // weapon row, so the friendly set needs that base too or the row reads [0]. Resolve both the
    // config-baseWeapon and the inheritance-parent forms of that base.
    _s append ([_s] call fnc_arsenal_base_weapons);
    DUWS_friendlyArsenal = _s arrayIntersect _s;
    publicVariable "DUWS_friendlyArsenal";
    // Limited has no unlimited floor, so stock the whole standard-issue set into the pool at boot.
    // Magazines are seeded too; the seed is simply unused while ammo is untracked.
    if (DUWS_arsenalLimited) then {
        { [_x, DUWS_limitedSeed] call fnc_captured_pool_setCount; } forEach DUWS_friendlyArsenal;
        publicVariable "DUWS_capturedPool";
    };
    ["INFO", "GEAR", format ["Friendly arsenal snapshot: %1 classes", count DUWS_friendlyArsenal]] call fnc_log;
};

// Create the base list for Restricted Arsenal
_basic_ammoArray = [] call fnc_basic_ammo_lists;
_ACE_Items = _basic_ammoArray select 0;
_basic_backpacks = _basic_ammoArray select 1;
_basic_vests = _basic_ammoArray select 2;
_basic_items = _basic_ammoArray select 3;
_basic_optics = _basic_ammoArray select 4;
_basic_magazines = _basic_ammoArray select 5;
_extra_weapons = _basic_ammoArray select 6;

// ACE medical, detected off ACE's own CfgWeapons flag rather than a hardcoded list, so the set
// tracks the installed ACE version and catches medical items ACE-patched faction mods add.
private _aceMedical = [];
if (isClass (configFile >> "CfgPatches" >> "ace_medical")) then {
    _aceMedical = ("getNumber (_x >> 'ACE_isMedicalItem') == 1 && {getNumber (_x >> 'scope') == 2}"
        configClasses (configFile >> "CfgWeapons")) apply { configName _x };
};

_blufor_units = [blufor_LAT_SOLDIER_X,blufor_SPECOPS_MEDIC_X,blufor_SPECOPS_ENG_X];
_opfor_units = [opfor_LAT_SOLDIER_X,opfor_SPECOPS_MEDIC_X,opfor_SPECOPS_ENG_X];

{
    _side = _x;
    _sideArray = [];
    if (_side == 1) then {
        _sideArray = _blufor_units;
    } else {
        _sideArray = _opfor_units;
    };

    _total_weapons = [];
    _total_magazines = [];
    _total_items = [];

    _temp_weapons = [];
    _temp_magazines = [];
    _temp_items = [];

    _group = createGroup west;
    _group deleteGroupWhenEmpty true;
    _unit = "";

    {
        _unit = _group createUnit [_x,[0,0], [], 0, "FORM"];
        _temp_weapons = _temp_weapons + [weapons _unit];
        _temp_magazines = _temp_magazines + [magazines _unit];
        _temp_items = _temp_items + [items _unit];
        sleep 1;
        deleteVehicle _unit;

    } forEach _sideArray;

    // Copy temp items to "total items" arrays
    {
        _class = _x;
        {
            if (_x != "" && isClass(configFile >> "CfgWeapons" >> _x)) then {
                _total_weapons = _total_weapons + [_x];
            };
        } forEach _class;
    } forEach _temp_weapons;
    {
        _class = _x;
        {
            if (_x != "" && isClass(configFile >> "CfgMagazines" >> _x)) then {
                _total_magazines = _total_magazines + [_x];
            };
        } forEach _class;
    } forEach _temp_magazines;
    {
        _class = _x;
        {
            if (_x != "" && isClass(configFile >> "CfgWeapons" >> _x)) then {
                _total_items = _total_items + [_x];
            };
        } forEach _class;
    } forEach _temp_items;

    if (isClass (configFile >> "CfgPatches" >> "ace_main")) then {
        _total_items = _total_items + _ACE_Items + _aceMedical;
    };

    _total_weapons = _total_weapons - _excludedItems;
    _total_magazines = _total_magazines - _excludedItems;
    _total_items = _total_items - _excludedItems;

    // Create global ammobox arrays
    if (_side == 1) then {
        blufor_ammobox_weapons = _total_weapons;publicVariable "blufor_ammobox_weapons";
        blufor_ammobox_magazines = _total_magazines;publicVariable "blufor_ammobox_magazines";
        blufor_ammobox_items = _total_items;publicVariable "blufor_ammobox_items";
    };
    if (_side == 2) then {
        opfor_ammobox_weapons = _total_weapons;publicVariable "opfor_ammobox_weapons";
        opfor_ammobox_magazines = _total_magazines;publicVariable "opfor_ammobox_magazines";
        opfor_ammobox_items = _total_items;publicVariable "opfor_ammobox_items";
    };

} forEach [1,2];  // 1 = blufor, 2 = opfor


waitUntil {sleep 5;chosen_settings};

// The arsenal draws only from the units the DUWS role keys resolve to -- each key's representative
// plus its spawn pool. The old config-faction sweep (spawn a seed unit, read its faction, pull every
// CfgVehicles man of that faction) was dropped: it rode on faction detection being right and, when it
// was not, stocked the arsenal with another faction's gear. The keylist is exactly what the quick
// kits already draw from, so both surfaces now offer the same units.
_factionUnitArray = ["blufor"] call fnc_faction_unit_keylist;

//array of all loadouts of all units in player faction
_factionLoadouts = [];
{
    _factionLoadouts append (flatten getUnitLoadout _x);
    sleep 0.1;
} forEach _factionUnitArray;

//remove duplicates
_factionLoadouts = _factionLoadouts arrayIntersect _factionLoadouts;

private _randomListItems = [];
{
    private _cfg = configFile >> "CfgVehicles" >> _x;
    if (isClass _cfg) then {
        private _uniformList = getArray (_cfg >> "uniformList");
        for "_i" from 0 to (count _uniformList - 1) step 2 do {
            private _item = _uniformList select _i;
            if (_item != "" && isClass (configFile >> "CfgWeapons" >> _item)) then {
                _randomListItems pushBackUnique _item;
            };
        };
        private _headgearList = getArray (_cfg >> "headgearList");
        for "_i" from 0 to (count _headgearList - 1) step 2 do {
            private _item = _headgearList select _i;
            if (_item != "" && isClass (configFile >> "CfgWeapons" >> _item)) then {
                _randomListItems pushBackUnique _item;
            };
        };
        private _facewearList = getArray (_cfg >> "facewearList");
        for "_i" from 0 to (count _facewearList - 1) step 2 do {
            private _item = _facewearList select _i;
            if (_item != "" && isClass (configFile >> "CfgGlasses" >> _item)) then {
                _randomListItems pushBackUnique _item;
            };
        };
        private _vestList = getArray (_cfg >> "vestList");
        for "_i" from 0 to (count _vestList - 1) step 2 do {
            private _item = _vestList select _i;
            if (_item != "" && isClass (configFile >> "CfgWeapons" >> _item)) then {
                _randomListItems pushBackUnique _item;
            };
        };
    };
} forEach _factionUnitArray;

_factionLoadouts append _randomListItems;
_factionLoadouts = _factionLoadouts arrayIntersect _factionLoadouts;

_factionLoadouts = _factionLoadouts - _excludedItems;

copyToClipboard str _factionLoadouts;

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

//add faction items to arsenal
{
    if (typeName _x == "STRING") then {
        if (_x != "") then {
            if (_x isKindOf "Bag_Base") then {
                _pack = _x;
                _possibleBackpack = [ configFile >> "CfgVehicles" >> _pack, true ] call BIS_fnc_returnParents; 
                _possibleBackpackParent = []; 
                _possibleBackpackChildren = [];
                { 
                    if (getNumber(configFile >> "CfgVehicles" >> _x >> "scope") == 2) then {_possibleBackpackParent pushBackUnique _x}; 
                } forEach _possibleBackpack;
                _possibleBackpackChildren = ("(configname _x isKindOf 'Bag_Base') && (configname _x isKindOf _pack) && (getNumber(_x >> 'scope') == 2)" 
                                            configClasses (configfile >> "CfgVehicles")) apply {configName _x};
                _validBackpacks = [];
                {
                    if ([_x] call _isBackpackWithCapacity) then {
                        _validBackpacks pushBack _x;
                    };
                } forEach (_possibleBackpackParent + _possibleBackpackChildren);
                
                {
                    [missionNamespace, _x, true,false] call BIS_fnc_addVirtualBackpackCargo; 
                } forEach _validBackpacks;

            } else {
                [missionNamespace, _x, true,false] call BIS_fnc_addVirtualItemCargo;
                [missionNamespace, _x, true,false] call BIS_fnc_addVirtualBackpackCargo;
                [missionNamespace, _x, true,false] call BIS_fnc_addVirtualMagazineCargo;
                if (isClass(configFile >> "CfgWeapons" >> _x)) then {
                    [missionNamespace, _x, true,false] call BIS_fnc_addVirtualWeaponCargo;
                };
            };
        };
    };
} forEach _factionLoadouts;

//Add additional basic items that some factions may lack, especially backpacks.
//basic backpacks - multicolor variants to make them as usable with as many factions as possible
if (VERSION_X != "MODERN") exitWith { call _snapFriendly; };

private _filteredBackpacks = [];
{
    if ([_x] call _isBackpackWithCapacity) then {
        _filteredBackpacks pushBack _x;
    };
} forEach (_basic_backpacks - _excludedItems);
[missionNamespace, _filteredBackpacks, true, false] call BIS_fnc_addVirtualBackpackCargo;

//basic vests
[missionNamespace, _basic_vests - _excludedItems, true, false] call BIS_fnc_addVirtualItemCargo;
//basic items
[missionNamespace, _basic_items - _excludedItems, true, false] call BIS_fnc_addVirtualItemCargo;
//basic optics
[missionNamespace, _basic_optics - _excludedItems, true, false] call BIS_fnc_addVirtualItemCargo;
//misc magazines
[missionNamespace, _basic_magazines - _excludedItems, true, false ] call BIS_fnc_addVirtualMagazineCargo;
//extra weapons
[missionNamespace, _extra_weapons - _excludedItems, true, false ] call BIS_fnc_addVirtualWeaponCargo;

// ACE items: scanned medical, curated tools, and extra utility gear. Route each by where it actually
// lives -- CfgWeapons to item cargo, CfgMagazines to throwable cargo -- and skip-with-warn any class
// that resolves to neither, so a missing mod or a renamed class drops one item, not the whole batch.
if (isClass (configFile >> "CfgPatches" >> "ace_main")) then {
    [missionNamespace, _aceMedical - _excludedItems, true, false] call BIS_fnc_addVirtualItemCargo;

    private _aceExtra = [
        "ACE_EarPlugs", "ACE_MapTools", "ACE_Kestrel4500", "ACE_microDAGR", "ACE_SpareBarrel",
        "ACE_CableTie", "ACE_EntrenchingTool", "ACE_Flashlight_MX991", "ACE_Flashlight_KSF1",
        "ACE_Flashlight_XL50", "ACE_HuntIR_monitor", "ACE_HuntIR_M203", "ACE_SpottingScope",
        "ACE_Tripod", "ACE_SpraypaintBlack", "ACE_SpraypaintRed", "ACE_SpraypaintGreen",
        "ACE_SpraypaintBlue", "ACE_Chemlight_IR"
    ];
    {
        switch (true) do {
            case (isClass (configFile >> "CfgWeapons" >> _x)): {
                [missionNamespace, _x, true, false] call BIS_fnc_addVirtualItemCargo;
            };
            case (isClass (configFile >> "CfgMagazines" >> _x)): {
                [missionNamespace, _x, true, false] call BIS_fnc_addVirtualMagazineCargo;
            };
            default { ["WARN", "GEAR", format ["ACE arsenal item not found, skipped: %1", _x]] call fnc_log; };
        };
    } forEach ((_ACE_Items + _aceExtra) - _excludedItems);
};
private _aceFoods = [
    "ACE_MRE_SteakVegetables",
    "ACE_MRE_MeatballsPasta",
    "ACE_MRE_LambCurry",
    "ACE_MRE_CreamTomatoSoup",
    "ACE_MRE_CreamChickenSoup",
    "ACE_MRE_ChickenHerbDumplings",
    "ACE_MRE_ChickenTikkaMasala",
    "ACE_MRE_BeefStew",
    "ACE_Humanitarian_Ration"
];
[missionNamespace, _aceFoods, true] call BIS_fnc_addVirtualItemCargo;
[missionNamespace, _aceFoods, true] call BIS_fnc_addVirtualMagazineCargo;
private _bluFaction = "";
private _opfFaction = "";
{
    _group = createGroup west;
    _unit = _group createUnit [_x,[0,0], [], 0, "FORM"];
    _bluFaction = faction _unit;
    deleteVehicle _unit;
    deleteGroup _group;
    break;
} forEach [blufor_SOLDIER_X, blufor_SPECOPS_X, blufor_SPECOPS_MEDIC_X];

{
    _group = createGroup east;
    _unit = _group createUnit [_x,[0,0], [], 0, "FORM"];
    _opfFaction = faction _unit;
    deleteVehicle _unit;
    deleteGroup _group;
    break;
} forEach [opfor_SOLDIER_X, opfor_SPECOPS_X, opfor_SPECOPS_MEDIC_X];

["INFO", "CIV", format ["Detected factions: BLU=%1, OPF=%2", _bluFaction, _opfFaction]] call fnc_log;

// Pass the curated basic/extra classes so they join the friendly set: these are on the shelf but no
// sampled unit wears them, so the cargo scan alone leaves them at [0].
[(_extra_weapons + _basic_vests + _basic_items + _basic_optics + _basic_magazines
    + _filteredBackpacks + _aceMedical + _aceFoods) - _excludedItems] call _snapFriendly;
