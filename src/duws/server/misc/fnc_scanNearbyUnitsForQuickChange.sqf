// Runs once, the first time a player comes within 50 m of HQ -- the caller owns that trigger.

if (!isServer) exitWith {};

// Quick kits mirror the DUWS role keys exactly: the player adopts a kit that belongs to a unit the
// faction actually fields, never gear copied off whatever WEST unit wandered near HQ. getUnitLoadout
// takes a classname here, so the kit is the unit's config loadout, not one live instance's.

// The class each man role key resolves to -- the kit that is a DUWS key proper, as opposed to the
// extra variants faction detection folded into its pool.
private _reps = [];
{
    if ((_x select 2) isEqualTo "man") then {
        private _v = missionNamespace getVariable [(_x select 0), ""];
        private _rep = if (_v isEqualType []) then { _v param [0, ""] } else { _v };
        if (_rep != "") then { _reps pushBackUnique _rep };
    };
} forEach (["blufor"] call fnc_faction_schema);

// Decorate with a lowercased display-name key, sort lexicographically, strip the key. Alphabetical
// order goes through `sort` on strings because BIS_fnc_sortBy only orders numbers; the className in
// the key breaks display-name ties without ever comparing the loadout arrays.
private _sortByName = {
    private _decorated = _this apply { [toLower (_x select 1), _x select 0, _x] };
    _decorated sort true;
    _decorated apply { _x select 2 }
};

// Key kits before pool variants, each block alphabetical.
private _keyKits = [];
private _poolKits = [];
{
    private _className = _x;
    private _displayName = getText (configFile >> "CfgVehicles" >> _className >> "displayName");
    private _entry = [_className, _displayName, getUnitLoadout _className];
    if (_className in _reps) then { _keyKits pushBack _entry } else { _poolKits pushBack _entry };
} forEach (["blufor"] call fnc_faction_unit_keylist);

private _uniqueLoadouts = (_keyKits call _sortByName) + (_poolKits call _sortByName);

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

["INFO", "GEAR", format ["arsenal updated: %1 weapons, %2 magazines, %3 items, %4 backpacks added",
    count _addedWeapons, count _addedMagazines, count _addedItems, count _addedBackpacks]] call fnc_log;