// Locality: any -- a pure table, reads no engine or mission state.
//
// The one place the DUWS role schema is written down: every key a side must fill, in fill order,
// with the section, class kind, and required flag no earlier list carried. Three consumers used to
// hold their own copy (fnc_custom_faction_parse's required keys, the two AutoDetect pool-publish
// lists); a fourth for the confirmation screen would only have let the copies disagree.
//
// Returns [key, group, kind, required]:
//   key      - full global name, e.g. "blufor_AR_SOLDIER_X"
//   group    - INFANTRY | VEHICLES | STATIC | OPERATORS | SPECIAL; the confirmation screen's section
//   kind     - man | vehicle | static; which CfgVehicles branch the key editor may offer
//   required - must a pasted custom faction define it. False marks a key added after the shipped
//              faction files: an existing paste has no value for it and nothing in factions/MODERN/
//              defines it either, so the resolver's fallback covers the empty key. Clearing still
//              walks every key regardless, or a re-paste would leave the previous faction's value.
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
    ["opfor_SOLDIER_X",            "INFANTRY",    "man",        true],
    ["opfor_AA_SOLDIER_X",         "INFANTRY",    "man",        true],
    ["opfor_AR_SOLDIER_X",         "INFANTRY",    "man",        true],
    ["opfor_AT_SOLDIER_X",         "INFANTRY",    "man",        true],
    ["opfor_GL_SOLDIER_X",         "INFANTRY",    "man",        true],
    ["opfor_LAT_SOLDIER_X",        "INFANTRY",    "man",        true],
    ["opfor_SL_SOLDIER_X",         "INFANTRY",    "man",        true],
    ["opfor_TL_SOLDIER_X",         "INFANTRY",    "man",        true],
    ["opfor_MARK_SOLDIER_X",       "INFANTRY",    "man",        true],
    ["opfor_SNIPER_SOLDIER_X",     "INFANTRY",    "man",        true],
    // required=false: only the default faction defines a regular medic; the rest backfill from SPECOPS_MEDIC_X.
    ["opfor_MEDIC_X",              "INFANTRY",    "man",        false],
    ["opfor_OFFICER_X",            "INFANTRY",    "man",        true],

    ["opfor_ARMED_CAR1_X",         "VEHICLES",    "vehicle",    true],
    ["opfor_APC1_X",               "VEHICLES",    "vehicle",    true],
    ["opfor_APC2_X",               "VEHICLES",    "vehicle",    true],
    ["opfor_MBT_TANK1_X",          "VEHICLES",    "vehicle",    true],
    ["opfor_TRANS_HELI_X",         "VEHICLES",    "vehicle",    true],
    ["opfor_ATTACK_HELI_X",        "VEHICLES",    "vehicle",    true],
    ["opfor_MISC_AIR_X",           "VEHICLES",    "vehicle",    true],

    ["opfor_TURRET_AA",            "STATIC",      "static",     false],
    ["opfor_TURRET_AT",            "STATIC",      "static",     false],
    ["opfor_TURRET_HMG",           "STATIC",      "static",     true],
    ["opfor_TURRET_GMG",           "STATIC",      "static",     false],
    ["opfor_TURRET_MORTAR",        "STATIC",      "static",     false],

    ["opfor_SPECOPS_X",            "OPERATORS",   "man",        true],
    ["opfor_SPECOPS_GL_X",         "OPERATORS",   "man",        true],
    ["opfor_SPECOPS_LAT_X",        "OPERATORS",   "man",        true],
    ["opfor_SPECOPS_HAT_X",        "OPERATORS",   "man",        true],
    ["opfor_SPECOPS_AA_X",         "OPERATORS",   "man",        true],
    ["opfor_SPECOPS_MG_X",         "OPERATORS",   "man",        true],
    ["opfor_SPECOPS_MEDIC_X",      "OPERATORS",   "man",        true],
    ["opfor_SPECOPS_MARK_X",       "OPERATORS",   "man",        true],
    ["opfor_SPECOPS_SNIPER_X",     "OPERATORS",   "man",        true],
    ["opfor_SPECOPS_EXP_X",        "OPERATORS",   "man",        true],
    ["opfor_SPECOPS_ENG_X",        "OPERATORS",   "man",        true],

    ["opfor_ENG_SOLDIER_X",        "SPECIAL",     "man",        true],
    ["opfor_CREW_X",               "SPECIAL",     "man",        true],
    ["opfor_OPERATOR_X",           "SPECIAL",     "man",        true],
    ["opfor_AA_APC_X",             "SPECIAL",     "vehicle",    true],
    // SPECIAL, not VEHICLES: shared sections stay aligned across sides and only OPFOR fields a gun.
    // The player's own artillery is a support call that spawns shells, not a raised piece.
    ["opfor_ARTY_X",               "SPECIAL",     "vehicle",    false],
    ["opfor_TRANS_TRUCK_X",        "SPECIAL",     "vehicle",    true],
    ["opfor_COVERED_TRUCK_X",      "SPECIAL",     "vehicle",    true],
    ["opfor_AMMO_TRUCK_X",         "SPECIAL",     "vehicle",    true],
    ["opfor_REPAIR_TRUCK_X",       "SPECIAL",     "vehicle",    true]
]};

