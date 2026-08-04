// Locality: any -- a pure table, reads no engine or mission state.
//
// The one place the DUWS role schema is written down: every key a side must fill, in the order
// the faction files fill them, carrying the two facts no previous list held -- which section of
// the faction confirmation screen a key belongs to, and what kind of class may sit in it.
//
// Three consumers each held their own copy of this before: fnc_custom_faction_parse's required
// keys, and the two AutoDetect wrappers' pool-publish lists. A fourth copy for the confirmation
// screen would have made the copies disagree with each other rather than any one of them wrong.
//
// Returns [[key, group, kind], ...]:
//   key   - full global name, e.g. "blufor_SOLDIER_AR_X"
//   group - "INFANTRY" | "VEHICLES" | "STATIC" | "OPERATORS"; the confirmation screen's section,
//           and what keeps the two columns aligned when one side has more keys in a section
//   kind  - "man" | "vehicle" | "static"; which CfgVehicles branch the key editor may offer
//
// The sides are not mirror images. They hold different counts and spell the same role
// differently (blufor_SOLDIER_LAT_X against opfor_LAT_SOLDIER_X), so this is two tables rather
// than one with a prefix substituted in.
//
// The request-menu catalogues (blufor_RQST_UNITS / blufor_RQST_VEHICLES) are deliberately absent:
// they are variable-length ordered lists with no OPFOR counterpart, fnc_faction_rqst_list already
// carries fallbacks for a faction that leaves them short, and neither the validation nor the
// one-row-per-key screen can express a list.

params [["_side", "blufor"]];

if (_side == "opfor") exitWith {[
    ["opfor_SOLDIER_X",         "INFANTRY",  "man"],
    ["opfor_AA_SOLDIER_X",      "INFANTRY",  "man"],
    ["opfor_AR_SOLDIER_X",      "INFANTRY",  "man"],
    ["opfor_AT_SOLDIER_X",      "INFANTRY",  "man"],
    ["opfor_GL_SOLDIER_X",      "INFANTRY",  "man"],
    ["opfor_LAT_SOLDIER_X",     "INFANTRY",  "man"],
    ["opfor_SL_SOLDIER_X",      "INFANTRY",  "man"],
    ["opfor_TL_SOLDIER_X",      "INFANTRY",  "man"],
    ["opfor_MARK_SOLDIER_X",    "INFANTRY",  "man"],
    ["opfor_SNIPER_SOLDIER_X",  "INFANTRY",  "man"],
    ["opfor_ENG_SOLDIER_X",     "INFANTRY",  "man"],
    ["opfor_CREW_X",            "INFANTRY",  "man"],
    ["opfor_OFFICER_X",         "INFANTRY",  "man"],
    ["opfor_OPERATOR_X",        "INFANTRY",  "man"],

    ["opfor_ARMED_CAR1_X",      "VEHICLES",  "vehicle"],
    ["opfor_APC1_X",            "VEHICLES",  "vehicle"],
    ["opfor_APC2_X",            "VEHICLES",  "vehicle"],
    ["opfor_AA_APC_X",          "VEHICLES",  "vehicle"],
    ["opfor_MBT_TANK1_X",       "VEHICLES",  "vehicle"],
    ["opfor_TRANS_TRUCK_X",     "VEHICLES",  "vehicle"],
    ["opfor_COVERED_TRUCK_X",   "VEHICLES",  "vehicle"],
    ["opfor_AMMO_TRUCK_X",      "VEHICLES",  "vehicle"],
    ["opfor_REPAIR_TRUCK_X",    "VEHICLES",  "vehicle"],
    ["opfor_TRANS_HELI_X",      "VEHICLES",  "vehicle"],
    ["opfor_ATTACK_HELI_X",     "VEHICLES",  "vehicle"],
    ["opfor_MISC_AIR_X",        "VEHICLES",  "vehicle"],

    ["opfor_TURRET_HMG",        "STATIC",    "static"],

    ["opfor_SPECOPS_X",         "OPERATORS", "man"],
    ["opfor_SPECOPS_GL_X",      "OPERATORS", "man"],
    ["opfor_SPECOPS_LAT_X",     "OPERATORS", "man"],
    ["opfor_SPECOPS_HAT_X",     "OPERATORS", "man"],
    ["opfor_SPECOPS_AA_X",      "OPERATORS", "man"],
    ["opfor_SPECOPS_MG_X",      "OPERATORS", "man"],
    ["opfor_SPECOPS_MEDIC_X",   "OPERATORS", "man"],
    ["opfor_SPECOPS_MARK_X",    "OPERATORS", "man"],
    ["opfor_SPECOPS_SNIPER_X",  "OPERATORS", "man"],
    ["opfor_SPECOPS_EXP_X",     "OPERATORS", "man"],
    ["opfor_SPECOPS_ENG_X",     "OPERATORS", "man"]
]};

