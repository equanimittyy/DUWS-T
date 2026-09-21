// Locality: client -- an inventory add takes effect only where the unit is local.
//
// The regrant is all-or-nothing per class, so an empty return is the whole payout in the pack.
params ["_class", "_count", "_foundLine"];

private _dropped = ([[[_class, _count]]] call DUWS_fnc_money_regrant) isNotEqualTo [];
hint format ["%1\n%2", _foundLine,
    localize (["STR_DUWS_T_LOOT_TAKEN", "STR_DUWS_T_LOOT_DROPPED"] select _dropped)];
