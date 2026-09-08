// Locality: client -- the row handlers run on whoever opened the menu. Reached from fnc_debug_menu.
/*
    Developer tool: pick a hardpoint type, then click the open map to stand it up there, guns resolved
    to the side passed in. Reached from fnc_debug_menu.sqf. Strings are English-only for the same reason
    as that file. _this is the side, "opfor" or "blufor".
*/
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

private _rows = [];
{
    _x params ["_label", "_type", "_variant"];
    _rows pushBack [_label, {
        params ["_type", "_side", "_variant", "_label"];
        // Click-to-place on the open map, spawned for the helper's scheduled wait.
        [_type, _side, _variant, _label] spawn {
            params ["_type", "_side", "_variant", "_label"];
            private _pos = [format ["<t size='2' color='#00ffff'>Click the map to place a %1 %2 hardpoint. </t><br/>Dev tool: composition, defenders and a gunner on every static gun, resolved to the %2 faction. Close the map to cancel.", _label, _side]] call fnc_map_pick_pos;
            if (_pos isEqualTo []) exitWith {};
            [_type, _side, [_pos select 0, _pos select 1], 0, _variant] remoteExec ["fnc_debug_spawn_hardpoint", 2];
            hint format ["Spawning a %1 %2 hardpoint at the marked spot.\n\nDev tool: the composition, its defenders and a gunner\non every static gun, all resolved to the %2 faction.", _label, _side];
        };
    }, [_type, _side, _variant, _label], [1,0.667,0,1]];
} forEach _specs;

_rows pushBack ["Clear dev hardpoints", {
    [] remoteExec ["fnc_debug_clear_hardpoints", 2];
    hint "Clearing every dev-spawned hardpoint.\n\nThe defenders are deleted and the composition drops its\npersistent flag; the map sweep collects the props once\nno player is within 300 m.";
}, [], [1,0.667,0,1]];

[format ["Spawn %1 hardpoint", _side], _rows] call fnc_open_action_menu;
