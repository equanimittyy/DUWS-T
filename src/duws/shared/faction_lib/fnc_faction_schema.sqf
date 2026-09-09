// Locality: any -- a pure table, reads no engine or mission state.
//
// The one place the DUWS role schema is written down: every key a side must fill, in fill order,
// with the section, class kind, required flag and vanilla default no earlier list carried. Single-
// sourced so its consumers (fnc_custom_faction_parse's required keys, the two AutoDetect pool-publish
// lists, the confirmation screen) cannot disagree with each other.
//
// Returns [key, group, kind, required, vanillaDefault]:
//   key      - full global name, e.g. "blufor_AR_SOLDIER_X"
//   group    - INFANTRY | VEHICLES | STATIC | OPERATORS | SPECIAL; the confirmation screen's section
//   kind     - man | vehicle | static; which CfgVehicles branch the key editor may offer
//   required - must a pasted custom faction define it. False marks a key added after the shipped
//              faction files: an existing paste has no value for it and nothing in factions/MODERN/
//              defines it either, so the vanilla default below covers the empty key. Clearing still
//              walks every key regardless, or a re-paste would leave the previous faction's value.
//   vanillaDefault - the base-game NATO/CSAT class the role degrades to. One source, two readers:
//              fnc_faction_resolve appends it as the AutoDetect ladder's last rung when a call omits
//              an explicit fallback, and fnc_faction_vanilla_fill drops it into any key a hand-written
//              or pasted faction left empty or pointing at an absent class. Both mark the result tier 2
//              (the confirmation screen's red), so a stand-in is never passed off as the faction's own.
//              "" for a key with no honest vanilla stand-in: the fill leaves it empty rather than lie.
//
// Both sides spell a role the same way in the same position, so a composition names a role bare and
// the side supplies the man (DUWS_teamRosters). The four shared sections hold matching keys in
// matching order, which lets the confirmation screen put a role on one line across two columns.
// SPECIAL is what genuinely belongs to one side (BLUFOR's boat taxi and rescue pilot, OPFOR's supply
// trucks and mission-thread roles); filing those shared would gap the other column at every row below.
//
// The request-menu catalogues (blufor_RQST_UNITS / blufor_RQST_VEHICLES) are absent on purpose:
// variable-length ordered lists with no OPFOR counterpart, fnc_faction_rqst_list already has
// fallbacks, and neither validation nor the one-row-per-key screen can express a list.

params [["_side", "blufor"]];

