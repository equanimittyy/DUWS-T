// The OPFOR AutoDetect role ladders: which detection buckets each DUWS role key draws from, in
// preference order, and what it falls back to when the faction fields nothing for the role.
// Included as the body of an array literal, inside fnc_factionGen where the buckets are locals:
//
//     { _x call fnc_faction_resolve } forEach [
//     #include "..\..\includes\autodetect_roles_opfor.hpp"
//     ];
//
// Shared because AUTODETECT_opfor and AUTODETECT_RANDOM_opfor resolve the same keys from the same
// buckets and differ only in how the faction is chosen. As two copies they drifted: one fell back
// to a T-100 for a tank, the other to a civilian offroad, and an attack helicopter fell back to an
// unarmed one. Bug fixes landed in whichever copy was open at the time.
//
// Columns: [role key, ladder of buckets in preference order, fallback when every rung is empty]
//
// A rung is skipped when the faction has nothing in it, so the ladder reads as what the role
// degrades through. Fallbacks are vanilla CSAT: they only apply to a faction that fields nothing
// for the role, and fnc_faction_resolve drops any that a given install does not have.

    ["opfor_SOLDIER_X",         [_grunt, _infantry],                                "O_Soldier_F"],
    ["opfor_AA_SOLDIER_X",      [_aa, _hat, _lat, _grunt, _infantry],               "O_Soldier_AA_F"],
    ["opfor_AR_SOLDIER_X",      [_ar, _mg, _grunt, _infantry],                      "O_Soldier_AR_F"],
    ["opfor_AT_SOLDIER_X",      [_hat, _lat, _aa, _grunt, _infantry],               "O_Soldier_AT_F"],
    ["opfor_GL_SOLDIER_X",      [_gl, _grunt, _infantry],                           "O_Soldier_GL_F"],
    ["opfor_LAT_SOLDIER_X",     [_lat, _hat, _aa, _grunt, _infantry],               "O_Soldier_LAT_F"],
    ["opfor_SL_SOLDIER_X",      [_sl, _tl, _officer, _grunt, _infantry],            "O_Soldier_SL_F"],
    ["opfor_TL_SOLDIER_X",      [_tl, _sl, _grunt, _infantry],                      "O_Soldier_TL_F"],
    ["opfor_MARK_SOLDIER_X",    [_marksman, _sniper, _grunt, _infantry],            "O_soldier_M_F"],
    ["opfor_SNIPER_SOLDIER_X",  [_sniper, _marksman, _grunt, _infantry],            "O_sniper_F"],
    ["opfor_ENG_SOLDIER_X",     [_eng, _exp, _grunt, _infantry],                    "O_engineer_F"],
    ["opfor_CREW_X",            [_crew, _pilot, _grunt, _infantry],                 "O_crew_F"],
    ["opfor_OFFICER_X",         [_officer, _sl, _tl, _grunt, _infantry],            "O_officer_F"],
    ["opfor_OPERATOR_X",        [_spec, _sl, _grunt, _infantry],                    "O_recon_F"],

    ["opfor_ARMED_CAR1_X",      [_carArmed, _apcWheeled, _carTransport],            "O_LSV_02_armed_F"],
    ["opfor_APC1_X",            [_apcWheeled, _apcTracked, _carArmed],              "O_APC_Tracked_02_cannon_F"],
    ["opfor_APC2_X",            [_apcTracked, _apcWheeled, _carArmed],              "O_APC_Tracked_02_cannon_F"],
    ["opfor_AA_APC_X",          [_antiAir, _apcTracked, _apcWheeled],               "O_APC_Tracked_02_AA_F"],
    ["opfor_MBT_TANK1_X",       [_tank, _apcTracked, _apcWheeled],                  "O_MBT_02_cannon_F"],
    // One rung and no degrade: every other bucket holds direct-fire vehicles, and a tank standing in
    // for a gun is a battery that cannot answer a fire mission -- which reads as broken artillery
    // rather than as a faction that fields none. The vanilla piece is the honest substitute.
    ["opfor_ARTY_X",            [_arty],                                            "O_MBT_02_arty_F"],
    ["opfor_TRANS_TRUCK_X",     [_carTransport, _carArmed],                         "O_Truck_03_transport_F"],
    ["opfor_COVERED_TRUCK_X",   [_carTransport, _carArmed],                         "O_Truck_03_covered_F"],
    ["opfor_AMMO_TRUCK_X",      [_carRearm, _carTransport],                         "O_Truck_03_ammo_F"],
    ["opfor_REPAIR_TRUCK_X",    [_carRepair, _carTransport],                        "O_Truck_03_repair_F"],
    ["opfor_TRANS_HELI_X",      [_heliTransport, _heliArmed],                       "O_Heli_Light_02_unarmed_F"],
    ["opfor_ATTACK_HELI_X",     [_heliArmed, _droneAir, _heliTransport],            "O_Heli_Attack_02_dynamicLoadout_F"],
    ["opfor_MISC_AIR_X",        [_planeArmed, _droneAir, _heliArmed],               "O_Plane_CAS_02_dynamicLoadout_F"],

    // Derived rather than hardcoded: the HMG was pinned to a guerrilla static, so every faction in
    // the game garrisoned its zones with the same gun. The other four keys are read by
    // fnc_static_resolve, which turns a composition's vanilla placeholder into the faction's own
    // emplacement. Each bottoms out in the faction's MG before the vanilla tail: an MG nest is the
    // stand-in every role degrades to, and it keeps a zone inside the faction it names.
    ["opfor_TURRET_AA",         [_turretAA, _turretAT, _turretHMG],                 "O_static_AA_F"],
    ["opfor_TURRET_AT",         [_turretAT, _turretAA, _turretHMG],                 "O_static_AT_F"],
    ["opfor_TURRET_HMG",        [_turretHMG, _turretGMG, _turretAT],                "O_HMG_01_high_F"],
    ["opfor_TURRET_GMG",        [_turretGMG, _turretHMG],                           "O_GMG_01_high_F"],
    ["opfor_TURRET_MORTAR",     [_turretMortar, _turretGMG, _turretHMG],            "O_Mortar_01_F"],

    // Operators draw from the suppressed-weapon sets the role parser fills, then from the plain
    // role. The old spelling was `_spec arrayIntersect _lat + _aa`, which parses as
    // `(_spec arrayIntersect _lat) + _aa` -- every anti-air man in the faction, operator or not.
    ["opfor_SPECOPS_X",         [_spec_sl, _spec, _sl, _grunt, _infantry],          "O_recon_F"],
    ["opfor_SPECOPS_GL_X",      [_spec_gl, _gl, _grunt, _infantry],                 "O_Soldier_GL_F"],
    ["opfor_SPECOPS_LAT_X",     [_spec_lat, _lat, _hat, _grunt, _infantry],         "O_recon_LAT_F"],
    ["opfor_SPECOPS_HAT_X",     [_spec_hat, _hat, _lat, _grunt, _infantry],         "O_Soldier_AT_F"],
    ["opfor_SPECOPS_AA_X",      [_spec_aa, _aa, _hat, _grunt, _infantry],           "O_Soldier_AA_F"],
    ["opfor_SPECOPS_MG_X",      [_spec_mg, _spec_ar, _mg, _ar, _grunt, _infantry],  "O_Soldier_AR_F"],
    ["opfor_SPECOPS_MEDIC_X",   [_spec_medic, _medic, _grunt, _infantry],           "O_recon_medic_F"],
    ["opfor_SPECOPS_MARK_X",    [_spec_marksman, _marksman, _sniper, _grunt],       "O_recon_M_F"],
    ["opfor_SPECOPS_SNIPER_X",  [_spec_sniper, _sniper, _marksman, _grunt],         "O_sniper_F"],
    ["opfor_SPECOPS_EXP_X",     [_spec_exp, _exp, _eng, _grunt, _infantry],         "O_recon_exp_F"],
    ["opfor_SPECOPS_ENG_X",     [_spec_eng, _eng, _exp, _grunt, _infantry],         "O_engineer_F"]
