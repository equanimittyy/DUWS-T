// Locality: client -- a dialog action (shared/includes/request_menu.hpp), so it runs on whoever
// pressed the button.
//
// One button, two verbs: a consumable the player already owns refunds, anything else buys. The
// toggle is deliberate rather than a second button. A refund returns everything it charged and
// re-buying costs the same again, so the pair behaves like swapping a loadout rather than like a
// transaction worth confirming, and the button relabels itself as the selection moves
// (fnc_support_sel_changed) so the verb is never a surprise.
//
// The catalogue and both verbs live in client/supports/fnc_supports_init.sqf. This file is the
// dialog's half: which row is selected, and repainting the list once the verb has landed.
private _sel = lbCurSel 2103;
private _rows = uiNamespace getVariable ["DUWS_support_rows", []];
if (_sel < 0 || {_sel >= count _rows}) exitWith {};

private _def = _rows select _sel;
// A heading carries no def. Absent from the row map rather than guarded by a text comparison,
// which would break the moment a heading were translated.
if (_def isEqualTo []) exitWith {};

private _refunding = (_def select 1) == "CONS" && {[_def select 3] call fnc_support_owned};
private _done = if (_refunding) then { [_def] call fnc_support_refund } else { [_def] call fnc_support_buy };

if (_done) then { [_sel] call fnc_support_list_fill };
