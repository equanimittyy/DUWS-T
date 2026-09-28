// Locality: client -- an onLBSelChanged handler on the supports list (shared/includes/request_menu.hpp).
params ["_control", "_sel"];

private _rows = uiNamespace getVariable ["DUWS_support_rows", []];
private _def = if (_sel >= 0 && {_sel < count _rows}) then { _rows select _sel } else { [] };

ctrlEnable [1617, !(_def isEqualTo []) && {(_def select 1) == "CONS"} && {([_def select 0, _def select 5] call fnc_support_in_hand) > 0}];
