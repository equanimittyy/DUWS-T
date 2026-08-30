// The town-event tables, one row per reputation band: [label, loRep, hiRep, weights]. Included as the
// body of an array literal, so the runner's lookup and the debug spawner read the same rows:
//
//     private _bands = [
//     #include "..\..\shared\includes\town_event_tables.hpp"
//     ];
//
// Every band whose [loRep, hiRep] range holds a town's reputation merges its weights into one pool for a
// single draw (fnc_town_event_table), so ranges can overlap to stack menus or partition the spectrum.
// weights is [[kind, weight], ...] for fnc_search_drawKind; each kind needs a case in fnc_town_event_fire.
// rep is an integer clamped to +-20 (fnc_town_rep_adjust), so a threshold is a range -- "<= -10" is [-20, -10].
// The default edges mirror fnc_civ_townIncome, so a town's events agree with the band that garrisons and pays OPFOR.
//
// label heads the band in the debug spawner (fnc_debug_town_event_menu); English-only, a dev surface, like
// the other debug labels.

["Ambient",  -20,  20, [["civ_car", 3], ["civ_heli", 1]]],
["Hostile",  -20, -10, []],
["Neutral",   -9,   9, []],
["Friendly",  10,  20, []]
