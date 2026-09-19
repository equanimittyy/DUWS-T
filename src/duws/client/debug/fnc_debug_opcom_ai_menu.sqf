// Locality: client -- a submenu function value in fnc_debug_menu.
if (!hasInterface) exitWith {};
// Re-checked, not trusted to the parent: this is publicVariable'd, so any client holds a callable copy.
if (!((vehiclevarname player) in game_master)) exitWith {};

private _c = [1, 0.667, 0, 1];
["OPCOM AI", [
    ["Mode: off",        { ["aimode", "off", "", "", player] remoteExec ["fnc_debug_opcom", 2] }, [], _c],
    ["Mode: random",     { ["aimode", "random", "", "", player] remoteExec ["fnc_debug_opcom", 2] }, [], _c],
    ["Pick once",        { ["pickonce", "", "", "", player] remoteExec ["fnc_debug_opcom", 2] }, [], _c],
    ["Overlay (on/off)", fnc_debug_opcom_ai_overlay, [], _c]
]] call fnc_open_action_menu;
