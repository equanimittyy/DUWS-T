// Locality: the client viewing the map. Builds the right-hand sidebar on the open map
// (findDisplay 12) and tears it down when the map closes.
//
// Controls are created on the map display itself, not in a dialog: a dialog draws over the map
// and the readout underneath it goes blind (the same reason fnc_map_prompt draws on display 12).
// The sidebar buttons are interactive, so unlike the prompt banner they capture their own clicks
// -- the map's onMapSingleClick still fires everywhere they are not.
//
// Buttons come from a table so a future entry is one row. Each row is [label, ButtonClick code].
if (!hasInterface) exitWith {};
disableSerialization;

private _disp = findDisplay 12;
if (isNull _disp) exitWith {};

private _baseIdc = 91340;
if (!isNull (_disp displayCtrl _baseIdc)) exitWith {};   // already up

private _buttons = [
	[localize "STR_DUWS_T_sidemission_sidebar_btn", { ["toggle"] spawn fnc_sidemission_picker }]
];

private _w = safezoneW * 0.14;
private _h = safezoneH * 0.05;
private _x = safezoneX + safezoneW - _w - (safezoneW * 0.008);
private _y0 = safezoneY + safezoneH * 0.28;
private _gap = safezoneH * 0.012;

{
	_x params ["_label", "_action"];
	private _ctrl = _disp ctrlCreate ["RscButton", _baseIdc + _forEachIndex];
	_ctrl ctrlSetPosition [_x, _y0 + _forEachIndex * (_h + _gap), _w, _h];
	_ctrl ctrlSetText _label;
	_ctrl ctrlAddEventHandler ["ButtonClick", _action];
	_ctrl ctrlCommit 0;
} forEach _buttons;

// The map gives no close callback, so a watcher retires the sidebar (and any open picker) when
// the display goes away. Count captured, because the button list is out of scope in the spawn.
[count _buttons] spawn {
	params ["_count"];
	waitUntil { !visibleMap };
	if (uiNamespace getVariable ["DUWS_sideMissionPickerOn", false]) then {
		["close"] call fnc_sidemission_picker;
	};
	private _d = findDisplay 12;
	for "_i" from 0 to (_count - 1) do {
		private _c = _d displayCtrl (91340 + _i);
		if (!isNull _c) then { ctrlDelete _c };
	};
};
