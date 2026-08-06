// Locality: client -- the row handlers run on whoever opened the menu. Reached from fnc_debug_menu.
/*
    fnc_debug_hardpoint_menu.sqf
    Developer tool: stand a hardpoint of the chosen type up 25 m ahead, guns resolved to the side
    passed in. Reached from fnc_debug_menu.sqf. Strings are English-only for the same reason as that
    file. _this is the side, "opfor" or "blufor".
*/
if (!hasInterface) exitWith {};

// Re-checked rather than trusted to the caller: this function is publicVariable'd, so every client
// holds a copy, and a spawn makes the server do real work.
if (!((vehiclevarname player) in game_master)) exitWith {};

private _side = _this;
private _types = ["OP", "ROADBLOCK", "MG", "AT", "AA", "MORTAR", "ARTY", "MINEFIELD"];

private _rows = [];
{
    _rows pushBack [_x, {
        params ["_type", "_side"];
        // The position the player is facing, 25 m out, so a spawn lands where they are looking rather
        // than on top of them. The layout faces the player's heading.
        private _p = player getRelPos [25, 0];
        [_type, _side, [_p select 0, _p select 1], getDir player] remoteExec ["fnc_debug_spawn_hardpoint", 2];
        hint format ["Spawning a %1 %2 hardpoint 25 m ahead.\n\nDev tool: the composition is built and its guns\nresolve to the %2 faction. No garrison or streaming\nyet -- those are the next steps.", _type, _side];
    }, [_x, _side], [1,0.667,0,1]];
} forEach _types;

_rows pushBack ["Clear dev hardpoints", {
    ["hpdev"] remoteExec ["fnc_duws_release", 2];
    hint "Releasing every dev-spawned hardpoint.\n\nThey drop their persistent flag and the map sweep\ncollects them once no player is within 300 m.";
}, [], [1,0.667,0,1]];

[format ["Spawn %1 hardpoint", _side], _rows] call fnc_open_action_menu;
