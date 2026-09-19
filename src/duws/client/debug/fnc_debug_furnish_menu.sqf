// Locality: client -- the row handlers below remoteExec the furnish to the server. Reached from
// fnc_debug_menu.sqf, which captures the object under the cursor before its dialog opens and passes it in.
// Strings are English-only for the same reason as the other debug menus.
#include "..\..\shared\includes\debug_menu.hpp"
if (!hasInterface) exitWith {};

// Re-checked rather than trusted to the caller: this function is publicVariable'd, so every client holds a
// copy it can call, and each row makes the server build props on demand.
if (!((vehiclevarname player) in game_master)) exitWith {};

params [["_target", objNull]];
if (isNull _target) exitWith {
    hint "Furnish (debug)\n\nNothing was under the cursor when the Debug menu\nopened. Look at a building first, then open Debug.";
};

private _rows = [DBG_BACK("cursor"), ["Furnish", {
    [_this, "debug_furnish", 0] remoteExec ["fnc_furnish_building", 2];
}, _target, DBG_ACTION]];

{
    _x params ["_label", "_mode"];
    private _on = (missionNamespace getVariable ["DUWS_dbgFurnishOn", false]) && {(missionNamespace getVariable ["DUWS_dbgFurnishMode", ""]) == _mode};
    _rows pushBack [format ["%1 [%2]", _label, ["off", "on"] select _on], { _this call fnc_debug_furnish_view }, [_target, _mode], [DBG_OFF, DBG_ON] select _on];
} forEach [["Grid overlay: state (open / near / blocked)", "state"], ["Grid overlay: rooms", "room"]];

private _name = typeOf _target;
if (_name isEqualTo "") then { _name = str _target };

[format ["Furnish %1", _name], _rows] call fnc_open_action_menu;
