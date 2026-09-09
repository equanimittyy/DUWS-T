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
// Columns: [role key, ladder of buckets in preference order]
//
// A rung is skipped when the faction has nothing in it, so the ladder reads as what the role
// degrades through. The vanilla-CSAT stand-in each role falls back to lives in the schema (its
// vanillaDefault column), which fnc_faction_resolve appends as the ladder's last rung when a row
// carries no explicit fallback -- so a stand-in is written once and cannot drift from the BLUFOR side
// or the empty-key fill. It only applies to a faction that fields nothing for the role, and
// fnc_faction_resolve drops any stand-in a given install does not have.

    ["opfor_SOLDIER_X",         [_grunt, _infantry]],
    ["opfor_AA_SOLDIER_X",      [_aa, _hat, _lat, _grunt, _infantry]],
    ["opfor_AR_SOLDIER_X",      [_ar, _mg, _grunt, _infantry]],
    ["opfor_AT_SOLDIER_X",      [_hat, _lat, _aa, _grunt, _infantry]],
    ["opfor_GL_SOLDIER_X",      [_gl, _grunt, _infantry]],
    ["opfor_LAT_SOLDIER_X",     [_lat, _hat, _aa, _grunt, _infantry]],
    ["opfor_SL_SOLDIER_X",      [_sl, _tl, _officer, _grunt, _infantry]],
    ["opfor_TL_SOLDIER_X",      [_tl, _sl, _grunt, _infantry]],
    ["opfor_MARK_SOLDIER_X",    [_marksman, _sniper, _grunt, _infantry]],
    ["opfor_SNIPER_SOLDIER_X",  [_sniper, _marksman, _grunt, _infantry]],
    ["opfor_ENG_SOLDIER_X",     [_eng, _exp, _grunt, _infantry]],
    ["opfor_CREW_X",            [_crew, _pilot, _grunt, _infantry]],
    ["opfor_OFFICER_X",         [_officer, _sl, _tl, _grunt, _infantry]],
    ["opfor_OPERATOR_X",        [_spec, _sl, _grunt, _infantry]],

    ["opfor_ARMED_CAR1_X",      [_carArmed, _apcWheeled, _carTransport]],
    ["opfor_APC1_X",            [_apcWheeled, _apcTracked, _carArmed]],
    ["opfor_APC2_X",            [_apcTracked, _apcWheeled, _carArmed]],
    ["opfor_AA_APC_X",          [_antiAir, _apcTracked, _apcWheeled]],
    ["opfor_MBT_TANK1_X",       [_tank, _apcTracked, _apcWheeled]],
    // One rung and no degrade: every other bucket holds direct-fire vehicles, and a tank standing in
    // for a gun is a battery that cannot answer a fire mission -- which reads as broken artillery
    // rather than as a faction that fields none. The vanilla piece is the honest substitute.
    ["opfor_ARTY_X",            [_arty]],
    ["opfor_TRANS_TRUCK_X",     [_carTransport, _carArmed]],
    ["opfor_COVERED_TRUCK_X",   [_carTransport, _carArmed]],
    ["opfor_AMMO_TRUCK_X",      [_carRearm, _carTransport]],
    ["opfor_REPAIR_TRUCK_X",    [_carRepair, _carTransport]],
    ["opfor_TRANS_HELI_X",      [_heliTransport, _heliArmed]],
    ["opfor_ATTACK_HELI_X",     [_heliArmed, _droneAir, _heliTransport]],
    ["opfor_MISC_AIR_X",        [_planeArmed, _droneAir, _heliArmed]],
    ["opfor_BOAT_ARMED_X",      [_boatArmed]],

    // Derived rather than hardcoded: the HMG was pinned to a guerrilla static, so every faction in
    // the game garrisoned its zones with the same gun. The other four keys are read by
    // fnc_static_resolve, which turns a composition's vanilla placeholder into the faction's own
    // emplacement. Each bottoms out in the faction's MG before the vanilla tail: an MG nest is the
    // stand-in every role degrades to, and it keeps a zone inside the faction it names.
    ["opfor_TURRET_AA",         [_turretAA, _turretAT, _turretHMG, _turretAny]],
    ["opfor_TURRET_AT",         [_turretAT, _turretAA, _turretHMG, _turretAny]],
    ["opfor_TURRET_HMG",        [_turretHMG, _turretGMG, _turretAT, _turretAny]],
    ["opfor_TURRET_GMG",        [_turretGMG, _turretHMG, _turretAny]],
    ["opfor_TURRET_MORTAR",     [_turretMortar, _turretGMG, _turretHMG, _turretAny]],

    // Operators draw from the suppressed-weapon sets the role parser fills, then from the plain
    // role. The old spelling was `_spec arrayIntersect _lat + _aa`, which parses as
    // `(_spec arrayIntersect _lat) + _aa` -- every anti-air man in the faction, operator or not.
    ["opfor_SPECOPS_X",         [_spec_sl, _spec, _sl, _grunt, _infantry]],
    ["opfor_SPECOPS_GL_X",      [_spec_gl, _gl, _grunt, _infantry]],
    ["opfor_SPECOPS_LAT_X",     [_spec_lat, _lat, _hat, _grunt, _infantry]],
    ["opfor_SPECOPS_HAT_X",     [_spec_hat, _hat, _lat, _grunt, _infantry]],
    ["opfor_SPECOPS_AA_X",      [_spec_aa, _aa, _hat, _grunt, _infantry]],
    ["opfor_SPECOPS_MG_X",      [_spec_mg, _spec_ar, _mg, _ar, _grunt, _infantry]],
    ["opfor_SPECOPS_MEDIC_X",   [_spec_medic, _medic, _grunt, _infantry]],
    ["opfor_SPECOPS_MARK_X",    [_spec_marksman, _marksman, _sniper, _grunt]],
    ["opfor_SPECOPS_SNIPER_X",  [_spec_sniper, _sniper, _marksman, _grunt]],
    ["opfor_SPECOPS_EXP_X",     [_spec_exp, _exp, _eng, _grunt, _infantry]],
    ["opfor_SPECOPS_ENG_X",     [_spec_eng, _eng, _exp, _grunt, _infantry]]
