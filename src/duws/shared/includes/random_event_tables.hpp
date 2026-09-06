// The random-event tables, one row per reputation band: [label, loRep, hiRep, weights]. Included as the
// body of an array literal, so the runner's lookup and the debug spawner read the same rows:
//
//     private _bands = [
//     #include "..\..\shared\includes\random_event_tables.hpp"
//     ];
//
// Bands whose [loRep, hiRep] range holds a town's reputation merge their weights into one draw
// (fnc_random_event_table), so ranges can overlap or partition. Each kind in weights needs a case in
// fnc_random_event_fire; the edges mirror fnc_civ_townIncome so events agree with the economy bands.
//
// label heads the band in the debug spawner (fnc_debug_random_event_menu); English-only, a dev surface, like
// the other debug labels.

["Ambient",  -20,  20, [["civ_car", 3], ["civ_stranded", 2], ["civ_heli", 1], ["civ_convoy", 1]]],
["Hostile",  -20, -10, [["car_bomb", 3], ["recon_patrol", 3], ["enemy_car", 2], ["enemy_sniper", 2], ["ied", 2]]],
["Friendly",  10,  20, []]
