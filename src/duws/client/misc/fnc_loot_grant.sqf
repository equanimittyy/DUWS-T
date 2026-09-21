// Locality: client -- an inventory add takes effect only where the unit is local.
//
// The regrant is all or nothing, so an empty return is the whole payout in the pack.
params ["_class", "_count", "_foundLine"];

private _dropPairs = [[[_class, _count]]] call DUWS_fnc_money_regrant;
hint format ["%1\n\n%2", _foundLine,
    if (_dropPairs isEqualTo []) then { localize "STR_DUWS_T_LOOT_TAKEN" } else { [_dropPairs] call DUWS_fnc_dropped_line }];
