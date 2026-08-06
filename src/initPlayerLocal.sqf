// initPlayerLocal.sqf

// Initialize the player/client side Dynamic Groups framework
["InitializePlayer", [player]] call BIS_fnc_dynamicGroups; 

player allowDamage false;

// Revive selection must stay last in this file.

// NO REVIVE vs AIS vs Vanilla vs ACE medical
_revive = ["Revive", 1] call BIS_fnc_getParamValue;

// NO REVIVE or ACE MEDICAL DETECTED
if (_revive == 0 || isClass (configFile >> "CfgPatches" >> "ace_medical") || isClass (configFile >> "CfgPatches" >> "ace_main")) then {
	[player] call bis_fnc_disableRevive;
	player setVariable ["AIS_noReviveInit", true];
	["Revive is disabled"] call BIS_fnc_logFormat;
};
// AIS
if (_revive == 1) then {
	player setVariable ["AIS_noReviveInit", false];
	[player] call AIS_System_fnc_loadAIS;
	[player] call bis_fnc_disableRevive;
};
// VANILLA
if (_revive == 2) then {
	player setVariable ["AIS_noReviveInit", true];
};

// helper: recursively pull every item classname from a loadout
DUWS_fnc_extractLoadoutItems = {
    params ["_data", "_resultArray"];
    if (typeName _data == "STRING") then {
        if (_data != "") then { _resultArray pushBackUnique _data };
    } else {
        if (typeName _data == "ARRAY") then {
            { [_x, _resultArray] call DUWS_fnc_extractLoadoutItems } forEach _data;
        };
    };
};

// helper: count item types that changed between two loadouts
DUWS_fnc_countLoadoutChanges = {
    params ["_loadout1", "_loadout2"];
    
    private _items1 = [];
    private _items2 = [];
    [_loadout1, _items1] call DUWS_fnc_extractLoadoutItems;
    [_loadout2, _items2] call DUWS_fnc_extractLoadoutItems;
    
    private _added = _items2 - _items1;
    private _removed = _items1 - _items2;
    
    count (_added + _removed)
};

// items force-removed from a loadout: money and intel
DUWS_forcedRemoveItems = [
    "Money_roll", "Files", "Wallet_ID", "SmartPhone", "MobilePhone", 
    "FlashDisk", "FileTopSecret", "FilesSecret"
];

// detect money/intel in a loadout; detection only, no removal
DUWS_fnc_check_money_intel = {
    private _loadout = getUnitLoadout player;
    private _loadoutItems = [];
    [_loadout, _loadoutItems] call DUWS_fnc_extractLoadoutItems;
    
    private _foundItems = [];
    {
        if (_x in DUWS_forcedRemoveItems) then {
            _foundItems pushBackUnique _x;
        };
    } forEach _loadoutItems;
    
    count _foundItems
};

// standalone: remove only money and intel items
DUWS_fnc_remove_money_intel = {
    private _loadout = getUnitLoadout player;
    private _loadoutItems = [];
    [_loadout, _loadoutItems] call DUWS_fnc_extractLoadoutItems;
    
    private _removedCount = 0;
    
    {
        private _className = _x;
        if (_className in DUWS_forcedRemoveItems) then {
            private _itemData = ([_className] call BIS_fnc_itemType);
            private _category = _itemData select 0;
            private _subcategory = _itemData select 1;
            
            if (_category == "Weapon") then {
                player removeWeaponGlobal _className;
                _removedCount = _removedCount + 1;
            } else {
                if (_category == "Item") then {
                    while {_className in (items player)} do {
                        player removeItem _className;
                        _removedCount = _removedCount + 1;
                    };
                } else {
                    if (_category == "Equipment") then {
                        if (_subcategory == "Uniform") then {
                            removeUniform player;
                            _removedCount = _removedCount + 1;
                        } else {
                            if (_subcategory == "Backpack") then {
                                removeBackpackGlobal player;
                                _removedCount = _removedCount + 1;
                            } else {
                                if (_subcategory == "Vest") then {
                                    removeVest player;
                                    _removedCount = _removedCount + 1;
                                } else {
                                    if (_subcategory == "Headgear") then {
                                        removeHeadgear player;
                                        _removedCount = _removedCount + 1;
                                    };
                                };
                            };
                        };
                    } else {
                        private _countBefore = {_x == _className} count magazines player;
                        player removeMagazines _className;
                        _removedCount = _removedCount + _countBefore;
                    };
                };
            };
        };
    } forEach _loadoutItems;
    
    if (_removedCount > 0) then {
        systemChat format [localize "STR_DUWS_ARSENAL_MONEY_REMOVED", _removedCount];
    };
};

