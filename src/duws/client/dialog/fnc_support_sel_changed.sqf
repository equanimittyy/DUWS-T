// Locality: client -- an onLBSelChanged handler on the supports list (shared/includes/request_menu.hpp).
//
// The one button both buys and refunds, so it has to say which. A fixed "UNLOCK" over a list where
// any owned consumable would instead refund is a misclick with a price on it.
params ["_control", "_sel"];

private _rows = uiNamespace getVariable ["DUWS_support_rows", []];
private _label = "STR_DUWS_T_bp73qs16";

if (_sel >= 0 && {_sel < count _rows}) then {
    private _def = _rows select _sel;
    // A heading is an empty def and keeps the buy label: it cannot be actioned either way.
    if (!(_def isEqualTo []) && {(_def select 1) == "CONS"} && {[_def select 3] call fnc_support_owned}) then {
        _label = "STR_DUWS_T_SUPPORT_REFUND_BUTTON";
    };
};

ctrlSetText [1603, localize _label];
