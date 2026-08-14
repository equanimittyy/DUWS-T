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
// Columns: [thread, cooldown-ready name, strategic-map description, map icon, debug label, launcher,
//           CP, AP, REP, deadline, category, objective]
//
// CP/AP/REP are the mission's base payout, the single source for both the reward the thread pays
// (via fnc_mission_begin -> DUWS_curReward) and the figures the strategic map prints -- edit the
// number here and both move together. REP is display-only: the two missions that grant it run their
// own town-rep call, this column only feeds the briefing line.
//
// deadline is [minHours, maxHours] of in-game time to finish before the mission auto-fails. Equal
// bounds are a fixed clock ("Time: 3hrs"); a range rolls a random 10-minute step within it at start
// ("Time: 2-3hrs"). fnc_mission_begin rolls it into DUWS_curDeadlineAt; fnc_stratmap prints the band.
//
// category is "command" (issued by HQ, the default) or "civilian" (issued by the population). An
// explicit tag, not derived from REP: today the civilian set is exactly the REP-granting missions
// (protect_civ, transport_IDAP), but a future civilian mission need not pay REP, nor a command one be
// barred from it. No consumer branches on it yet -- it exists to let one differentiate the two sets.
//
// objective is the mission's archetype -- what the player does to win: elimination, assault, sabotage,
// requisition, rescue, defend, escort, recon. Orthogonal to category (who issues it). Read from the win
// condition, not the name: "Destroy armour" succeeds on
// killing the tank commander, so it is elimination; "Destroy tower" drops a fixed installation like the
// radar and cache missions, so sabotage. No consumer branches on it yet.
//
// The launcher is a literal block per row rather than something built from the thread column:
// BIS_fnc_strategicMapOpen runs it with no arguments and an SQF block captures no locals, so the
// only thing it can carry is its own index, written out. fnc_mission_launch turns that index back
// into a position and a name via DUWS_missionSlots.
//
// The debug label is deliberately English-only, matching fnc_debug_mission_menu.

["fnc_rescue_squad_mission",     "STR_DUWS_T_c0",  "STR_DUWS_T_kievbwmd",   "\a3\ui_f\data\gui\cfg\hints\ActionMenu_ca.paa", "Rescue squad",              { [0]  call fnc_mission_launch }, 45, 24, 0, [3,3], "command", "rescue"],
["fnc_steal_supply_mission",     "STR_DUWS_T_c1",  "STR_DUWS_T_p7qawzl4",   "\a3\ui_f\data\gui\cfg\hints\BasicSpeed_ca.paa", "Steal supply truck",       { [1]  call fnc_mission_launch }, 35, 24, 0, [3,3], "command", "requisition"],
["fnc_target_hvt_mission",       "STR_DUWS_T_c2",  "STR_DUWS_T_19ajhe1d",   "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Kill HVT",                 { [2]  call fnc_mission_launch }, 35, 36, 0, [3,3], "command", "elimination"],
["fnc_destroy_tower_mission",    "STR_DUWS_T_c3",  "STR_DUWS_T_dgpqenyw",   "\a3\ui_f\data\gui\cfg\hints\IEDs_ca.paa",       "Destroy tower",            { [3]  call fnc_mission_launch }, 20, 30, 0, [3,3], "command", "sabotage"],
["fnc_rescue_pilot_mission",     "STR_DUWS_T_c4",  "STR_DUWS_T_njsu8ofz",   "\a3\ui_f\data\gui\cfg\hints\Direction_ca.paa",  "Rescue pilot",             { [4]  call fnc_mission_launch }, 25, 40, 0, [3,3], "command", "rescue"],
["fnc_target_sniper_mission",    "STR_DUWS_T_c5",  "STR_DUWS_T_16dh939j",   "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Kill snipers",             { [5]  call fnc_mission_launch }, 30, 30, 0, [3,3], "command", "elimination"],
["fnc_steal_builder_mission",    "STR_DUWS_T_c6",  "STR_DUWS_T_czpvn5z1",   "\a3\ui_f\data\gui\cfg\hints\BasicSpeed_ca.paa", "Steal engineering vehicle",{ [6]  call fnc_mission_launch }, 15, 20, 0, [3,3], "command", "requisition"],
["fnc_target_armor_mission",     "STR_DUWS_T_c7",  "STR_DUWS_T_y7z1cx6j",   "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Destroy armour",           { [7]  call fnc_mission_launch }, 15, 20, 0, [3,3], "command", "elimination"],
["fnc_sabotage_laptop_mission",  "STR_DUWS_T_c8",  "STR_DUWS_T_j97ecrsh",   "\a3\ui_f\data\gui\cfg\hints\IEDs_ca.paa",       "Sabotage laptop",          { [8]  call fnc_mission_launch }, 10, 36, 0, [3,3], "command", "sabotage"],
["fnc_destroy_cache_mission",    "STR_DUWS_T_c9",  "STR_DUWS_T_geryeddp",   "\a3\ui_f\data\gui\cfg\hints\IEDs_ca.paa",       "Destroy cache",            { [9]  call fnc_mission_launch }, 30, 20, 0, [3,3], "command", "sabotage"],
["fnc_destroy_radar_mission",    "STR_DUWS_T_c10", "STR_DUWS_T_n4uc7t2x",   "\a3\ui_f\data\gui\cfg\hints\IEDs_ca.paa",       "Destroy radar",            { [10] call fnc_mission_launch }, 25, 24, 0, [3,3], "command", "sabotage"],
["fnc_clearthearea_cqb_mission", "STR_DUWS_T_c11", "STR_DUWS_T_cqbdesc", "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Clear the area (CQB)", { [11] call fnc_mission_launch }, 15, 20, 0, [3,3], "command", "assault"],
["fnc_holdposition_mission",     "STR_DUWS_T_c12", "STR_DUWS_T_holdposdesc", "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Hold position",        { [12] call fnc_mission_launch }, 30, 36, 0, [3,3], "command", "defend"],
["fnc_domination_mission",       "STR_DUWS_T_c13", "STR_DUWS_T_domination", "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Domination",               { [13] call fnc_mission_launch }, 10, 30, 0, [3,3], "command", "assault"],
["fnc_protect_civ_mission",      "STR_DUWS_T_c14", "STR_DUWS_T_protectciv", "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Protect civilian",         { [14] call fnc_mission_launch }, 20, 10, 5, [3,3], "civilian", "defend"],
["fnc_transport_IDAP_mission",   "STR_DUWS_T_c15", "STR_DUWS_T_transIDAP",  "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Transport IDAP",           { [15] call fnc_mission_launch }, 20, 10, 5, [3,3], "civilian", "escort"],
["fnc_informant_mission",        "STR_DUWS_T_c16", "STR_DUWS_T_INTEL_INFORMANT_DESC", "\a3\ui_f\data\gui\cfg\hints\ActionMenu_ca.paa", "Eliminate informant", { [16] call fnc_mission_launch }, 5, 10, 0, [3,3], "command", "elimination"]
