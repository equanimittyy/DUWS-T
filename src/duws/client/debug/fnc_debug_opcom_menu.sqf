// Locality: client -- a submenu function value in fnc_debug_menu, so it runs on whoever opened it. Every row
// hands off to the server's fnc_debug_opcom, since the OPCOM store lives server-side; lists return via the picker.
if (!hasInterface) exitWith {};
// Re-checked, not trusted to the parent: this is publicVariable'd, so any client holds a callable copy -- same
// reason fnc_debug_menu re-gates.
if (!((vehiclevarname player) in game_master)) exitWith {};

private _c = [1, 0.667, 0, 1];
["OPCOM (Phase 3)", [
    ["Recruit a unit",  { ["recruitlist", "", "", "", player] remoteExec ["fnc_debug_opcom", 2] }, [], _c],
    ["Task a tasking",  { ["tasklist",    "", "", "", player] remoteExec ["fnc_debug_opcom", 2] }, [], _c],
    ["List taskings",   { ["list",        "", "", "", player] remoteExec ["fnc_debug_opcom", 2] }, [], _c],
    ["Clear store",     { ["clear",       "", "", "", player] remoteExec ["fnc_debug_opcom", 2] }, [], _c]
]] call fnc_open_action_menu;
