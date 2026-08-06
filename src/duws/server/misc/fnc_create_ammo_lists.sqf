// CREATE LISTS OF ITEMS FOR ADDING TO AMMOBOXES, VEHICLES, RESTRICTED ARSENAL, etc...
// SPAWN UNITS, COPY ITEMS
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

// weapons = all weapons
// magazines = ammo mags, grenades, rockets, explosives
// items = medkits, FAKs, toolkits, etc...
// assignedItems = map, compass, radio, etc...
// primaryWeaponItems = scopes, laser, grips, etc...
// headgear = helmets, shemags, etc...
// goggles = goggles, glasses, etc...
// uniformItems = all items in uniform
// vestItems = all items in vest
// backpackItems = all items in backpack

blufor_ammobox_weapons = [];
blufor_ammobox_magazines = [];
blufor_ammobox_items = [];

opfor_ammobox_weapons = [];
opfor_ammobox_magazines = [];
opfor_ammobox_items = [];

// Create the base list for Restricted Arsenal
_basic_ammoArray = [] call fnc_basic_ammo_lists;
_ACE_Items = _basic_ammoArray select 0;
_basic_backpacks = _basic_ammoArray select 1;
_basic_vests = _basic_ammoArray select 2;
_basic_items = _basic_ammoArray select 3;
_basic_optics = _basic_ammoArray select 4;
_basic_magazines = _basic_ammoArray select 5;
_extra_weapons = _basic_ammoArray select 6;

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
        _total_items = _total_items + _ACE_Items;
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

// get blufor faction and create the array of units
_factionUnitArray = [];
_temp_factionUnitArray = [];
{
    _group = createGroup west;
    _group deleteGroupWhenEmpty true;
    _unit = "";
    _unit = _group createUnit [_x,[0,0], [], 0, "FORM"];
    _faction = [format["%1",faction _unit]] select 0;
    sleep 1;
    deleteVehicle _unit;

    //array of all units in player faction
    _temp_factionUnitArray = ("(configname _x isKindOf 'CAManBase') && (gettext (_x >> 'faction') == _faction) && (getNumber (_x >> 'scope') == 2)" configClasses (configfile >> "CfgVehicles")) apply {configName _x};
    _factionUnitArray = _factionUnitArray + _temp_factionUnitArray;

} foreach [blufor_SOLDIER_X,blufor_SPECOPS_X,blufor_SPECOPS_MEDIC_X];

//remove duplicates
_factionUnitArray = _factionUnitArray arrayIntersect _factionUnitArray; 

private _quickChangeUnits = (["UNIT"] call fnc_faction_rqst_list) apply { _x select 0 };
_factionUnitArray append _quickChangeUnits;
_factionUnitArray = _factionUnitArray arrayIntersect _factionUnitArray;

//array of all loadouts of all units in player faction (original method)
_factionLoadouts = [];
{ 
    _factionLoadouts append (flatten getUnitLoadout _x);
    sleep 0.1;
} forEach _factionUnitArray;

//remove duplicates
_factionLoadouts = _factionLoadouts arrayIntersect _factionLoadouts;

// === NEW: Also extract items from ALiVE_orbatCreator_loadout arrays and merge ===
_aliveLoadouts = [];

// Define recursive extraction function
_extractStrings = {
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
    _loadoutArray = getArray (configFile >> "CfgVehicles" >> _x >> "ALiVE_orbatCreator_loadout");
    if (count _loadoutArray > 0) then {
        _extracted = [];
        [_loadoutArray, _extracted] call _extractStrings;
        _aliveLoadouts append _extracted;
    };
    sleep 0.1;
} forEach _factionUnitArray;

_aliveLoadouts = _aliveLoadouts arrayIntersect _aliveLoadouts; // remove duplicates within Alive items

// Merge Alive items into the main loadouts array
_factionLoadouts = _factionLoadouts + _aliveLoadouts;
_factionLoadouts = _factionLoadouts arrayIntersect _factionLoadouts; // final deduplication
// === END NEW ===

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
if (VERSION_X != "MODERN") exitWith {};

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

// ACE Items from above
if (isClass (configFile >> "CfgPatches" >> "ace_main")) then {
    [missionNamespace, _ACE_Items - _excludedItems, true, false] call BIS_fnc_addVirtualItemCargo;
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
