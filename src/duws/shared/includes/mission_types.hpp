// The side-mission definition table: one row per type, index-aligned with fnc_mission_begin's
// mission type. Included as the body of an array literal, so every consumer reads the same rows:
//
//     private _types = [
//     #include "..\..\shared\includes\mission_types.hpp"
//     ];
//
// Adding a side mission is one row here plus the thread itself -- one table, not four hand-synced
// ones that agree only because somebody checked them.
//
// Columns: [thread, cooldown-ready name, strategic-map description, map icon, debug label, launcher,
//           CP, AP, REP, deadline, category, objective, note, spawnRule]
//
// spawnRule column: [needDestZone, minCorridor, routeAvoidBlufor, hardEligible, weight, surveyKind]
//
// CP/AP/REP are the mission's base payout, the single source for both the reward the thread pays
// (via fnc_mission_begin -> DUWS_curReward) and the figures the strategic map prints -- edit the
// number here and both move together. REP is display-only: the two missions that grant it run their
// own town-rep call, this column only feeds the briefing line.
//
// deadline is [minHours, maxHours] of in-game time to finish before the mission auto-fails. Fractions
// are fine (0.6667 = 40 min). Equal bounds are a fixed clock ("Time: ~3h00"); a range rolls a random
// 5-minute step within it at start ("Time: ~2h30-3h00"). fnc_mission_begin rolls it into
// DUWS_curDeadlineAt; fnc_stratmap prints the band as HhMM.
//
// category is "command" (issued by HQ, the default) or "civilian" (issued by the population). An
// explicit tag, not derived from REP: today the civilian set is exactly the REP-granting missions
// (protect_civ, transport_IDAP), but a future civilian mission need not pay REP, nor a command one be
// barred from it. No consumer branches on it yet -- it exists to let one differentiate the two sets.
//
// objective is the mission's archetype -- what the player does to win: elimination, assault, sabotage,
// requisition, rescue, defend, escort, recon. Orthogonal to category (who issues it). Read from the win
// condition, not the name: "Destroy armour" succeeds on
// killing the tank commander, so it is elimination; "Destroy Signal Tower" drops a fixed installation like the
// radar and cache missions, so sabotage. Title-cased, it is the "Mission Type" line of the briefing
// stats block (fnc_missionTaskCreate and fnc_stratmap), which is why the token is the display word.
//
// note is an optional stringtable key for a caveat shown as its own "Note:" line in the briefing, after
// the deadline and before the stats block. Empty for a type without one. It lives here rather than baked
// into the description string so the description stays the plain objective and the note renders in its
// own slot on both the journal task and the map picker.
//
// spawnRule is the type's placement contract, read by fnc_mission_findSite: [needDestZone, minCorridor,
// routeAvoidBlufor]. needDestZone true makes siting pick an OPFOR-held zone as the mission's destination
// (the convoy haven) and hand it to the thread through the launch payload, so the thread runs to a zone
// the offer already vetted instead of recomputing its own. minCorridor is the metres that zone must sit
// from the sited anchor, so the drive is a real journey rather than a hop to an adjacent zone.
// routeAvoidBlufor true rejects any anchor whose straight line to that zone passes within reach of
// BLUFOR-held ground, keeping the convoy corridor off friendly positions. The three destination fields
// default to [false, 0, false] -- every type but the deny-armor convoy. The HVT convoy leaves them default
// too: instead of siting picking its destination, its own site-finder (fnc_target_hvt_site) anchors on the
// nearest discovered OPFOR-held zone and ejects the spawn 3-10 km out from it, its thread picking the haven
// from there (fnc_hvt_dest_pick). That way it still offers on tight, cluster-zoned maps, where two OPFOR
// zones 3 km apart -- what needDestZone would demand -- rarely exist but open ground 3-10 km out does.
//
// hardEligible and weight feed the strategic-map draw (fnc_stratmap), not siting. hardEligible true lets
// the type fill one of the two deep, difficulty-boosted "hard" offer slots; false bars a type from them.
// Every type is hardEligible: the hard survey scores a town or countryside feature 0 where no enemy zone
// or hardpoint is near (fnc_mission_findSite _fnHardScore), so a type with no enemy-dense fit just returns
// no hard site -- that slot draws another type and the type still seats easy -- rather than placing
// somewhere absurd. So the flag needs no bar; leave it true unless a future type must never pay the deep
// bonus. weight is the relative odds of being drawn; 1 is neutral, lower makes a type rarer. Types are
// drawn without replacement into the offer set, so weight biases order and presence, not duplication.
//
// surveyKind is the placement survey's candidate source (fnc_mission_findSite): "zone" scans the countryside
// off OPFOR zones, "town" scans populated towns, "map" samples the whole HQ-reach area, "hardpoint"
// enumerates the live target hardpoints directly, "capturezone" enumerates the OPFOR-held zones directly.
// Set "town" for a type that belongs in a built-up area
// (informant, CQB, the civilian pair). Set "map" for a type not tied to a zone, placed straight on the
// sampled dot: the hard/easy dial (not a zone anchor) pulls it toward meaningful ground (hard scores 0 with
// no enemy near, so it still clusters on enemy density; easy favours the frontline). Set "hardpoint" for a
// type that destroys an existing emplacement (tower, hardpoint): the survey lists those emplacements one per
// candidate via the type's finder in ["ALL"] mode -- so a "hardpoint" type MUST define a finder that answers
// ["ALL"] -- giving a sparse, scattered target set even coverage where a random-dot survey would collapse
// onto whichever target sits nearest a zone cluster. "capturezone" shares that enumerate path (its finder
// must answer ["ALL"] too) but sources revealed OPFOR-held zones, and its objective sits ON the zone, so it
// is the one surveyKind exempt from findSite's zone-interior claimed gate. The deny-armor convoy uses "map" too: its spawn is free
// but needDest still ties the haven it drives to a zone. The HVT convoy stays "zone" -- its finder anchors
// the eject on a discovered held zone, not a dot. The front-vs-deep bias is separate -- it is the offer's
// hard/easy dial, not the survey source.
//
// The launcher is a literal block per row rather than something built from the thread column:
// BIS_fnc_strategicMapOpen runs it with no arguments and an SQF block captures no locals, so the
// only thing it can carry is its own index, written out. fnc_mission_launch turns that index back
// into a position and a name via DUWS_missionSlots.
//
// The debug label is deliberately English-only, matching fnc_debug_mission_menu.

