// Locality: any -- pure lookup over reputation, no engine state. Returns a weighted event menu
// ([[kind, weight], ...] for fnc_search_drawKind) for the town the runner picked
// (docs/plans/town_events_plan.md).
//
// Each band is [loRep, hiRep, weights]; every band whose range holds the rep merges its rows into one
// pool, so overlapping ranges stack into a single draw and disjoint ranges partition. rep is an integer
// clamped to +-20 (fnc_town_rep_adjust), so any threshold is a range -- "<= -10" is [-20, -10]. Default
// edges mirror fnc_civ_townIncome; an edge off -10 stops events agreeing with the band that garrisons
// and pays OPFOR.
params [["_rep", 0]];

private _bands = [
	[-20,  20, [["civ_car", 3], ["civ_heli", 1]]],   // ambient -- no rep gate, merges into every roll
	[-20, -10, []],   // hostile
	[ -9,   9, []],   // neutral
	[ 10,  20, []]    // friendly
];

private _menu = [];
{
	_x params ["_lo", "_hi", "_weights"];
	if (_rep >= _lo && _rep <= _hi) then { _menu append _weights };
} forEach _bands;
_menu
