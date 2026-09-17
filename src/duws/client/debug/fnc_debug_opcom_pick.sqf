// Locality: client -- remoteExec'd back to the caller by fnc_debug_opcom with a freshly-read list. Opens the row
// picker; the pick runs its step (fnc_debug_opcom_step), which owns every chain.
if (!hasInterface) exitWith {};
params ["_title", "_rows", "_mode", ["_ctx", ""]];
if (_rows isEqualTo []) exitWith {};

private _c = [1, 0.667, 0, 1];
private _entries = _rows apply {
    _x params ["_key", "_label"];
    [_label, { params ["_key", "_mode", "_ctx"]; [_key, _mode, _ctx] call fnc_debug_opcom_step }, [_key, _mode, _ctx], _c]
};
["OPCOM: " + _title, _entries] call fnc_open_action_menu;
