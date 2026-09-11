// Locality: server -- reads the engine config to drop unresolved classes, and is called only by the
// server-side placer. Definition only; registered in server_fnc_init.sqf before fnc_furnish_building,
// which consumes it. Server-only, not broadcast.
//
// Reads furniture_catalog.hpp into two cached lookups, built once on first call:
//   DUWS_furnitureCatalog   class -> [role, frontYaw, family, seats, slot, maxPerRoom]
//   DUWS_furnitureRoleIndex role  -> [[class, family, slot], ...]   (the placer picks a class per role, by family or slot)
// A class resolving in none of CfgVehicles/CfgMagazines/CfgWeapons is logged and skipped -- an
// unknown furniture class is our own gap, distinct from an unknown building class the grid still handles.

fnc_furnish_catalog = {
    private _cached = missionNamespace getVariable ["DUWS_furnitureCatalog", createHashMap];
    if (count _cached > 0) exitWith { _cached };

    private _rows = [
    #include "..\..\shared\includes\furniture_catalog.hpp"
    ];

    private _cat = createHashMap;
    private _byRole = createHashMap;
    private _dropped = 0;
    {
        _x params ["_cls", "_role", "_fy", "_family", "_seats", ["_slot", ""], ["_max", 0]];
        private _resolves = isClass (configFile >> "CfgVehicles" >> _cls)
            || {isClass (configFile >> "CfgMagazines" >> _cls)}
            || {isClass (configFile >> "CfgWeapons" >> _cls)};
        if (!_resolves) then {
            _dropped = _dropped + 1;
        } else {
            _cat set [_cls, [_role, _fy, _family, _seats, _slot, _max]];
            private _lst = _byRole getOrDefault [_role, []];
            _lst pushBack [_cls, _family, _slot];
            _byRole set [_role, _lst];
        };
    } forEach _rows;

    if (_dropped > 0) then {
        ["WARN", "FURNISH", format ["catalog: %1 class(es) unresolved and skipped", _dropped]] call fnc_log;
    };
    missionNamespace setVariable ["DUWS_furnitureCatalog", _cat];
    missionNamespace setVariable ["DUWS_furnitureRoleIndex", _byRole];
    _cat
};

// Classes of a role, filtered by _key: for seat/clutter _key is a family (an anchor's companions), for
// anchor a slot ("center"/"wall"). _key "" matches any -- how the wall pool (family "", slot "") is drawn.
// [] when none. Builds the catalog on first use.
fnc_furnish_classesFor = {
    params ["_role", ["_key", ""]];
    call fnc_furnish_catalog;
    private _byRole = missionNamespace getVariable ["DUWS_furnitureRoleIndex", createHashMap];
    (_byRole getOrDefault [_role, []]) select { _key == "" || {_key == (_x select 1)} || {_key == (_x select 2)} } apply { _x select 0 }
};
