// Mirrors shared/includes/defines.hpp, which is config and cannot be included here.
#define GUI_GRID_W  0.025
#define GUI_GRID_H  0.04

#define ROW_H       1.0
#define STATUS_X    6.5
#define ORDERS_X    15.5
#define ROW_W       25

params ["_display"];
private _list = _display displayCtrl 1700;

private _cell = {
	params ["_left", "_width", "_top", "_text"];
	private _ctrl = _display ctrlCreate ["RscText", -1, _list];
	_ctrl ctrlSetPosition [_left * GUI_GRID_W, _top * GUI_GRID_H, _width * GUI_GRID_W, ROW_H * GUI_GRID_H];
	_ctrl ctrlSetFontHeight 0.026;
	_ctrl ctrlSetTextColor [1, 1, 1, 1];
	_ctrl ctrlSetText _text;
	_ctrl ctrlSetTooltip _text;
	_ctrl ctrlCommit 0;
};

private _taskforces = ((missionNamespace getVariable ["DUWS_taskforces", []]) apply {_x select 0}) select {!isNull _x};
if (_taskforces isEqualTo []) exitWith {
	[0, ROW_W, 0, localize "STR_DUWS_T_TASKFORCE_NONE"] call _cell;
};

{
	(_x getVariable ["DUWS_taskforce_status", [0, [], []]]) params ["_alive", "_classes", "_order"];

	private _status = format [localize "STR_DUWS_T_TASKFORCE_ALIVE", _alive];
	if (_classes isNotEqualTo []) then {
		_status = _status + ", " + ((_classes apply {getText (configFile >> "CfgVehicles" >> _x >> "displayName")}) joinString ", ");
	};

	_order params [["_kind", ""], ["_target", ""]];
	private _ordersText = switch (_kind) do {
		case "capture": { format [localize "STR_DUWS_T_TASKFORCE_CAPTURE", _target] };
		case "patrol": { format [localize "STR_DUWS_T_TASKFORCE_PATROL", _target] };
		case "hq": { localize "STR_DUWS_T_TASKFORCE_DEFEND_HQ" };
		default { localize "STR_DUWS_T_TASKFORCE_AWAITING" };
	};

	private _top = _forEachIndex * ROW_H;
	[0, STATUS_X, _top, groupId _x] call _cell;
	[STATUS_X, ORDERS_X - STATUS_X, _top, _status] call _cell;
	[ORDERS_X, ROW_W - ORDERS_X, _top, _ordersText] call _cell;
} forEach _taskforces;
