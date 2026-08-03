// The side-mission definition table: one row per type, index-aligned with fnc_mission_begin's
// mission type. Included as the body of an array literal, so every consumer reads the same rows:
//
//     private _types = [
//     #include "..\..\shared\includes\mission_types.hpp"
//     ];
//
// Adding a side mission is one row here plus the thread itself. It used to be four hand-synced
// tables that agreed only because somebody checked them.
//
// Columns: [thread, cooldown-ready name, strategic-map description, map icon, debug label, launcher]
//
// The launcher is a literal block per row rather than something built from the thread column:
// BIS_fnc_strategicMapOpen runs it with no arguments and an SQF block captures no locals, so the
// only thing it can carry is its own index, written out. fnc_mission_launch turns that index back
// into a position and a name via DUWS_missionSlots.
//
// The debug label is deliberately English-only, matching fnc_debug_mission_menu.

["fnc_rescue_squad_mission",     "STR_DUWS_T_c0",  "STR_DUWS_T_kievbwmd",   "\a3\ui_f\data\gui\cfg\hints\ActionMenu_ca.paa", "Rescue squad",              { [0]  call fnc_mission_launch }],
["fnc_steal_supply_mission",     "STR_DUWS_T_c1",  "STR_DUWS_T_p7qawzl4",   "\a3\ui_f\data\gui\cfg\hints\BasicSpeed_ca.paa", "Steal supply truck",       { [1]  call fnc_mission_launch }],
["fnc_target_hvt_mission",       "STR_DUWS_T_c2",  "STR_DUWS_T_19ajhe1d",   "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Kill HVT",                 { [2]  call fnc_mission_launch }],
["fnc_destroy_tower_mission",    "STR_DUWS_T_c3",  "STR_DUWS_T_dgpqenyw",   "\a3\ui_f\data\gui\cfg\hints\IEDs_ca.paa",       "Destroy tower",            { [3]  call fnc_mission_launch }],
["fnc_rescue_pilot_mission",     "STR_DUWS_T_c4",  "STR_DUWS_T_njsu8ofz",   "\a3\ui_f\data\gui\cfg\hints\Direction_ca.paa",  "Rescue pilot",             { [4]  call fnc_mission_launch }],
["fnc_target_sniper_mission",    "STR_DUWS_T_c5",  "STR_DUWS_T_16dh939j",   "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Kill snipers",             { [5]  call fnc_mission_launch }],
["fnc_steal_builder_mission",    "STR_DUWS_T_c6",  "STR_DUWS_T_czpvn5z1",   "\a3\ui_f\data\gui\cfg\hints\BasicSpeed_ca.paa", "Steal engineering vehicle",{ [6]  call fnc_mission_launch }],
["fnc_target_armor_mission",     "STR_DUWS_T_c7",  "STR_DUWS_T_y7z1cx6j",   "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Destroy armour",           { [7]  call fnc_mission_launch }],
["fnc_sabotage_laptop_mission",  "STR_DUWS_T_c8",  "STR_DUWS_T_j97ecrsh",   "\a3\ui_f\data\gui\cfg\hints\IEDs_ca.paa",       "Sabotage laptop",          { [8]  call fnc_mission_launch }],
["fnc_destroy_cache_mission",    "STR_DUWS_T_c9",  "STR_DUWS_T_geryeddp",   "\a3\ui_f\data\gui\cfg\hints\IEDs_ca.paa",       "Destroy cache",            { [9]  call fnc_mission_launch }],
["fnc_destroy_radar_mission",    "STR_DUWS_T_c10", "STR_DUWS_T_n4uc7t2x",   "\a3\ui_f\data\gui\cfg\hints\IEDs_ca.paa",       "Destroy radar",            { [10] call fnc_mission_launch }],
["fnc_clearthearea_cqb_mission", "STR_DUWS_T_c11", "STR_DUWS_T_cqbdesc", "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Clear the area (CQB)", { [11] call fnc_mission_launch }],
["fnc_holdposition_mission",     "STR_DUWS_T_c12", "STR_DUWS_T_holdposdesc", "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Hold position",        { [12] call fnc_mission_launch }],
["fnc_domination_mission",       "STR_DUWS_T_c13", "STR_DUWS_T_domination", "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Domination",               { [13] call fnc_mission_launch }],
["fnc_protect_civ_mission",      "STR_DUWS_T_c14", "STR_DUWS_T_protectciv", "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Protect civilian",         { [14] call fnc_mission_launch }],
["fnc_transport_IDAP_mission",   "STR_DUWS_T_c15", "STR_DUWS_T_transIDAP",  "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Transport IDAP",           { [15] call fnc_mission_launch }],
["fnc_intel_gathering_mission",  "STR_DUWS_T_c16", "STR_DUWS_T_INTEL_GATHERING_DESC", "\a3\ui_f\data\gui\cfg\hints\ActionMenu_ca.paa", "Intel gathering", { [16] call fnc_mission_launch }]