if (_side == "opfor") exitWith {[
    ["opfor_SOLDIER_X",            "INFANTRY",    "man",        true,    "O_Soldier_F"],
    ["opfor_AA_SOLDIER_X",         "INFANTRY",    "man",        true,    "O_Soldier_AA_F"],
    ["opfor_AR_SOLDIER_X",         "INFANTRY",    "man",        true,    "O_Soldier_AR_F"],
    ["opfor_AT_SOLDIER_X",         "INFANTRY",    "man",        true,    "O_Soldier_AT_F"],
    ["opfor_GL_SOLDIER_X",         "INFANTRY",    "man",        true,    "O_Soldier_GL_F"],
    ["opfor_LAT_SOLDIER_X",        "INFANTRY",    "man",        true,    "O_Soldier_LAT_F"],
    ["opfor_SL_SOLDIER_X",         "INFANTRY",    "man",        true,    "O_Soldier_SL_F"],
    ["opfor_TL_SOLDIER_X",         "INFANTRY",    "man",        true,    "O_Soldier_TL_F"],
    ["opfor_MARK_SOLDIER_X",       "INFANTRY",    "man",        true,    "O_soldier_M_F"],
    ["opfor_SNIPER_SOLDIER_X",     "INFANTRY",    "man",        true,    "O_sniper_F"],
    // required=false: only the default faction defines a regular medic; the rest backfill from SPECOPS_MEDIC_X.
    ["opfor_MEDIC_X",              "INFANTRY",    "man",        false,   "O_medic_F"],
    ["opfor_OFFICER_X",            "INFANTRY",    "man",        true,    "O_officer_F"],

    ["opfor_ARMED_CAR1_X",         "VEHICLES",    "vehicle",    true,    "O_LSV_02_armed_F"],
    ["opfor_APC1_X",               "VEHICLES",    "vehicle",    true,    "O_APC_Tracked_02_cannon_F"],
    ["opfor_APC2_X",               "VEHICLES",    "vehicle",    true,    "O_APC_Tracked_02_cannon_F"],
    ["opfor_MBT_TANK1_X",          "VEHICLES",    "vehicle",    true,    "O_MBT_02_cannon_F"],
    ["opfor_TRANS_HELI_X",         "VEHICLES",    "vehicle",    true,    "O_Heli_Light_02_unarmed_F"],
    ["opfor_ATTACK_HELI_X",        "VEHICLES",    "vehicle",    true,    "O_Heli_Attack_02_dynamicLoadout_F"],
    ["opfor_MISC_AIR_X",           "VEHICLES",    "vehicle",    true,    "O_Plane_CAS_02_dynamicLoadout_F"],

    ["opfor_TURRET_AA",            "STATIC",      "static",     false,   "O_static_AA_F"],
    ["opfor_TURRET_AT",            "STATIC",      "static",     false,   "O_static_AT_F"],
    ["opfor_TURRET_HMG",           "STATIC",      "static",     true,    "O_HMG_01_high_F"],
    ["opfor_TURRET_GMG",           "STATIC",      "static",     false,   "O_GMG_01_high_F"],
    ["opfor_TURRET_MORTAR",        "STATIC",      "static",     false,   "O_Mortar_01_F"],

    ["opfor_SPECOPS_X",            "OPERATORS",   "man",        true,    "O_recon_F"],
    ["opfor_SPECOPS_GL_X",         "OPERATORS",   "man",        true,    "O_Soldier_GL_F"],
    ["opfor_SPECOPS_LAT_X",        "OPERATORS",   "man",        true,    "O_recon_LAT_F"],
    ["opfor_SPECOPS_HAT_X",        "OPERATORS",   "man",        true,    "O_Soldier_AT_F"],
    ["opfor_SPECOPS_AA_X",         "OPERATORS",   "man",        true,    "O_Soldier_AA_F"],
    ["opfor_SPECOPS_MG_X",         "OPERATORS",   "man",        true,    "O_Soldier_AR_F"],
    ["opfor_SPECOPS_MEDIC_X",      "OPERATORS",   "man",        true,    "O_recon_medic_F"],
    ["opfor_SPECOPS_MARK_X",       "OPERATORS",   "man",        true,    "O_recon_M_F"],
    ["opfor_SPECOPS_SNIPER_X",     "OPERATORS",   "man",        true,    "O_sniper_F"],
    ["opfor_SPECOPS_EXP_X",        "OPERATORS",   "man",        true,    "O_recon_exp_F"],
    ["opfor_SPECOPS_ENG_X",        "OPERATORS",   "man",        true,    "O_engineer_F"],

    ["opfor_ENG_SOLDIER_X",        "SPECIAL",     "man",        true,    "O_engineer_F"],
    ["opfor_CREW_X",               "SPECIAL",     "man",        true,    "O_crew_F"],
    ["opfor_OPERATOR_X",           "SPECIAL",     "man",        true,    "O_recon_F"],
    ["opfor_AA_APC_X",             "SPECIAL",     "vehicle",    true,    "O_APC_Tracked_02_AA_F"],
    // SPECIAL, not VEHICLES: shared sections stay aligned across sides and only OPFOR fields a gun.
    // The player's own artillery is a support call that spawns shells, not a raised piece.
    ["opfor_ARTY_X",               "SPECIAL",     "vehicle",    false,   "O_MBT_02_arty_F"],
    ["opfor_TRANS_TRUCK_X",        "SPECIAL",     "vehicle",    true,    "O_Truck_03_transport_F"],
    ["opfor_COVERED_TRUCK_X",      "SPECIAL",     "vehicle",    true,    "O_Truck_03_covered_F"],
    ["opfor_AMMO_TRUCK_X",         "SPECIAL",     "vehicle",    true,    "O_Truck_03_ammo_F"],
    ["opfor_REPAIR_TRUCK_X",       "SPECIAL",     "vehicle",    true,    "O_Truck_03_repair_F"],
    // Empty default, not the CSAT boat: a faction with no detected boat fields none, so OPCOM's sea-ferry
    // falls to a rotary rather than a stand-in hull forced onto a land force (docs/plans/opcom/opcom_plan.md).
    ["opfor_BOAT_ARMED_X",         "SPECIAL",     "vehicle",    false,   ""]
]};