[
    ["blufor_SOLDIER_X",           "INFANTRY",    "man",        true],
    // The three no BLUFOR faction file has ever defined. fnc_faction_backfill borrows each from a
    // role the same side does field, so a shared team row can name them on either side.
    ["blufor_AA_SOLDIER_X",        "INFANTRY",    "man",        false],
    ["blufor_AR_SOLDIER_X",        "INFANTRY",    "man",        true],
    ["blufor_AT_SOLDIER_X",        "INFANTRY",    "man",        false],
    ["blufor_GL_SOLDIER_X",        "INFANTRY",    "man",        true],
    ["blufor_LAT_SOLDIER_X",       "INFANTRY",    "man",        true],
    ["blufor_SL_SOLDIER_X",        "INFANTRY",    "man",        true],
    ["blufor_TL_SOLDIER_X",        "INFANTRY",    "man",        true],
    ["blufor_MARK_SOLDIER_X",      "INFANTRY",    "man",        true],
    ["blufor_SNIPER_SOLDIER_X",    "INFANTRY",    "man",        false],
    // required=false: only the default faction defines a regular medic; the rest backfill from SPECOPS_MEDIC_X.
    ["blufor_MEDIC_X",             "INFANTRY",    "man",        false],
    ["blufor_OFFICER_X",           "INFANTRY",    "man",        true],

    ["blufor_ARMED_CAR1_X",        "VEHICLES",    "vehicle",    true],
    ["blufor_APC1_X",              "VEHICLES",    "vehicle",    true],
    ["blufor_APC2_X",              "VEHICLES",    "vehicle",    true],
    ["blufor_MBT_TANK1_X",         "VEHICLES",    "vehicle",    true],
    ["blufor_TRANS_HELI_X",        "VEHICLES",    "vehicle",    true],
    ["blufor_ATTACK_HELI_X",       "VEHICLES",    "vehicle",    true],
    ["blufor_MISC_AIR_X",          "VEHICLES",    "vehicle",    true],

    ["blufor_TURRET_AA",           "STATIC",      "static",     true],
    ["blufor_TURRET_AT",           "STATIC",      "static",     true],
    ["blufor_TURRET_HMG",          "STATIC",      "static",     true],
    ["blufor_TURRET_GMG",          "STATIC",      "static",     true],
    ["blufor_TURRET_MORTAR",       "STATIC",      "static",     false],

    ["blufor_SPECOPS_X",           "OPERATORS",   "man",        true],
    ["blufor_SPECOPS_GL_X",        "OPERATORS",   "man",        true],
    ["blufor_SPECOPS_LAT_X",       "OPERATORS",   "man",        true],
    ["blufor_SPECOPS_HAT_X",       "OPERATORS",   "man",        true],
    ["blufor_SPECOPS_AA_X",        "OPERATORS",   "man",        true],
    ["blufor_SPECOPS_MG_X",        "OPERATORS",   "man",        true],
    ["blufor_SPECOPS_MEDIC_X",     "OPERATORS",   "man",        true],
    ["blufor_SPECOPS_MARK_X",      "OPERATORS",   "man",        true],
    ["blufor_SPECOPS_SNIPER_X",    "OPERATORS",   "man",        true],
    ["blufor_SPECOPS_EXP_X",       "OPERATORS",   "man",        true],
    ["blufor_SPECOPS_ENG_X",       "OPERATORS",   "man",        true],

    ["blufor_HELI_PILOT_X",        "SPECIAL",     "man",        true],
    ["blufor_BOAT_ARMED_X",        "SPECIAL",     "vehicle",    true],
    // Crews the boat above, which is why it sits with the vehicles rather than the infantry.
    ["blufor_BOAT_CREW_X",         "SPECIAL",     "man",        true],
    // Wants a gun on it: fnc_helotaxi flies into contested ground, where the plain transport the
    // shared TRANS_HELI key holds is what the random patrols want.
    ["blufor_HELI_TRANS_ARM_X",    "SPECIAL",     "vehicle",    true]
]
