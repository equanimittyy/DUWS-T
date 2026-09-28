// Locality: client -- a dialog action (shared/includes/request_menu.hpp), so it runs on whoever
// pressed the button.
//
// UNLOCK buys another copy and REFUND sells one back. Two buttons rather than one that toggles:
// consumables stack, so an owned row is as likely to be bought again as sold.
//
// The catalogue and both verbs live in client/supports/fnc_supports_init.sqf. This file is the
// dialog's half: which row is selected, and repainting the list once the verb has landed.
//
// One verb in flight at a time: a buy tests its cap and free slots before the server round-trip and
// records its copy after it, so overlapping buys all pass. The action is unscheduled, so no second
// click lands between the test and the claim.
params [["_refund", false]];
private _verb = uiNamespace getVariable ["DUWS_support_verb", scriptNull];
if (!isNull _verb && {!scriptDone _verb}) exitWith {};

private _sel = lbCurSel 2103;
private _rows = uiNamespace getVariable ["DUWS_support_rows", []];
if (_sel < 0 || {_sel >= count _rows}) exitWith {};

private _def = _rows select _sel;
// A heading carries no def. Absent from the row map rather than guarded by a text comparison,
// which would break the moment a heading were translated.
if (_def isEqualTo []) exitWith {};

uiNamespace setVariable ["DUWS_support_verb", [_refund, _def, _sel] spawn {
	params ["_refund", "_def", "_sel"];
	private _done = if (_refund) then { [_def] call fnc_support_refund } else { [_def] call fnc_support_buy };
	if (_done) then { [_sel] call fnc_support_list_fill };
}];
