// Locality: server -- a class the server cannot resolve must not be sellable, the same rule
// fnc_faction_query enforces for the faction browser.
/*
    One stock list. Params: [kind ("gear" | "car" | "boat"), list ("civilian" | "blufor" | "opfor" |
    "all")]. Returns [[displayName, class], ...] sorted by display name.

    Built once per list and cached. The "all" sweep walks whole configs, which is far too much to pay on
    every menu open, and no list can change once built: the role keys the side lists read and the
    civilian pools are all resolved at campaign start and never rewritten.
*/
if (!isServer) exitWith { [] };
params [["_kind", "gear"], ["_list", "all"]];

private _cacheVar = format ["DUWS_vendorStock_%1_%2", _kind, _list];
private _cached = missionNamespace getVariable [_cacheVar, []];
if (_cached isNotEqualTo []) exitWith { _cached };

private _scope2 = "getNumber (_x >> 'scope') == 2";
private _classes = [];

private _fnc_rows = {
    params ["_classes"];
    // OPFOR drops what BLUFOR sells and All drops what every other list sells, so one item never shows
    // on two lists at two prices. Lowercased: unit loadout arrays need not match the config's case.
    private _taken = createHashMap;
    {
        { _taken set [toLower (_x select 1), true] } forEach ([_kind, _x] call fnc_vendor_stock);
    } forEach (switch (_list) do {
        case "opfor": { ["blufor"] };
        // An arms dealer has no Civilian list: asking for one falls through to the whole-config sweep
        // and would empty All.
        case "all": { [["civilian", "blufor", "opfor"], ["blufor", "opfor"]] select (_kind isEqualTo "gear") };
        default { [] };
    });
    private _rows = [];
    {
        private _cfg = [_x] call fnc_vendor_classCfg;
        // Priced first: the price function is the one place that decides what may be sold at all, so
        // a row can never reach the catalogue without a number the server will honour.
        if (!isNull _cfg && {!(toLower _x in _taken)} && {getNumber (_cfg >> "scope") == 2}
            && {([_x, _list] call fnc_vendor_price) > 0}) then {
            private _name = getText (_cfg >> "displayName");
            _rows pushBack [if (_name isEqualTo "") then {_x} else {_name}, _x];
        };
    } forEach _classes;
    _rows sort true;

    missionNamespace setVariable [_cacheVar, _rows];
    ["INFO", "VENDOR", format ["stock list '%1/%2' built: %3 classes", _kind, _list, count _rows]] call fnc_log;
    _rows
};

if (_kind isNotEqualTo "gear") exitWith {
    switch (_list) do {
        // The civilian pools the ambient traffic already draws from, so a dealer sells what the town
        // itself drives and a civ mod's vehicles reach the forecourt with no second detection path.
        case "civilian": {
            private _pool = ["civ_veh_array", "civ_boat_array"] select (_kind isEqualTo "boat");
            _classes = +(missionNamespace getVariable [_pool, []]);
        };
        case "blufor";
        case "opfor": {
            _classes = [_list, "vehicle"] call fnc_faction_unit_keylist;
            // The role keys name only what the AI fields; BLUFOR's unarmed transports live in the
            // request menu alone.
            if (_list isEqualTo "blufor") then {
                { _classes pushBackUnique (_x select 0) } forEach (["VEHICLE"] call fnc_faction_rqst_list);
            };
        };
        default {
            _classes = (_scope2 configClasses (configFile >> "CfgVehicles")) apply { configName _x };
        };
    };
    _classes = _classes select { [_kind, _x] call fnc_vendor_hullFits };
    [_classes] call _fnc_rows
};

switch (_list) do {
    case "blufor";
    case "opfor": {
        // Read out of config, never by spawning: a shop needs both sides. Attachments come off the class
        // loadout, because an ORBAT export names bare guns in weapons[].
        {
            private _cfg = configFile >> "CfgVehicles" >> _x;
            { _classes pushBackUnique _x } forEach ([[_x] call fnc_faction_class_loadout] call fnc_loadout_attachments);
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
        // Backpacks are the only CfgVehicles class the gear lists carry. Filtered after the walk rather
        // than inside the condition string: isKindOf on a config entry is newer than the string form,
        // and this sweep is the one place a version difference would silently empty a whole list.
        {
            private _c = configName _x;
            if (_c isKindOf ["Bag_Base", configFile >> "CfgVehicles"]) then { _classes pushBackUnique _c };
        } forEach (_scope2 configClasses (configFile >> "CfgVehicles"));
    };
};

[_classes] call _fnc_rows
