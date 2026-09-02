// Locality: any -- pure lookup over reputation, no engine state. Returns the merged weighted event menu
// ([[kind, weight], ...] for fnc_search_drawKind) for a town at reputation _rep: every band whose range
// holds _rep contributes its weights. The bands and their merge rule live in random_event_tables.hpp.
params [["_rep", 0]];

private _bands = [
#include "..\..\shared\includes\random_event_tables.hpp"
];

private _menu = [];
{
	_x params ["_label", "_lo", "_hi", "_weights"];
	if (_rep >= _lo && _rep <= _hi) then { _menu append _weights };
} forEach _bands;
_menu