// restricted-arsenal handler: whitelist filter plus forced money/intel removal
DUWS_fnc_arsenal_restricted = {
    private _whitelist = flatten (missionNamespace getVariable ["bis_addVirtualWeaponCargo_cargo", []]);
    _whitelist = _whitelist arrayIntersect _whitelist;
    _whitelist append ( _whitelist select { ([_x] call BIS_fnc_itemType)#0 isEqualTo "Weapon" } apply { configName inheritsFrom (configFile >> "CfgWeapons" >> _x) } );
    
    private _loadout = getUnitLoadout player;
    private _loadoutItems = [];
    [_loadout, _loadoutItems] call DUWS_fnc_extractLoadoutItems;
    
    private _removedItems = [];
    
    // pull secondary-weapon info from the loadout
    private _handgunSlot = _loadout select 2;
    private _handgunWeapon = "";
    private _handgunItems = [];
    private _handgunBase = "";
    
    if (count _handgunSlot > 0) then {
        _handgunWeapon = _handgunSlot select 0;
        private _itemsData = _handgunSlot select 1;
        if (typeName _itemsData == "ARRAY") then {
            _handgunItems = _itemsData;
        } else {
            _handgunItems = [];
        };
        _handgunBase = if (_handgunWeapon != "") then { [_handgunWeapon] call BIS_fnc_baseWeapon } else { "" };
    };
    
    // force-removed items first
    {
        private _className = _x;
        if (_className in DUWS_forcedRemoveItems) then {
            private _itemData = ([_className] call BIS_fnc_itemType);
            private _category = _itemData select 0;
            private _subcategory = _itemData select 1;
            
            if (_category == "Weapon") then {
                player removeWeaponGlobal _className;
            } else {
                if (_category == "Item") then {
                    while {_className in (items player)} do {
                        player removeItem _className;
                    };
                } else {
                    if (_category == "Equipment") then {
                        if (_subcategory == "Uniform") then {
                            removeUniform player;
                        } else {
                            if (_subcategory == "Backpack") then {
                                removeBackpackGlobal player;
                            } else {
                                if (_subcategory == "Vest") then {
                                    removeVest player;
                                } else {
                                    if (_subcategory == "Headgear") then {
                                        removeHeadgear player;
                                    };
                                };
                            };
                        };
                    } else {
                        player removeMagazines _className;
                    };
                };
            };
            _removedItems pushBackUnique _className;
        };
    } forEach _loadoutItems;
    
    // then the whitelist filter
    {
        private _className = _x;
        if (_className in DUWS_forcedRemoveItems) then { continue };
        
        private _itemData = ([_className] call BIS_fnc_itemType);
        private _category = _itemData select 0;
        private _subcategory = _itemData select 1;
        
        if (!(_category in ["Weapon", "Item", "Equipment"])) then { continue };
        if (_category == "Equipment" && _subcategory == "Glasses") then { continue };
        if (_handgunWeapon != "" && {_className == _handgunWeapon || _className == _handgunBase}) then { continue };
        if (count _handgunItems > 0 && {_handgunItems findIf { _x == _className } != -1}) then { continue };
        
        if (!(_className in _whitelist)) then {
            if (_category == "Weapon") then {
                player removeWeaponGlobal _className;
            } else {
                if (_category == "Item") then {
                    while {_className in (items player)} do {
                        player removeItem _className;
                    };
                } else {
                    if (_subcategory == "Uniform") then {
                        removeUniform player;
                    } else {
                        if (_subcategory == "Backpack") then {
                            removeBackpackGlobal player;
                        } else {
                            if (_subcategory == "Vest") then {
                                removeVest player;
                            } else {
                                if (_subcategory == "Headgear") then {
                                    removeHeadgear player;
                                };
                            };
                        };
                    };
                };
            };
            _removedItems pushBackUnique _className;
        };
    } forEach _loadoutItems;
    
    if (count _removedItems > 0) then {
        systemChat format [localize "STR_DUWS_ARSENAL_RESTRICTED_REMOVED", count _removedItems];
    };
};

// full-arsenal handler: no-op
DUWS_fnc_arsenal_full = {
};

// default to full mode
DUWS_fnc_arsenal_current = DUWS_fnc_arsenal_full;

[ missionNamespace, "arsenalOpened", {
    [] spawn {
        scriptName "Arsenal whitelist enforcer";
        waitUntil { sleep 0.1; !isNull (uiNamespace getVariable ["RscDisplayArsenal", displayNull]) };
        systemChat localize "STR_DUWS_ARSENAL_INIT";
        
// on arsenal open: warn about money/intel, do not remove it
private _moneyIntelCount = [] call DUWS_fnc_check_money_intel;
if (_moneyIntelCount > 0) then {
    systemChat format [localize "STR_DUWS_ARSENAL_MONEY_WARNING", _moneyIntelCount];
    private _title = localize "STR_DUWS_ARSENAL_MONEY_WARNING_TITLE";
    private _desc = format [localize "STR_DUWS_ARSENAL_MONEY_WARNING_DESC", _moneyIntelCount];
    ["alert", [_title, _desc]] remoteExec ["BIS_fnc_showNotification", player];
};
        
        private _isRestricted = player getVariable ["DUWS_isRestrictedArsenal", false];
        
        private _refLoadout = getUnitLoadout player;
        private _changeThreshold = 10;
        
        while { sleep 0.2; !isNull (uiNamespace getVariable ["RscDisplayArsenal", displayNull]) } do {
            private _currentLoadout = getUnitLoadout player;
            if (_currentLoadout isNotEqualTo _refLoadout) then {
                systemChat localize "STR_DUWS_ARSENAL_LOADOUT_CHANGED";
                
                private _changeCount = [_refLoadout, _currentLoadout] call DUWS_fnc_countLoadoutChanges;
                private _isLargeChange = (_changeCount >= _changeThreshold);
                
                if (_isLargeChange) then {
                    systemChat format [localize "STR_DUWS_ARSENAL_LARGE_CHANGE_DETECTED", _changeCount];
                };
                
                // remove money/intel on any loadout change, small or large
                [] call DUWS_fnc_remove_money_intel;
                
                // restricted mode also runs the whitelist filter on a large change
                if (_isRestricted && _isLargeChange) then {
                    // DUWS_fnc_arsenal_restricted also strips money/intel, already done above by DUWS_fnc_remove_money_intel
                    // calling the full function double-removes, which is harmless; kept for simplicity
                    [] call DUWS_fnc_arsenal_restricted;
                };
                
                _refLoadout = _currentLoadout;
            };
        };
        
        // on arsenal close: no removal
        systemChat localize "STR_DUWS_ARSENAL_EXIT";
        player setVariable ["DUWS_isRestrictedArsenal", nil];
    };
}] call BIS_fnc_addScriptedEventHandler;