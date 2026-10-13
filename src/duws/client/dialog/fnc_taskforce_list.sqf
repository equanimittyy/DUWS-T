// Mirrors shared/includes/defines.hpp, which is config and cannot be included here.
#define GUI_GRID_W  0.025
#define GUI_GRID_H  0.04

#define ROW_H       1.0
#define STATUS_X    6.5
#define ORDERS_X    15.5
#define TAKE_X      21.5
#define ROW_W       25.9

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

private _stance = _display displayCtrl 1605;
_stance setVariable ["DUWS_stanceKeys", ["STR_DUWS_T_TASKFORCE_STANCE_ATTACK", "STR_DUWS_T_TASKFORCE_STANCE_BALANCED", "STR_DUWS_T_TASKFORCE_STANCE_DEFEND"]];
// The button steps its own copy, so a click before the broadcast of the last one returns still moves one stance on.
_stance setVariable ["DUWS_stance", DUWS_taskforce_stance];
_stance ctrlSetText format [localize "STR_DUWS_T_TASKFORCE_STANCE", localize ((_stance getVariable "DUWS_stanceKeys") select DUWS_taskforce_stance)];
_stance ctrlAddEventHandler ["ButtonClick", {
	params ["_ctrl"];
	private _next = ((_ctrl getVariable "DUWS_stance") + 1) mod 3;
	_ctrl setVariable ["DUWS_stance", _next];
	_ctrl ctrlSetText format [localize "STR_DUWS_T_TASKFORCE_STANCE", localize ((_ctrl getVariable "DUWS_stanceKeys") select _next)];
	[_next] remoteExec ["fnc_taskforce_stance", 2];
}];

private _taskforces = (missionNamespace getVariable ["DUWS_taskforces", []]) select {!isNull (_x select 0)};
if (_taskforces isEqualTo []) exitWith {
	[0, ROW_W, 0, localize "STR_DUWS_T_TASKFORCE_NONE"] call _cell;
};

{
	_x params ["_group", "", "", "_spawned"];
	(_group getVariable ["DUWS_taskforce_status", [0, [], []]]) params ["_alive", "_classes", "_order"];

	private _status = format [localize "STR_DUWS_T_TASKFORCE_ALIVE", _alive];
	if (_classes isNotEqualTo []) then {
		_status = _status + ", " + ((_classes apply {getText (configFile >> "CfgVehicles" >> _x >> "displayName")}) joinString ", ");
	};

	_order params [["_kind", ""], ["_target", ""]];
	private _ordersText = switch (_kind) do {
		case "capture": { format [localize "STR_DUWS_T_TASKFORCE_CAPTURE", _target] };
		case "patrol": { format [localize "STR_DUWS_T_TASKFORCE_PATROL", _target] };
		case "defend": { format [localize "STR_DUWS_T_TASKFORCE_DEFEND", _target] };
		case "hq": { localize "STR_DUWS_T_TASKFORCE_DEFEND_HQ" };
		default { localize "STR_DUWS_T_TASKFORCE_AWAITING" };
	};

	private _top = _forEachIndex * ROW_H;
	[0, STATUS_X, _top, groupId _group] call _cell;
	[STATUS_X, ORDERS_X - STATUS_X, _top, _status] call _cell;
	[ORDERS_X, TAKE_X - ORDERS_X, _top, _ordersText] call _cell;

	if (!_spawned) then {
		private _take = _display ctrlCreate ["RscButton", -1, _list];
		_take ctrlSetPosition [TAKE_X * GUI_GRID_W, _top * GUI_GRID_H, (ROW_W - TAKE_X) * GUI_GRID_W, ROW_H * GUI_GRID_H];
		_take ctrlSetFontHeight 0.024;
		_take ctrlSetText localize "STR_DUWS_T_TASKFORCE_TAKEBACK";
		_take ctrlSetTooltip localize "STR_DUWS_T_TASKFORCE_TAKEBACK_TIP";
		_take setVariable ["DUWS_taskforce", _group];
		_take ctrlAddEventHandler ["ButtonClick", {
			params ["_ctrl"];
			[_ctrl getVariable "DUWS_taskforce", player] remoteExec ["fnc_taskforce_release", 2];
			closeDialog 0;
		}];
		_take ctrlCommit 0;
	};
} forEach _taskforces;
