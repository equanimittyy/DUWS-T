// Locality: client -- the row handlers run on whoever opened the menu. Reached from fnc_debug_menu.
/*
    Developer tool: pick a hardpoint type, then click the open map to stand it up there, guns resolved
    to the side passed in; a minefield takes three clicks, outlining its front and depth. Reached from
    fnc_debug_menu.sqf. Strings are English-only for the same reason as that file. _this is the side,
    "opfor" or "blufor".
*/
#include "..\..\shared\includes\debug_menu.hpp"
if (!hasInterface) exitWith {};

// Re-checked rather than trusted to the caller: this function is publicVariable'd, so every client
// holds a copy, and a spawn makes the server do real work.
if (!((vehiclevarname player) in game_master)) exitWith {};

private _side = _this;
// [menu label, hardpoint type, minefield variant]. The variant is read only by the MINEFIELD build;
// every other type ignores it. Two minefield rows so both mine patterns are placeable.
private _specs = [
    ["OP", "OP", "AT"],
    ["ROADBLOCK", "ROADBLOCK", "AT"],
    ["MG", "MG", "AT"],
    ["GMG", "GMG", "AT"],
    ["AT", "AT", "AT"],
    ["AA", "AA", "AT"],
    ["MORTAR", "MORTAR", "AT"],
    ["ARTY", "ARTY", "AT"],
    ["MINEFIELD (AT)", "MINEFIELD", "AT"],
    ["MINEFIELD (AP)", "MINEFIELD", "AP"]
];

private _placeOne = {
    params ["_type", "_side", "_variant", "_label"];
    [format ["Click the map to place a %1 %2 hardpoint.", _label, _side],
        format ["Dev tool: composition, defenders and a gunner on every static gun, resolved to the %1 faction.", _side],
        {
            params ["_pos", "_args"];
            _args params ["_type", "_side", "_variant", "_label"];
            [_type, _side, [_pos select 0, _pos select 1], 0, _variant] remoteExec ["fnc_debug_spawn_hardpoint", 2];
            hint format ["Spawning a %1 %2 hardpoint at the marked spot.\n\nDev tool: the composition, its defenders and a gunner\non every static gun, all resolved to the %2 faction.", _label, _side];
        }, _this] call fnc_debug_map_click;
};

private _placeField = {
    _this spawn {
        params ["", "_side", "_variant", "_label"];
        private _title = format ["<t size='2' color='#00ffff'>%1 %2</t><br/>", _label, _side];
        private _a = [_title + "Click one end of the front. Close the map to cancel.", {true}, "", true] call fnc_map_pick_pos;
        if (_a isEqualTo []) exitWith {};
        private _markA = createMarkerLocal ["DUWS_dbgMineA", _a];
        _markA setMarkerTypeLocal "mil_dot";
        private _b = [_title + "Click the other end of the front. Close the map to cancel.", {true}, "", true] call fnc_map_pick_pos;
        private _c = [];
        private _cols = 1;
        if (_b isNotEqualTo []) then {
            private _markB = createMarkerLocal ["DUWS_dbgMineB", _b];
            _markB setMarkerTypeLocal "mil_dot";
            _cols = 1 max round ((_a distance2D _b) / DUWS_mineSquare);
            _c = [format ["%1Front %2 m. Click how deep the field runs. Close the map to cancel.", _title, _cols * DUWS_mineSquare]]
                call fnc_map_pick_pos;
        };
        { deleteMarkerLocal _x } forEach ["DUWS_dbgMineA", "DUWS_dbgMineB"];
        if (_c isEqualTo []) exitWith {};

        private _front = _a getDir _b;
        private _rel = ((_a getDir _c) - _front + 360) % 360;
        private _dir = _front + ([-90, 90] select (_rel < 180));
        private _rows = 1 max round ((_a distance2D _c) * abs (sin _rel) / DUWS_mineSquare);
        private _center = [((_a select 0) + (_b select 0)) / 2, ((_a select 1) + (_b select 1)) / 2]
            getPos [_rows * DUWS_mineSquare / 2, _dir];
        ["MINEFIELD", _side, [_center select 0, _center select 1], _dir, _variant, [_cols, _rows]]
            remoteExec ["fnc_debug_spawn_hardpoint", 2];
        hint format ["Laying a %1 m x %2 m %3 minefield.", _cols * DUWS_mineSquare, _rows * DUWS_mineSquare, _variant];
    };
};

private _rows = [DBG_BACK("zones")];
{
    _x params ["_label", "_type", "_variant"];
    _rows pushBack [_label, [_placeOne, _placeField] select (_type isEqualTo "MINEFIELD"), [_type, _side, _variant, _label], DBG_MAP];
} forEach _specs;

[format ["Spawn %1 hardpoint (click map)", _side], _rows] call fnc_open_action_menu;