["fnc_rescue_squad_mission",     "STR_DUWS_T_c0",  "STR_DUWS_T_kievbwmd",   "\a3\ui_f\data\gui\cfg\hints\ActionMenu_ca.paa", "Rescue Assault Team",              { [0]  call fnc_mission_launch }, 25, 15, 0, [0.6667,1.5], "command", "rescue", "", [false, 0, false, true, 1, "map"]],
["fnc_steal_supply_mission",     "STR_DUWS_T_c1",  "STR_DUWS_T_p7qawzl4",   "\a3\ui_f\data\gui\cfg\hints\BasicSpeed_ca.paa", "Steal Supply Truck",       { [1]  call fnc_mission_launch }, 20, 20, 0, [0.6667,1.5], "command", "requisition", "", [false, 0, false, true, 1, "map"]],
["fnc_target_hvt_mission",       "STR_DUWS_T_c2",  "STR_DUWS_T_19ajhe1d",   "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Eliminate High-Value Target",          { [2]  call fnc_mission_launch }, 35, 30, 0, [1.5,2], "command", "elimination", "", [false, 0, false, true, 1, "zone"]],
["fnc_destroy_tower_mission",    "STR_DUWS_T_c3",  "STR_DUWS_T_dgpqenyw",   "\a3\ui_f\data\gui\cfg\hints\IEDs_ca.paa",       "Destroy Signal Tower",            { [3]  call fnc_mission_launch }, 30, 20, 0, [1.5,2], "command", "sabotage", "", [false, 0, false, true, 1, "hardpoint"]],
["fnc_rescue_pilot_mission",     "STR_DUWS_T_c4",  "STR_DUWS_T_njsu8ofz",   "\a3\ui_f\data\gui\cfg\hints\Direction_ca.paa",  "Rescue Pilot",             { [4]  call fnc_mission_launch }, 25, 25, 0, [0.3333,1], "command", "rescue", "STR_DUWS_T_rescuepilot_note", [false, 0, false, true, 1, "map"]],
["fnc_target_sniper_mission",    "STR_DUWS_T_c5",  "STR_DUWS_T_16dh939j",   "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Hunt Sniper Team",             { [5]  call fnc_mission_launch }, 15, 15, 0, [0.6667,1.5], "command", "elimination", "", [false, 0, false, true, 1, "map"]],
["fnc_steal_builder_mission",    "STR_DUWS_T_c6",  "STR_DUWS_T_czpvn5z1",   "\a3\ui_f\data\gui\cfg\hints\BasicSpeed_ca.paa", "Steal Builder Vehicle",{ [6]  call fnc_mission_launch }, 20, 30, 0, [0.3333,1], "command", "requisition", "", [false, 0, false, true, 1, "map"]],
["fnc_target_armor_mission",     "STR_DUWS_T_c7",  "STR_DUWS_T_y7z1cx6j",   "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Destroy Vehicle Patrol",  { [7]  call fnc_mission_launch }, 15, 20, 0, [0.6667,1.5], "command", "elimination", "STR_DUWS_T_armornote", [false, 0, false, true, 1, "map"]],
["fnc_sabotage_laptop_mission",  "STR_DUWS_T_c8",  "STR_DUWS_T_j97ecrsh",   "\a3\ui_f\data\gui\cfg\hints\IEDs_ca.paa",       "Sabotage Laptop",         { [8]  call fnc_mission_launch }, 30, 20, 0, [0.6667,1.5], "command", "sabotage", "", [false, 0, false, true, 1, "map"]],
["fnc_destroy_cache_mission",    "STR_DUWS_T_c9",  "STR_DUWS_T_geryeddp",   "\a3\ui_f\data\gui\cfg\hints\IEDs_ca.paa",       "Destroy Ammo Cache",            { [9]  call fnc_mission_launch }, 25, 15, 0, [0.6667,1.5], "command", "sabotage", "", [false, 0, false, true, 1, "map"]],
["fnc_destroy_radar_mission",    "STR_DUWS_T_c10", "STR_DUWS_T_n4uc7t2x",   "\a3\ui_f\data\gui\cfg\hints\IEDs_ca.paa",       "Destroy Radar",            { [10] call fnc_mission_launch }, 15, 25, 0, [0.6667,1.5], "command", "sabotage", "", [false, 0, false, true, 1, "map"]],
["fnc_deny_armor_mission",       "STR_DUWS_T_c11", "STR_DUWS_T_destroyarmour_desc",   "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Deny Enemy Armor",         { [11] call fnc_mission_launch }, 20, 20, 0, [1.5,2], "command", "elimination", "STR_DUWS_T_destroyarmour_note", [true, 1500, true, true, 1, "map"]],
["fnc_recon_observe_mission",    "STR_DUWS_T_c12", "STR_DUWS_T_RECON_OBSERVE_DESC",   "\a3\ui_f\data\gui\cfg\hints\Direction_ca.paa",  "Recon Enemy Position",       { [12] call fnc_mission_launch }, 10, 5,  0, [0.3333,1], "command", "recon", "", [false, 0, false, true, 1, "zone"]],
["fnc_protect_civ_mission",      "STR_DUWS_T_c13", "STR_DUWS_T_protectciv", "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Protect Informant",         { [13] call fnc_mission_launch }, 40, 30, 3, [1.5,2], "civilian", "defend", "STR_DUWS_T_protectciv_note", [false, 0, false, true, 1, "map"]],
["fnc_transport_IDAP_mission",   "STR_DUWS_T_c14", "STR_DUWS_T_transIDAP",  "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Recover Humanitarian Supply Truck",           { [14] call fnc_mission_launch }, 25, 10, 3, [0.3333,1], "civilian", "escort", "STR_DUWS_T_townrep_note", [false, 0, false, true, 1, "map"]],
["fnc_informant_mission",        "STR_DUWS_T_c15", "STR_DUWS_T_INTEL_INFORMANT_DESC", "\a3\ui_f\data\gui\cfg\hints\ActionMenu_ca.paa", "Informant Manhunt", { [15] call fnc_mission_launch }, 10, 25, 0, [1.5,2], "command", "elimination", "STR_DUWS_T_INTEL_INFORMANT_NOTE", [false, 0, false, true, 1, "town"]],
["fnc_destroy_hardpoint_mission", "STR_DUWS_T_c16", "STR_DUWS_T_DESTROY_HARDPOINT_DESC", "\a3\ui_f\data\gui\cfg\hints\IEDs_ca.paa",       "Destroy Hardpoint",            { [16] call fnc_mission_launch }, 10, 10, 0, [0.3333,1], "command", "sabotage", "", [false, 0, false, true, 1, "hardpoint"]],
["fnc_target_recon_mission",      "STR_DUWS_T_c17", "STR_DUWS_T_RECON_PATROL_DESC",       "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Eliminate Recon Patrol",       { [17] call fnc_mission_launch }, 10, 10, 0, [0.3333,1], "command", "elimination", "", [false, 0, false, true, 1, "map"]],
["fnc_destroy_patrol_camp_mission", "STR_DUWS_T_c18", "STR_DUWS_T_DESTROY_PATROL_CAMP_DESC", "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Destroy Patrol Camp",       { [18] call fnc_mission_launch }, 20, 15, 0, [0.6667,1.5], "command", "elimination", "", [false, 0, false, true, 1, "map"]],
["fnc_destroy_air_mission",      "STR_DUWS_T_c19", "STR_DUWS_T_DESTROY_AIR_DESC",     "\a3\ui_f\data\gui\cfg\hints\Annoucning_ca.paa", "Destroy Air Asset",         { [19] call fnc_mission_launch }, 25, 25, 0, [0.6667,1.5], "command", "elimination", "", [false, 0, false, true, 1, "map"]],
["fnc_escort_informant_mission", "STR_DUWS_T_c20", "STR_DUWS_T_ESCORT_INFORMANT_DESC", "\a3\ui_f\data\gui\cfg\hints\Direction_ca.paa",  "Escort Informant",          { [20] call fnc_mission_launch }, 5, 15, 1, [0.6667,1.5], "civilian", "escort", "STR_DUWS_T_townrep_note", [false, 0, false, true, 1, "town"]],
["fnc_deliver_supplies_mission", "STR_DUWS_T_c21", "STR_DUWS_T_DELIVER_SUPPLIES_DESC", "\a3\ui_f\data\gui\cfg\hints\BasicSpeed_ca.paa", "Deliver Supplies",          { [21] call fnc_mission_launch }, 15, 5, 3, [0.6667,1.5], "civilian", "escort", "STR_DUWS_T_townrep_note", [false, 0, false, true, 1, "town"]],
["fnc_capture_zone_mission",     "STR_DUWS_T_c22", "STR_DUWS_T_CAPTURE_ZONE_DESC", "\a3\ui_f\data\gui\cfg\hints\ActionMenu_ca.paa", "Capture Zone",             { [22] call fnc_mission_launch }, 20, 20, 0, [1.5,2], "command", "assault", "", [false, 0, false, true, 1, "capturezone"]],
// CP/AP kept modest: the cache is turned in at HQ analysis for its own CP + reveals, so a rich base payout on top would double-dip.
["fnc_raid_safehouse_mission",   "STR_DUWS_T_RAID_SAFEHOUSE_READY", "STR_DUWS_T_RAID_SAFEHOUSE_DESC", "\a3\ui_f\data\gui\cfg\hints\ActionMenu_ca.paa", "Raid Informant Safehouse", { [23] call fnc_mission_launch }, 15, 15, 0, [1.5,2], "command", "assault", "STR_DUWS_T_RAID_SAFEHOUSE_NOTE", [false, 0, false, true, 1, "town"]]