[
    ["blufor_SOLDIER_X",        "INFANTRY",  "man"],
    ["blufor_SOLDIER_LAT_X",    "INFANTRY",  "man"],
    ["blufor_SOLDIER_GL_X",     "INFANTRY",  "man"],
    ["blufor_SOLDIER_TL_X",     "INFANTRY",  "man"],
    ["blufor_SOLDIER_SL_X",     "INFANTRY",  "man"],
    ["blufor_SOLDIER_AR_X",     "INFANTRY",  "man"],
    ["blufor_MARKSMAN_X",       "INFANTRY",  "man"],
    ["blufor_OFFICER_X",        "INFANTRY",  "man"],
    ["blufor_HELI_PILOT_X",     "INFANTRY",  "man"],

    ["blufor_BOAT_ARMED_X",     "VEHICLES",  "vehicle"],
    // Crews the boat above, which is why it sits with the vehicles rather than the infantry.
    ["blufor_BOAT_CREW_X",      "VEHICLES",  "man"],
    ["blufor_HELI_TRANS_ARM_X", "VEHICLES",  "vehicle"],
    ["blufor_HELI_TRANS_UNARM_X", "VEHICLES", "vehicle"],
    ["blufor_HELI_ATTACK_X",    "VEHICLES",  "vehicle"],
    ["blufor_PLANE_CAS_X",      "VEHICLES",  "vehicle"],
    ["blufor_CAR_PATROL1_X",    "VEHICLES",  "vehicle"],
    ["blufor_APC_PATROL1_X",    "VEHICLES",  "vehicle"],
    ["blufor_APC_PATROL2_X",    "VEHICLES",  "vehicle"],
    ["blufor_TANK_PATROL1_X",   "VEHICLES",  "vehicle"],

    ["blufor_TURRET_AA",        "STATIC",    "static"],
    ["blufor_TURRET_AT",        "STATIC",    "static"],
    ["blufor_TURRET_HMG",       "STATIC",    "static"],
    ["blufor_TURRET_GMG",       "STATIC",    "static"],

    ["blufor_SPECOPS_X",        "OPERATORS", "man"],
    ["blufor_SPECOPS_GL_X",     "OPERATORS", "man"],
    ["blufor_SPECOPS_LAT_X",    "OPERATORS", "man"],
    ["blufor_SPECOPS_HAT_X",    "OPERATORS", "man"],
    ["blufor_SPECOPS_AA_X",     "OPERATORS", "man"],
    ["blufor_SPECOPS_MG_X",     "OPERATORS", "man"],
    ["blufor_SPECOPS_MEDIC_X",  "OPERATORS", "man"],
    ["blufor_SPECOPS_MARK_X",   "OPERATORS", "man"],
    ["blufor_SPECOPS_SNIPER_X", "OPERATORS", "man"],
    ["blufor_SPECOPS_EXP_X",    "OPERATORS", "man"],
    ["blufor_SPECOPS_ENG_X",    "OPERATORS", "man"]
]
