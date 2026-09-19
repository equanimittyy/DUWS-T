// Locality: client -- the Debug menu's OPCOM orders page, so it runs on whoever opened it. Every row hands off to the
// server's fnc_debug_opcom, since the OPCOM store lives server-side; lists return via the picker.
#include "..\..\shared\includes\debug_menu.hpp"
if (!hasInterface) exitWith {};
// Re-checked, not trusted to the parent: this is publicVariable'd, so any client holds a callable copy -- same
// reason fnc_debug_menu re-gates.
if (!((vehiclevarname player) in game_master)) exitWith {};

["OPCOM orders", [
    DBG_BACK("opcom"),
    ["Recruit a unit",      { ["recruitlist", "", "", "", player] remoteExec ["fnc_debug_opcom", 2] }, [], DBG_ACTION],
    ["Order a unit or gun", { ["tasklist",    "", "", "", player] remoteExec ["fnc_debug_opcom", 2] }, [], DBG_ACTION],
    ["Defensive taskings",  { ["zonelist", "", "zonebuy", "", player] remoteExec ["fnc_debug_opcom", 2] }, [], DBG_ACTION],
    ["List taskings",       { ["list",        "", "", "", player] remoteExec ["fnc_debug_opcom", 2] }, [], DBG_ACTION],
    ["Tasking unit status (click map)", {
        ["Select a tasking unit.", "Dev tool: the nearest tasking's type, strength and order.",
            { params ["_pos"]; ["unitstatus", _pos, "", "", player] remoteExec ["fnc_debug_opcom", 2] }] call fnc_debug_map_click;
    }, [], DBG_MAP],
    ["Ferry status",        { ["ferry",       "", "", "", player] remoteExec ["fnc_debug_opcom", 2] }, [], DBG_ACTION]
]] call fnc_open_action_menu;
