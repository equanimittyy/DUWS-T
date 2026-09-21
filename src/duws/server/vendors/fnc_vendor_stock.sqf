// Locality: server -- a class the server cannot resolve must not be sellable, the same rule
// fnc_faction_query enforces for the faction browser.
/*
    One stock list. Params: ["blufor" | "opfor" | "all" | "cars" | "boats"]. Returns
    [[displayName, class], ...] sorted by display name.

    Built once per list and cached. The "all" sweep walks four whole configs, which is far too much to
    pay on every menu open, and no list can change once built: the role keys the side lists read and
    the civilian pools the vehicle lists read are all resolved at campaign start and never rewritten.
*/
if (!isServer) exitWith { [] };
params [["_list", "all"]];

private _cacheVar = format ["DUWS_vendorStock_%1", _list];
private _cached = missionNamespace getVariable [_cacheVar, []];
if (_cached isNotEqualTo []) exitWith { _cached };

private _scope2 = "getNumber (_x >> 'scope') == 2";
private _classes = [];

switch (_list) do {
    // The civilian pools the ambient traffic already draws from, so a dealer sells what the town
    // itself drives and a civ mod's vehicles reach the forecourt with no second detection path.
    case "cars":  { _classes = +(missionNamespace getVariable ["civ_veh_array", []]) };
    case "boats": { _classes = +(missionNamespace getVariable ["civ_boat_array", []]) };

    case "blufor";
    case "opfor": {
        // Read out of config, never by spawning. fnc_create_ammo_lists spawns each key to call
        // getUnitLoadout at a tenth of a second per class; a shop needs both sides and cannot pay
        // that twice.
        {
            private _cfg = configFile >> "CfgVehicles" >> _x;
            {
                { _classes pushBackUnique _x } forEach (getArray (_cfg >> _x));
            } forEach ["weapons", "magazines", "items", "linkedItems"];
            private _bag = getText (_cfg >> "backpack");
            if (_bag != "") then { _classes pushBackUnique _bag };
            // The random-gear lists are flat [class, weight, class, weight, ...] pairs, so only the
            // even indices are classes.
            {
                private _l = getArray (_cfg >> _x);
                for "_i" from 0 to (count _l - 1) step 2 do { _classes pushBackUnique (_l select _i) };
            } forEach ["uniformList", "vestList", "headgearList", "facewearList"];
        } forEach ([_list] call fnc_faction_unit_keylist);
    };

    default {
        // A modded server sells its mods: the sweep is the config as installed, not a curated list.
        {
            { _classes pushBackUnique (configName _x) } forEach (_scope2 configClasses (configFile >> _x));
        } forEach ["CfgWeapons", "CfgMagazines", "CfgGlasses"];
        // Backpacks are the only CfgVehicles class the gear lists carry; a dealer's vehicles come
        // from the civilian pools above. Filtered after the walk rather than inside the condition
        // string: isKindOf on a config entry is newer than the string form, and this sweep is the
        // one place a version difference would silently empty a whole list.
        {
            private _c = configName _x;
            if (_c isKindOf ["Bag_Base", configFile >> "CfgVehicles"]) then { _classes pushBackUnique _c };
        } forEach (_scope2 configClasses (configFile >> "CfgVehicles"));
    };
};

private _rows = [];
{
    private _cfg = [_x] call fnc_vendor_classCfg;
    // Priced first: the price function is the one place that decides what may be sold at all, so a
    // row can never reach the catalogue without a number the server will honour.
    if (!isNull _cfg && {getNumber (_cfg >> "scope") == 2} && {([_x] call fnc_vendor_price) > 0}) then {
        private _name = getText (_cfg >> "displayName");
        _rows pushBack [if (_name isEqualTo "") then {_x} else {_name}, _x];
    };
} forEach _classes;
_rows sort true;

missionNamespace setVariable [_cacheVar, _rows];
["INFO", "VENDOR", format ["stock list '%1' built: %2 classes", _list, count _rows]] call fnc_log;
_rows
