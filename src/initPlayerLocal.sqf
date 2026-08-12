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

// The player's balance IS the Money_roll (plus intel) they carry, so any operation that rewrites the
// whole inventory -- an arsenal edit, a quick-kit setUnitLoadout -- would delete it. Stash pulls
// every carried money/intel class out and returns [[class, n], ...]; regrant hands that back, into
// inventory where it fits and dropped at the player's feet where it does not, so a full pack loses
// none. canAdd is checked per instance so a piece that will not fit is never added and then also
// dropped. Both run client-local on player; the overflow drop is a server-side remoteExec.
DUWS_fnc_money_stash = {
    private _stash = [];
    {
        private _cls = _x;
        private _n = { _x == _cls } count (itemsWithMagazines player);
        if (_n > 0) then {
            _stash pushBack [_cls, _n];
            for "_i" from 1 to _n do { player removeItem _cls; player removeMagazine _cls; };
        };
    } forEach DUWS_forcedRemoveItems;
    _stash
};

DUWS_fnc_money_regrant = {
    params [["_stash", []]];
    private _dropPairs = [];
    {
        _x params ["_cls", "_n"];
        private _isMag = isClass (configFile >> "CfgMagazines" >> _cls);
        private _over = 0;
        for "_i" from 1 to _n do {
            if (player canAdd _cls) then {
                if (_isMag) then { player addMagazine _cls; } else { player addItem _cls; };
            } else {
                _over = _over + 1;
            };
        };
        if (_over > 0) then { _dropPairs pushBack [_cls, _over]; };
    } forEach _stash;
    if (count _dropPairs > 0) then { [_dropPairs, getPosATL player] remoteExec ["fnc_money_drop", 2]; };
    _dropPairs
};

