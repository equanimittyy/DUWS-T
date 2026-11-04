// Locality: server -- a class the server cannot resolve must not be sellable, the same rule
// fnc_faction_query enforces for the faction browser.
/*
    One stock list. Params: [kind ("gear" | "car" | "boat"), list ("civilian" | "blufor" | "opfor" |
    "all" | "town"), town index]. Returns [[displayName, class, category], ...] sorted by display name,
    where category indexes the kind's DUWS_vendorCategories list.

    Built once per list and cached. The "all" sweep walks whole configs, which is far too much to pay on
    every menu open, and no list can change once built: the role keys the side lists read and the
    civilian pools are all resolved at campaign start and never rewritten.

    "town" is the exception: the Limited arms stock (DUWS_paramArmsStock), rolled per town for each
    rotation window from the other three gear lists. The roll is stored, not cached, because every
    visit in a window must see one stock, and a load must resume it (armsStock).
*/
if (!isServer) exitWith { [] };
params [["_kind", "gear"], ["_list", "all"], ["_town", -1]];

#define ARMS_PICKS 10
#define ARMS_WINDOW 1800

if (_list isEqualTo "town") exitWith {
    private _pool = missionNamespace getVariable ["DUWS_armsPool", createHashMap];
    if (count _pool == 0) then {
        { { _pool set [toLower (_x select 1), _x] } forEach ([_kind, _x] call fnc_vendor_stock) } forEach ["blufor", "opfor", "all"];
        DUWS_armsPool = _pool;
    };
    private _order = DUWS_vendorCategories get _kind;
    private _magCat = _order find "STR_DUWS_T_VENDOR_CAT_MAGAZINE";
    private _gunCats = ["STR_DUWS_T_VENDOR_CAT_PRIMARY", "STR_DUWS_T_VENDOR_CAT_HANDGUN", "STR_DUWS_T_VENDOR_CAT_LAUNCHER"] apply { _order find _x };

    // Atomic: two players at one shop must not each roll and see different stock.
    private _picks = [];
    isNil {
        private _now = call fnc_campaign_now;
        if (_now >= (missionNamespace getVariable ["DUWS_armsWindowEnd", -1])) then {
            DUWS_armsWindowEnd = _now + ARMS_WINDOW;
            DUWS_armsStock = createHashMap;
        };
        _picks = DUWS_armsStock getOrDefault [_town, []];
        if (_picks isEqualTo []) then {
            private _byCat = _order apply { [] };
            { (_byCat select (_y select 2)) pushBack (_y select 1) } forEach _pool;
            {
                if (_forEachIndex != _magCat) then {
                    for "_i" from 1 to (ARMS_PICKS min count _x) do { _picks pushBack (_x deleteAt floor random count _x) };
                };
            } forEach _byCat;
            DUWS_armsStock set [_town, _picks];
        };
    };

    // A class a removed mod defined is not in the pool, so a restored pick of one drops out here.
    private _rows = (_picks apply { _pool getOrDefault [toLower _x, []] }) select { _x isNotEqualTo [] };
    {
        {
            private _row = _pool getOrDefault [toLower _x, []];
            if ((_row param [2, -1]) == _magCat) then { _rows pushBackUnique _row };
        } forEach (compatibleMagazines (_x select 1));
    } forEach (_rows select { (_x select 2) in _gunCats });
    _rows sort true;
    _rows
};

private _cacheVar = format ["DUWS_vendorStock_%1_%2", _kind, _list];
private _cached = missionNamespace getVariable [_cacheVar, []];
if (_cached isNotEqualTo []) exitWith { _cached };

private _scope2 = "getNumber (_x >> 'scope') == 2";
private _classes = [];

// What the engine's Throw and Put muzzles load is hand-thrown or hand-placed by definition, so a mod's
// grenade or charge files with the vanilla ones.
private _handHeld = createHashMap;
{
    private _weapon = configFile >> "CfgWeapons" >> _x;
    {
        { _handHeld set [toLower _x, true] } forEach getArray (_weapon >> _x >> "magazines");
    } forEach getArray (_weapon >> "muzzles");
} forEach ["Throw", "Put"];

// Gear files by the engine's own item typing, so a modded server's kit sorts with no table to keep; a
// hull files by the classifier that prices it.
private _order = DUWS_vendorCategories get _kind;
private _fnc_category = {
    params ["_class"];
    _order find (call {
        if (_kind isEqualTo "boat") exitWith { "STR_DUWS_T_VENDOR_CAT_BOAT" };
        if (_kind isEqualTo "car") exitWith {
            switch ([_class] call DUWS_fnc_vehKind) do {
                case "logi": { "STR_DUWS_T_VENDOR_CAT_LOGI" };
                case "apcIfv";
                case "tank": { "STR_DUWS_T_VENDOR_CAT_ARMOR" };
                case "heliTransport": { "STR_DUWS_T_VENDOR_CAT_HELI" };
                case "uav": { "STR_DUWS_T_VENDOR_CAT_DRONE" };
                default { "STR_DUWS_T_VENDOR_CAT_CAR" };
            }
        };
        if (toLower _class in _handHeld) exitWith { "STR_DUWS_T_VENDOR_CAT_EXPLOSIVE" };
        ([_class] call BIS_fnc_itemType) params ["_cat", "_sub"];
        if (_cat isEqualTo "Mine") exitWith { "STR_DUWS_T_VENDOR_CAT_EXPLOSIVE" };
        if (_cat isEqualTo "Magazine") exitWith { "STR_DUWS_T_VENDOR_CAT_MAGAZINE" };
        if (_cat isEqualTo "Weapon") exitWith {
            switch (_sub) do {
                case "Handgun": { "STR_DUWS_T_VENDOR_CAT_HANDGUN" };
                case "Launcher";
                case "MissileLauncher";
                case "RocketLauncher": { "STR_DUWS_T_VENDOR_CAT_LAUNCHER" };
                default { "STR_DUWS_T_VENDOR_CAT_PRIMARY" };
            }
        };
        switch (_sub) do {
            case "AccessoryMuzzle";
            case "AccessoryPointer";
            case "AccessorySights";
            case "AccessoryBipod": { "STR_DUWS_T_VENDOR_CAT_ATTACHMENT" };
            case "Uniform": { "STR_DUWS_T_VENDOR_CAT_UNIFORM" };
            case "Vest": { "STR_DUWS_T_VENDOR_CAT_VEST" };
            case "Headgear": { "STR_DUWS_T_VENDOR_CAT_HEADGEAR" };
            case "Glasses": { "STR_DUWS_T_VENDOR_CAT_FACEWEAR" };
            case "Backpack": { "STR_DUWS_T_VENDOR_CAT_BACKPACK" };
            default { "STR_DUWS_T_VENDOR_CAT_ITEM" };
        }
    })
};

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
            && {([_x] call fnc_vendor_price) > 0}) then {
            private _name = getText (_cfg >> "displayName");
            _rows pushBack [if (_name isEqualTo "") then {_x} else {_name}, _x, [_x] call _fnc_category];
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
            _classes = if (_kind isEqualTo "boat") then {
                +(missionNamespace getVariable ["civ_boat_array", []])
            } else {
                (missionNamespace getVariable ["civ_veh_array", []]) + (missionNamespace getVariable ["civ_heli_array", []])
            };
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
