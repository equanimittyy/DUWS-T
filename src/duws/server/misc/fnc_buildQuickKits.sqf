// Runs once, the first time a player comes within 50 m of HQ -- the caller owns that trigger.

if (!isServer) exitWith {};

// Quick kits mirror the DUWS role keys exactly: the player adopts a kit that belongs to a unit the
// faction actually fields, never gear copied off whatever WEST unit wandered near HQ. getUnitLoadout
// takes a classname here, so the kit is the unit's config loadout, not one live instance's.

private _uniqueLoadouts = [];
{
    private _className = _x;
    private _displayName = getText (configFile >> "CfgVehicles" >> _className >> "displayName");
    _uniqueLoadouts pushBack [_className, _displayName, getUnitLoadout _className];
} forEach (["blufor"] call fnc_faction_unit_keylist);

// Alphabetical by display name (what the player reads). Decorate with a lowercased key, sort, strip:
// `sort` orders strings, where BIS_fnc_sortBy only orders numbers; the className breaks ties so the
// loadout arrays are never compared.
_uniqueLoadouts = _uniqueLoadouts apply { [toLower (_x select 1), _x select 0, _x] };
_uniqueLoadouts sort true;
_uniqueLoadouts = _uniqueLoadouts apply { _x select 2 };

blufor_quickChange_loadouts_scanned = _uniqueLoadouts;
publicVariable "blufor_quickChange_loadouts_scanned";

["INFO", "GEAR", format ["Collected %1 quick-kit unit types from role keys.", count _uniqueLoadouts]] call fnc_log;

private _addedWeapons = [];
private _addedMagazines = [];
private _addedItems = [];
private _addedBackpacks = [];

// getUnitLoadout nests classnames inside arrays; recurse to pull every string out.
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

    {
        private _class = _x;
        if (_class == "") then { continue };

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
                    // Equipment covers helmets, vests, uniforms, glasses, etc.
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
            if (isClass (configFile >> "CfgMagazines" >> _class)) then {
                if !(_class in _addedMagazines) then {
                    [missionNamespace, [_class], true] call BIS_fnc_addVirtualMagazineCargo;
                    _addedMagazines pushBack _class;
                    if (duws_log_level >= 4) then { ["DEBUG", "GEAR", format ["Added magazine: %1", _class]] call fnc_log; };
                };
            } else {
                if (isClass (configFile >> "CfgVehicles" >> _class) && {getNumber (configFile >> "CfgVehicles" >> _class >> "isBackpack") == 1}) then {
                    if !(_class in _addedBackpacks) then {
                        [missionNamespace, [_class], true] call BIS_fnc_addVirtualBackpackCargo;
                        _addedBackpacks pushBack _class;
                        if (duws_log_level >= 4) then { ["DEBUG", "GEAR", format ["Added backpack: %1", _class]] call fnc_log; };
                    };
                } else {
                    // Misc items: FirstAidKit, Medikit, etc.
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

// Fold the freshly-added classes into the friendly set. This runs after fnc_create_ammo_lists took its
// DUWS_friendlyArsenal snapshot at boot, so these standard-issue role-key classes are absent from it --
// without this the count overlay reads them as an empty pool ([0]): unlimited in Hybrid, unseeded in
// Limited. Only genuinely-new classes are seeded, so a boot-seeded count is never reset here.
private _addedClasses = _addedWeapons + _addedMagazines + _addedItems + _addedBackpacks;
private _friendly = missionNamespace getVariable ["DUWS_friendlyArsenal", []];
private _newFriendly = _addedClasses select { !(_x in _friendly) };
if (count _newFriendly > 0) then {
    DUWS_friendlyArsenal = _friendly + _newFriendly;
    publicVariable "DUWS_friendlyArsenal";
    // Limited has no unlimited floor: seed the new standard-issue classes into the pool at the boot
    // seed count, matching fnc_create_ammo_lists, so they start stocked instead of at zero.
    if (DUWS_arsenalLimited) then {
        { [_x, DUWS_limitedSeed] call fnc_captured_pool_setCount; } forEach _newFriendly;
        publicVariable "DUWS_capturedPool";
    };
};

// Log unconditionally (even when 0 new) so an RPT proves this merge branch ran: a stale build without
// the fix prints no such line, making "did the count fix load?" answerable from the log alone.
["INFO", "GEAR", format ["friendly set: folded %1 new of %2 role-key classes (mode: %3)",
    count _newFriendly, count _addedClasses, ["Hybrid", "Limited"] select DUWS_arsenalLimited]] call fnc_log;

["INFO", "GEAR", format ["arsenal updated: %1 weapons, %2 magazines, %3 items, %4 backpacks added",
    count _addedWeapons, count _addedMagazines, count _addedItems, count _addedBackpacks]] call fnc_log;