// restricted-arsenal handler: whitelist filter plus forced money/intel removal
DUWS_fnc_arsenal_restricted = {
    // Whitelist is every virtual shelf, not just weapons: the strip below runs on all categories, so
    // a weapons-only whitelist would strip every friendly uniform, vest and item. The foreign pool is
    // stocked onto these same cargo vars on open, so banked captured gear is permitted here too.
    private _whitelist = [];
    {
        _whitelist append flatten (missionNamespace getVariable [_x, []]);
    } forEach ["bis_addVirtualWeaponCargo_cargo", "bis_addVirtualItemCargo_cargo",
        "bis_addVirtualMagazineCargo_cargo", "bis_addVirtualBackpackCargo_cargo"];
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

// Remove N instances of a class from the player, category-appropriate: weapons via
// removeWeaponGlobal, magazines via removeMagazine, everything else via removeItem. Each call
// removes one instance, so the loop strips exactly the overdraw and leaves the granted count.
DUWS_fnc_strip_n = {
    params ["_cls", "_n"];
    private _isWeapon = isClass (configFile >> "CfgWeapons" >> _cls) && {(([_cls] call BIS_fnc_itemType) select 0) isEqualTo "Weapon"};
    private _isMag = isClass (configFile >> "CfgMagazines" >> _cls);
    for "_i" from 1 to _n do {
        if (_isWeapon) then { player removeWeaponGlobal _cls; }
        else {
            if (_isMag) then { player removeMagazine _cls; } else { player removeItem _cls; };
        };
    };
};

// Which virtual-cargo shelf a class belongs on. Weapons, magazines and backpacks each have their
// own; everything else is an item.
DUWS_fnc_cargoType = {
    params ["_cls"];
    if (isClass (configFile >> "CfgWeapons" >> _cls) && {(([_cls] call BIS_fnc_itemType) select 0) isEqualTo "Weapon"}) exitWith { "weapon" };
    if (isClass (configFile >> "CfgMagazines" >> _cls)) exitWith { "magazine" };
    if (isClass (configFile >> "CfgVehicles" >> _cls) && {getNumber (configFile >> "CfgVehicles" >> _cls >> "isBackpack") == 1}) exitWith { "backpack" };
    "item"
};

// Add (_add true) or clear (_add false) a foreign class on the local shelf. The captured pool is
// stocked onto the client's own cargo on open and cleared back off on close, so the shelf shows the
// pool's current contents and never accumulates stale foreign gear across sessions.
DUWS_fnc_shelfForeign = {
    params ["_cls", "_type", "_add"];
    switch (_type) do {
        case "weapon":   { [missionNamespace, _cls, _add] call BIS_fnc_addVirtualWeaponCargo; };
        case "magazine": { [missionNamespace, _cls, _add] call BIS_fnc_addVirtualMagazineCargo; };
        case "backpack": { [missionNamespace, _cls, _add] call BIS_fnc_addVirtualBackpackCargo; };
        default          { [missionNamespace, _cls, _add] call BIS_fnc_addVirtualItemCargo; };
    };
};

// Stock the shelf for a restricted arsenal open and return the edits to undo on close, as
// [_addedForeign, _hiddenFriendly, _ammoList]. Caller guards on restricted mode; Full stocks nothing.
DUWS_fnc_arsenal_stock = {
    private _limited = missionNamespace getVariable ["DUWS_arsenalLimited", false];
    private _trackAmmo = missionNamespace getVariable ["DUWS_trackAmmo", false];
    private _friendly = missionNamespace getVariable ["DUWS_friendlyArsenal", []];
    private _pool = missionNamespace getVariable ["DUWS_capturedPool", []];

    private _addedForeign = [];
    private _hiddenFriendly = [];
    private _ammoList = [];

    // Banked foreign gear onto the shelf so it is takeable and the whitelist strip permits it.
    // Friendly-in-pool (Limited's seed) is already on the shelf from the boot build, so only
    // truly-foreign classes are added here.
    {
        _x params ["_cls", "_cnt"];
        if (_cnt > 0 && {!(_cls in _friendly)}) then {
            private _type = [_cls] call DUWS_fnc_cargoType;
            [_cls, _type, true] call DUWS_fnc_shelfForeign;
            _addedForeign pushBack [_cls, _type];
        };
    } forEach _pool;

    // Limited hides friendly gear that is fully depleted, so the shelf shows only what is in
    // stock. Magazines are exempt while ammo is untracked -- they are always free.
    if (_limited) then {
        {
            private _cls = _x;
            if (!((isClass (configFile >> "CfgMagazines" >> _cls)) && !_trackAmmo)) then {
                private _i = _pool findIf { (_x select 0) isEqualTo _cls };
                if (_i < 0 || {((_pool select _i) select 1) <= 0}) then {
                    private _type = [_cls] call DUWS_fnc_cargoType;
                    [_cls, _type, false] call DUWS_fnc_shelfForeign;
                    _hiddenFriendly pushBack [_cls, _type];
                };
            };
        } forEach _friendly;
    };

    // Ammo untracked: put the enemy faction's magazines on the shelf so captured weapons have
    // ammo. Friendly mags are already there; subtract them so the close removal cannot strip one.
    if (!_trackAmmo) then {
        _ammoList = (missionNamespace getVariable ["opfor_ammobox_magazines", []]) - _friendly;
        [missionNamespace, _ammoList, true] call BIS_fnc_addVirtualMagazineCargo;
    };

    [_addedForeign, _hiddenFriendly, _ammoList]
};

// Close a restricted arsenal: settle the captured pool (server strips the overdrawn foreign), then
// undo the shelf edits DUWS_fnc_arsenal_stock made. Takes the open-time baseline loadout and the three
// edit lists it returned. Caller guards on restricted mode.
DUWS_fnc_arsenal_unstock = {
    params ["_openLoadout", "_addedForeign", "_hiddenFriendly", "_ammoList"];

    duws_pool_seq = (missionNamespace getVariable ["duws_pool_seq", 0]) + 1;
    private _replyVar = format ["duws_pool_reply_%1", duws_pool_seq];
    [_openLoadout, getUnitLoadout player, player, _replyVar] remoteExec ["fnc_captured_pool_settle", 2];
    private _deadline = diag_tickTime + 5;
    waitUntil { !isNil _replyVar || {diag_tickTime > _deadline} };
    private _excess = (missionNamespace getVariable [_replyVar, [false, []]]) select 1;
    missionNamespace setVariable [_replyVar, nil];
    { _x params ["_cls", "_ex"]; [_cls, _ex] call DUWS_fnc_strip_n; } forEach _excess;

    // Clear the foreign gear back off, restore any friendly hidden as depleted, and pull the free
    // enemy magazines back off, so the shelf never carries stale gear into the next open.
    { _x params ["_cls", "_type"]; [_cls, _type, false] call DUWS_fnc_shelfForeign; } forEach _addedForeign;
    { _x params ["_cls", "_type"]; [_cls, _type, true] call DUWS_fnc_shelfForeign; } forEach _hiddenFriendly;
    if (count _ammoList > 0) then { [missionNamespace, _ammoList, false] call BIS_fnc_addVirtualMagazineCargo; };
};

[ missionNamespace, "arsenalOpened", {
    [] spawn {
        scriptName "Arsenal enforcer";
        waitUntil { sleep 0.1; !isNull (uiNamespace getVariable ["RscDisplayArsenal", displayNull]) };

        private _isRestricted = player getVariable ["DUWS_isRestrictedArsenal", false];

        // Money/intel out of the editable loadout for the whole session, then restored on close. The
        // arsenal deletes items on edit and the player's balance IS the Money_roll they carry, so
        // leaving it in would burn it. Both modes -- this is the money bug, independent of the pool.
        private _moneyStash = call DUWS_fnc_money_stash;

        // Close-diff baseline: taken after money removal, so neither money nor intel can register as a
        // foreign withdrawal. Never reassigned; _refLoadout tracks live edits separately.
        private _openLoadout = getUnitLoadout player;

        // Stock the shelf (restricted only) and keep the returned edit lists for the close cleanup.
        private _stock = if (_isRestricted) then { call DUWS_fnc_arsenal_stock } else { [[], [], []] };
        _stock params ["_addedForeign", "_hiddenFriendly", "_ammoList"];

        // Live re-stock needs the friendly set (foreign is never friendly) and the classes already on
        // the shelf, so the loop only adds genuinely-new banked gear.
        private _friendly = missionNamespace getVariable ["DUWS_friendlyArsenal", []];
        private _stockedForeign = _addedForeign apply { _x select 0 };

        private _refLoadout = getUnitLoadout player;
        private _changeThreshold = 10;

        // Item-count overlay. Restricted modes only -- Full is the whole-config unlimited arsenal,
        // where a per-row [∞] stamp is meaningless and only races BIS's repopulation of a huge list.
        // Painted every frame: BIS rebuilds a weapon's attachment sublists on each selection with no
        // event to hook, so only a per-frame re-stamp catches the rebuild before the plain rows are on
        // screen long enough to flicker. paintCounts is near-free on frames where nothing was rebuilt
        // (it skips any list already carrying the prefix); forcePaint makes the first frame stamp, and
        // later makes a live re-stock or insert re-stamp the list it appended an unprefixed row to.
        // Debug aid (DEBUG level only): arm the [0]-row collector paintCounts fills, so the close-time
        // diagnostic below can report what the overlay stamped [0] and why. Free when DEBUG is off.
        if (duws_log_level >= 4) then { DUWS_dbg_zeroRows = [] };
        private _paintEH = -1;
        if (_isRestricted) then {
            missionNamespace setVariable ["DUWS_arsenal_forcePaint", true];
            _paintEH = addMissionEventHandler ["EachFrame", {
                private _d = uiNamespace getVariable ["RscDisplayArsenal", displayNull];
                if (!isNull _d) then { [_d] call DUWS_fnc_arsenal_paintCounts; };
            }];
        };

        private _lastRestock = diag_tickTime;
        while { sleep 0.2; !isNull (uiNamespace getVariable ["RscDisplayArsenal", displayNull]) } do {
            if (_isRestricted) then {
                private _now = diag_tickTime;
                if (_now - _lastRestock > 0.5) then {
                    _lastRestock = _now;
                    private _display = uiNamespace getVariable ["RscDisplayArsenal", displayNull];
                    private _inserted = false;
                    // Live re-stock: a foreign class banked into the pool since open (a just-dropped item
                    // settled, a loot cache) goes on the shelf and straight into its category list, so it
                    // appears without a full close/reopen or tab switch. Tracked in _addedForeign so the
                    // close cleanup still clears it back off.
                    {
                        _x params ["_cls", "_cnt"];
                        if (_cnt > 0 && {!(_cls in _friendly)} && {!(_cls in _stockedForeign)}) then {
                            private _type = [_cls] call DUWS_fnc_cargoType;
                            [_cls, _type, true] call DUWS_fnc_shelfForeign;
                            [_display, _cls] call DUWS_fnc_arsenal_insert;
                            _addedForeign pushBack [_cls, _type];
                            _stockedForeign pushBack _cls;
                            _inserted = true;
                        };
                    } forEach (missionNamespace getVariable ["DUWS_capturedPool", []]);

                    // Standard-issue gear folded in after open (a quick-kit built on first HQ approach)
                    // grows the friendly set; surface that delta the same way, so new guns show at once.
                    private _liveFriendly = missionNamespace getVariable ["DUWS_friendlyArsenal", []];
                    if (count _liveFriendly != count _friendly) then {
                        { [_display, _x] call DUWS_fnc_arsenal_insert; } forEach (_liveFriendly - _friendly);
                        _friendly = _liveFriendly;
                        _inserted = true;
                    };

                    // A freshly-inserted row has no count prefix yet; force a full re-stamp next frame.
                    if (_inserted) then { missionNamespace setVariable ["DUWS_arsenal_forcePaint", true]; };
                };
            };

            private _currentLoadout = getUnitLoadout player;
            if (_currentLoadout isNotEqualTo _refLoadout) then {
                private _changeCount = [_refLoadout, _currentLoadout] call DUWS_fnc_countLoadoutChanges;

                // Restricted mode strips anything off the shelf (friendly plus pooled foreign) on a
                // large change; per-class counts are settled on close.
                if (_isRestricted && {_changeCount >= _changeThreshold}) then {
                    [] call DUWS_fnc_arsenal_restricted;
                };

                _refLoadout = _currentLoadout;
            };
        };

        // Debug aid: report each class the overlay stamped [0] with whether some friendly class lists it
        // as baseWeapon -- true means a preset is friendly but its base row was not folded (a preset/base
        // arsenal mismatch), false means the class reached the shelf from a path the friendly build never
        // saw. DEBUG level only; armed at open.
        if (_isRestricted && {!isNil "DUWS_dbg_zeroRows"}) then {
            private _fr = missionNamespace getVariable ["DUWS_friendlyArsenal", []];
            private _detail = DUWS_dbg_zeroRows apply {
                private _c = _x;
                private _hasPreset = (_fr findIf { isClass (configFile >> "CfgWeapons" >> _x) && {getText (configFile >> "CfgWeapons" >> _x >> "baseWeapon") == _c} }) >= 0;
                [_c, _hasPreset]
            };
            ["DEBUG", "GEAR", format ["arsenal [0] rows (cls, presetInFriendly)=%1", _detail]] call fnc_log;
        };

        // Close. Drop the per-frame painter first so it cannot run against a tearing-down display.
        if (_paintEH >= 0) then {
            removeMissionEventHandler ["EachFrame", _paintEH];
        };

        if (_isRestricted) then {
            [_openLoadout, _addedForeign, _hiddenFriendly, _ammoList] call DUWS_fnc_arsenal_unstock;
        };

        // Hand the money back into inventory, overflow dropped at the player's feet.
        private _dropPairs = [_moneyStash] call DUWS_fnc_money_regrant;

        // Dropped cash is the player's own news at the moment they closed the arsenal, so it goes to
        // the hint box (per-player), not a team card. Only money is reported: it is the balance.
        private _moneyDropped = 0;
        { if ((_x select 0) isEqualTo "Money_roll") then { _moneyDropped = _x select 1; }; } forEach _dropPairs;
        if (_moneyDropped > 0) then { hint format [localize "STR_DUWS_ARSENAL_MONEY_DROPPED", _moneyDropped]; };

        player setVariable ["DUWS_isRestrictedArsenal", nil];
    };
}] call BIS_fnc_addScriptedEventHandler;