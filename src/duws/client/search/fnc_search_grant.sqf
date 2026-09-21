// Locality: client -- an inventory add takes effect only where the unit is local.
//
// All or nothing, unlike the arsenal's per-item regrant: a part-fitting find would leave the player
// with money in two places and one hint naming both.
params ["_class", "_count", "_foundLine"];

private _fits = player canAdd [_class, _count];
if (_fits) then {
    [[[_class, _count]]] call DUWS_fnc_money_regrant;
} else {
    [[[_class, _count]], getPosATL player] remoteExec ["fnc_money_drop", 2];
};

hint format ["%1\n%2", _foundLine,
    localize (["STR_DUWS_T_SEARCH_LOOT_DROPPED", "STR_DUWS_T_SEARCH_LOOT_TAKEN"] select _fits)];
