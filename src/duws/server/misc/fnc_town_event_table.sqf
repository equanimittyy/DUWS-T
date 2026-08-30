// Locality: any -- pure lookup over reputation, no engine state. Returns the event menu for the town
// the runner picked, as [[kind, weight], ...] for fnc_search_drawKind. Reputation is the whole input
// (docs/plans/town_events_plan.md), so the band owns the menu and the runner stays agnostic.
//
// Edges mirror the town economy (fnc_civ_townIncome), so a town's income side and its event set cannot
// disagree about which band it is in. Empty for now: an empty menu draws to "", and the runner fires
// nothing.
params [["_rep", 0]];

// Hostile: the free consequence of a town let fall -- IEDs, ambushes, sabotage, hostile-civilian
// conversion, suicide bombers (invariants in docs/plans/town_events_plan.md).
if (_rep <= -10) exitWith { [] };

// Friendly: what a town that trusts BLUFOR offers the player.
if (_rep >= 10) exitWith { [] };

// Neutral: no reputation to act on.
[]
