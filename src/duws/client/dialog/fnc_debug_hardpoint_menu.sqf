// Locality: client -- the row handlers run on whoever opened the menu. Reached from fnc_debug_menu.
/*
    fnc_debug_hardpoint_menu.sqf
    Developer tool: pick a hardpoint type, then click the open map to stand it up there, guns resolved
    to the side passed in. Reached from fnc_debug_menu.sqf. Strings are English-only for the same reason
    as that file. _this is the side, "opfor" or "blufor".
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
        // Click-to-place on the open map. Spawned so it can hold the map open and wait on the click in
        // a scheduled environment; the position is captured client-side, then handed to the server.
        [_type, _side] spawn {
            params ["_type", "_side"];
            DUWS_dbgHPclicked = false;
            openMap [true, false];
            waitUntil { !isNull (findDisplay 12) };
            // Banner, not hint: the engine draws the hint box beneath the open map, so a hint would be
            // invisible for the whole click phase. Same treatment HQ placement gets.
            [format ["<t size='2' color='#00ffff'>Click the map to place a %1 %2 hardpoint. </t><br/>Dev tool: composition, defenders and a gunner on every static gun, resolved to the %2 faction. Close the map to cancel.", _type, _side]] call fnc_map_prompt;
            onMapSingleClick "DUWS_dbgHPpos = _pos; DUWS_dbgHPclicked = true; onMapSingleClick ''; true";
            waitUntil { DUWS_dbgHPclicked || !visibleMap };
            onMapSingleClick "";
            [""] call fnc_map_prompt;
            if (!DUWS_dbgHPclicked) exitWith {};
            openMap [false, false];
            [_type, _side, [DUWS_dbgHPpos select 0, DUWS_dbgHPpos select 1], 0] remoteExec ["fnc_debug_spawn_hardpoint", 2];
            hint format ["Spawning a %1 %2 hardpoint at the marked spot.\n\nDev tool: the composition, its defenders and a gunner\non every static gun, all resolved to the %2 faction.", _type, _side];
        };
    }, [_x, _side], [1,0.667,0,1]];
} forEach _types;

_rows pushBack ["Clear dev hardpoints", {
    [] remoteExec ["fnc_debug_clear_hardpoints", 2];
    hint "Clearing every dev-spawned hardpoint.\n\nThe defenders are deleted and the composition drops its\npersistent flag; the map sweep collects the props once\nno player is within 300 m.";
}, [], [1,0.667,0,1]];

[format ["Spawn %1 hardpoint", _side], _rows] call fnc_open_action_menu;
