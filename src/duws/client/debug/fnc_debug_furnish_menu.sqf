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

private _sets = ["living", "sleeping", "work"];
private _rows = [];
{
    _rows pushBack [_x, {
        _this params ["_t", "_s"];
        [_t, "debug_furnish", [_s], 0] remoteExec ["fnc_furnish_building", 2];
    }, [_target, _x], [1, 0.667, 0, 1]];
} forEach _sets;
_rows pushBack ["all (living + sleeping + work)", {
    [_this, "debug_furnish", [], 0] remoteExec ["fnc_furnish_building", 2];
}, _target, [1, 0.667, 0, 1]];

private _name = typeOf _target;
if (_name isEqualTo "") then { _name = str _target };

[format ["Furnish %1", _name], _rows] call fnc_open_action_menu;