[
    ["blufor_SOLDIER_X",           "INFANTRY",    "man",        true,    "B_Soldier_F"],
    // The three no BLUFOR faction file has ever defined. fnc_faction_backfill borrows each from a
    // role the same side does field, so a shared team row can name them on either side.
    ["blufor_AA_SOLDIER_X",        "INFANTRY",    "man",        false,   "B_soldier_AA_F"],
    ["blufor_AR_SOLDIER_X",        "INFANTRY",    "man",        true,    "B_Soldier_AR_F"],
    ["blufor_AT_SOLDIER_X",        "INFANTRY",    "man",        false,   "B_soldier_AT_F"],
    ["blufor_GL_SOLDIER_X",        "INFANTRY",    "man",        true,    "B_Soldier_GL_F"],
    ["blufor_LAT_SOLDIER_X",       "INFANTRY",    "man",        true,    "B_Soldier_LAT_F"],
    ["blufor_SL_SOLDIER_X",        "INFANTRY",    "man",        true,    "B_Soldier_SL_F"],
    ["blufor_TL_SOLDIER_X",        "INFANTRY",    "man",        true,    "B_Soldier_TL_F"],
    ["blufor_MARK_SOLDIER_X",      "INFANTRY",    "man",        true,    "B_soldier_M_F"],
    ["blufor_SNIPER_SOLDIER_X",    "INFANTRY",    "man",        false,   "B_sniper_F"],
    // required=false: only the default faction defines a regular medic; the rest backfill from SPECOPS_MEDIC_X.
    ["blufor_MEDIC_X",             "INFANTRY",    "man",        false,   "B_medic_F"],
    ["blufor_OFFICER_X",           "INFANTRY",    "man",        true,    "B_OFFICER_F"],

    ["blufor_ARMED_CAR1_X",        "VEHICLES",    "vehicle",    true,    "B_MRAP_01_hmg_F"],
    ["blufor_APC1_X",              "VEHICLES",    "vehicle",    true,    "B_APC_Tracked_01_rcws_F"],
    ["blufor_APC2_X",              "VEHICLES",    "vehicle",    true,    "B_APC_Wheeled_01_cannon_F"],
    ["blufor_MBT_TANK1_X",         "VEHICLES",    "vehicle",    true,    "B_MBT_01_cannon_F"],
    ["blufor_TRANS_HELI_X",        "VEHICLES",    "vehicle",    true,    "B_Heli_Transport_03_unarmed_F"],
    ["blufor_ATTACK_HELI_X",       "VEHICLES",    "vehicle",    true,    "B_Heli_Attack_01_F"],
    ["blufor_MISC_AIR_X",          "VEHICLES",    "vehicle",    true,    "B_Plane_CAS_01_F"],

    ["blufor_TURRET_AA",           "STATIC",      "static",     true,    "B_static_AA_F"],
    ["blufor_TURRET_AT",           "STATIC",      "static",     true,    "B_static_AT_F"],
    ["blufor_TURRET_HMG",          "STATIC",      "static",     true,    "B_HMG_01_high_F"],
    ["blufor_TURRET_GMG",          "STATIC",      "static",     true,    "B_GMG_01_high_F"],
    ["blufor_TURRET_MORTAR",       "STATIC",      "static",     false,   "B_Mortar_01_F"],

    ["blufor_SPECOPS_X",           "OPERATORS",   "man",        true,    "B_recon_F"],
    ["blufor_SPECOPS_GL_X",        "OPERATORS",   "man",        true,    "B_Soldier_GL_F"],
    ["blufor_SPECOPS_LAT_X",       "OPERATORS",   "man",        true,    "B_recon_LAT_F"],
    ["blufor_SPECOPS_HAT_X",       "OPERATORS",   "man",        true,    "B_soldier_AT_F"],
    ["blufor_SPECOPS_AA_X",        "OPERATORS",   "man",        true,    "B_soldier_AA_F"],
    ["blufor_SPECOPS_MG_X",        "OPERATORS",   "man",        true,    "B_Soldier_AR_F"],
    ["blufor_SPECOPS_MEDIC_X",     "OPERATORS",   "man",        true,    "B_recon_medic_F"],
    ["blufor_SPECOPS_MARK_X",      "OPERATORS",   "man",        true,    "B_recon_M_F"],
    ["blufor_SPECOPS_SNIPER_X",    "OPERATORS",   "man",        true,    "B_sniper_F"],
    ["blufor_SPECOPS_EXP_X",       "OPERATORS",   "man",        true,    "B_recon_exp_F"],
    ["blufor_SPECOPS_ENG_X",       "OPERATORS",   "man",        true,    "B_engineer_F"],

    ["blufor_HELI_PILOT_X",        "SPECIAL",     "man",        true,    "B_Helipilot_F"],
    ["blufor_BOAT_ARMED_X",        "SPECIAL",     "vehicle",    true,    "B_Boat_Armed_01_minigun_F"],
    // Crews the boat above, which is why it sits with the vehicles rather than the infantry.
    ["blufor_BOAT_CREW_X",         "SPECIAL",     "man",        true,    "C_Man_UtilityWorker_01_F"],
    // The unarmed player taxi boat. Seats its own pilot when spawned, so unlike the armed boat above
    // it needs no crew key.
    ["blufor_BOAT_TRANS_X",        "SPECIAL",     "vehicle",    true,    "B_Boat_Transport_01_F"],
    // Wants a gun on it: fnc_helotaxi flies into contested ground, where the plain transport the
    // shared TRANS_HELI key holds is what the random patrols want.
    ["blufor_HELI_TRANS_ARM_X",    "SPECIAL",     "vehicle",    true,    "B_Heli_Transport_01_F"]
]
