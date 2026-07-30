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

// ========== 辅助函数：递归提取负载中所有物品类名 ==========
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

// ========== 辅助函数：计算两次负载之间变化的物品种类数 ==========
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

// ========== 强制移除物品列表（钱币/情报） ==========
DUWS_forcedRemoveItems = [
    "Money_roll", "Files", "Wallet_ID", "SmartPhone", "MobilePhone", 
    "FlashDisk", "FileTopSecret", "FilesSecret"
];

// ========== 检测是否携带钱币/情报（仅检测，不删除） ==========
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

// ========== 独立函数：仅删除钱币和情报物品 ==========
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

// ========== 定义受限军火库处理函数（完整白名单 + 强制移除钱币/情报） ==========
DUWS_fnc_arsenal_restricted = {
    private _whitelist = flatten (missionNamespace getVariable ["bis_addVirtualWeaponCargo_cargo", []]);
    _whitelist = _whitelist arrayIntersect _whitelist;
    _whitelist append ( _whitelist select { ([_x] call BIS_fnc_itemType)#0 isEqualTo "Weapon" } apply { configName inheritsFrom (configFile >> "CfgWeapons" >> _x) } );
    
    private _loadout = getUnitLoadout player;
    private _loadoutItems = [];
    [_loadout, _loadoutItems] call DUWS_fnc_extractLoadoutItems;
    
    private _removedItems = [];
    
    // 从玩家负载中解析副武器信息
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
    
    // 先处理强制移除的物品
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
    
    // 再处理白名单过滤
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

// ========== 定义完整军火库处理函数（不执行任何操作） ==========
DUWS_fnc_arsenal_full = {
    // 完整军火库模式下不做任何额外处理
};

// 默认使用完整模式
DUWS_fnc_arsenal_current = DUWS_fnc_arsenal_full;

[ missionNamespace, "arsenalOpened", {
    [] spawn {
        scriptName "Arsenal whitelist enforcer";
        waitUntil { sleep 0.1; !isNull (uiNamespace getVariable ["RscDisplayArsenal", displayNull]) };
        systemChat localize "STR_DUWS_ARSENAL_INIT";
        
// 进入军火库时检测钱币/情报，仅提醒不删除
private _moneyIntelCount = [] call DUWS_fnc_check_money_intel;
if (_moneyIntelCount > 0) then {
    systemChat format [localize "STR_DUWS_ARSENAL_MONEY_WARNING", _moneyIntelCount];
    // 新增：使用 BIS_fnc_showNotification 弹出醒目提醒
    private _title = localize "STR_DUWS_ARSENAL_MONEY_WARNING_TITLE";
    private _desc = format [localize "STR_DUWS_ARSENAL_MONEY_WARNING_DESC", _moneyIntelCount];
    ["arsenal_warning", [_title, _desc]] remoteExec ["BIS_fnc_showNotification", player];
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
                
                // 无论小幅还是大幅换装，均删除钱币/情报
                [] call DUWS_fnc_remove_money_intel;
                
                // 受限模式下大幅换装额外执行白名单过滤
                if (_isRestricted && _isLargeChange) then {
                    // 注意：DUWS_fnc_arsenal_restricted 内部已包含删除钱币/情报，但我们已调用过 DUWS_fnc_remove_money_intel
                    // 为避免重复删除，可仅调用白名单过滤部分，但为了代码简洁，直接调用完整函数亦可（重复删除无影响）
                    [] call DUWS_fnc_arsenal_restricted;
                };
                
                _refLoadout = _currentLoadout;
            };
        };
        
        // 退出军火库时不执行任何删除
        systemChat localize "STR_DUWS_ARSENAL_EXIT";
        player setVariable ["DUWS_isRestrictedArsenal", nil];
    };
}] call BIS_fnc_addScriptedEventHandler;