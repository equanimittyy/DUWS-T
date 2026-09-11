// Locality: client -- the row handlers below remoteExec the furnish to the server. Reached from
// fnc_debug_menu.sqf, which captures the object under the cursor before its dialog opens and passes it in.
// Strings are English-only for the same reason as the other debug menus.
if (!hasInterface) exitWith {};

// Re-checked rather than trusted to the caller: this function is publicVariable'd, so every client holds a
// copy it can call, and each row makes the server build props on demand.
if (!((vehiclevarname player) in game_master)) exitWith {};

params [["_target", objNull]];
if (isNull _target) exitWith {
    hint "Furnish (debug)\n\nNothing was under the cursor when the Debug menu\nopened. Look at a building first, then open Debug.";
};

private _rows = [];
_rows pushBack ["furnish", {
    [_this, "debug_furnish", 0] remoteExec ["fnc_furnish_building", 2];
}, _target, [1, 0.667, 0, 1]];

// Geometry overlays (no furniture): the floor-plan grid, coloured by cell state or by room id.
_rows pushBack ["grid overlay: state (open / near / blocked)", { _this call fnc_debug_furnish_view }, [_target, "state"], [0.3, 0.8, 1, 1]];
_rows pushBack ["grid overlay: rooms", { _this call fnc_debug_furnish_view }, [_target, "room"], [0.3, 0.8, 1, 1]];

private _name = typeOf _target;
if (_name isEqualTo "") then { _name = str _target };

[format ["Furnish %1", _name], _rows] call fnc_open_action_menu;
