// Locality: client -- the row handlers below run on whoever opened the menu.
/*
    Developer tool: pick which search source to flag the object under the cursor with. Reached
    from fnc_debug_menu.sqf, which captures that object and passes it in. Strings are English-only
    for the same reason as that file.
*/
#include "..\..\shared\includes\debug_menu.hpp"
if (!hasInterface) exitWith {};

// Re-checked rather than trusted to the caller: this function is publicVariable'd, so every
// client holds a copy it can call.
if (!((vehiclevarname player) in game_master)) exitWith {};

params [["_target", objNull]];
if (isNull _target) exitWith {
    hint "Search flag (debug)\n\nNothing was under the cursor when the Debug menu\nopened. Look at the object first, then open Debug.";
};

// Named here because DUWS_searchSources is server-only and never broadcast. The server answers a
// name it does not hold with a hint, so a source renamed out from under this list fails loudly
// rather than flagging nothing.
private _sources = ["objective", "civ_frisk"];

private _rows = [DBG_BACK("cursor")];
{
    _rows pushBack [_x, {
        _this params ["_target", "_source"];
        [player, _target, _source] remoteExec ["fnc_debug_search_flag", 2];
    }, [_target, _x], DBG_ACTION];
} forEach _sources;

private _name = typeOf _target;
if (_name isEqualTo "") then { _name = str _target };

[format ["Flag %1 as searchable", _name], _rows] call fnc_open_action_menu;
