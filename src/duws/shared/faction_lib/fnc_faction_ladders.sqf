// Locality: server -- AutoDetect, the augment pass and the list editor's Make main all resolve there.
//
// The one table of which detection buckets each role key draws from, in preference order. AutoDetect
// resolves a key from its first rung with anything in it (fnc_faction_resolve). A class that a faction
// file names or the player makes main takes its siblings from the first rung that holds it
// (fnc_faction_pool_for_role). Both read this table, so a rebuilt list keeps to the constraints detection
// applied, and every bucket a ladder names must hold only classes that role may field.
//
// A rung the faction has nothing in is skipped, so a ladder reads as what the role degrades through.
// The vanilla stand-in is the schema's vanillaDefault, which fnc_faction_resolve appends.

// _parsed is fnc_parseFaction's return.
fnc_faction_ladders = {
    params ["_side", "_parsed"];
    _parsed params ["_infantry", "_infantryByRoles", "_boat", "_droneAir", "_droneLand", "_droneStatic", "_submersible",
        "_turretHMG", "_turretGMG", "_turretMortar", "_turretAA", "_turretAT", "_apcWheeled", "_apcTracked", "_tank",
        "_arty", "_antiAir", "_carArmed", "_carTransport", "_carRearm", "_carRepair", "_carRefuel", "_heliArmed",
        "_heliTransport", "_planeArmed", "_planeTransport", "_heliDoorGun", "_boatArmed", "_droneAirArmed"];
    _infantryByRoles params ["_grunt","_medic","_sl","_tl","_ar","_mg","_gl","_aa","_lat","_hat","_officer","_spec","_diver","_pilot","_crew","_marksman","_sniper","_eng","_exp","_uavOp"] +
        ["_spec","_spec_medic","_spec_sl","_spec_tl","_spec_ar","_spec_mg","_spec_gl","_spec_aa","_spec_lat","_spec_hat","_spec_marksman","_spec_sniper","_spec_eng","_spec_exp"];

    // Any static the faction fields, the last rung under every turret role: it keeps a zone inside the
    // faction it names when no weapon bucket matched.
    private _turretAny = _turretHMG + _turretGMG + _turretMortar + _turretAA + _turretAT;
    _turretAny = _turretAny arrayIntersect _turretAny;

    if (_side == "opfor") exitWith {[
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
        // No degrade: a tank standing in for a gun is a battery that cannot answer a fire mission, which
        // reads as broken artillery. The vanilla piece is the honest substitute.
        ["opfor_ARTY_X",            [_arty]],
        ["opfor_TRANS_TRUCK_X",     [_carTransport, _carArmed]],
        ["opfor_COVERED_TRUCK_X",   [_carTransport, _carArmed]],
        ["opfor_AMMO_TRUCK_X",      [_carRearm, _carTransport]],
        ["opfor_REPAIR_TRUCK_X",    [_carRepair, _carTransport]],
        ["opfor_TRANS_HELI_X",      [_heliTransport, _heliDoorGun, _heliArmed]],
        ["opfor_ATTACK_HELI_X",     [_heliArmed, _droneAirArmed, _heliDoorGun, _heliTransport]],
        ["opfor_MISC_AIR_X",        [_planeArmed, _droneAirArmed, _heliArmed]],
        ["opfor_BOAT_ARMED_X",      [_boatArmed]],

        // Each bottoms out in the faction's MG before the vanilla tail: an MG nest is the stand-in every
        // role degrades to.
        ["opfor_TURRET_AA",         [_turretAA, _turretAT, _turretHMG, _turretAny]],
        ["opfor_TURRET_AT",         [_turretAT, _turretAA, _turretHMG, _turretAny]],
        ["opfor_TURRET_HMG",        [_turretHMG, _turretGMG, _turretAT, _turretAny]],
        ["opfor_TURRET_GMG",        [_turretGMG, _turretHMG, _turretAny]],
        ["opfor_TURRET_MORTAR",     [_turretMortar, _turretGMG, _turretHMG, _turretAny]],

        // One rung per bucket, not summed pairs: `_spec arrayIntersect _lat + _aa` parses as
        // `(_spec arrayIntersect _lat) + _aa`, every anti-air man in the faction.
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
    ]};

    [
        ["blufor_SOLDIER_X",          [_grunt, _sl, _gl, _infantry]],
        ["blufor_AA_SOLDIER_X",       [_aa, _hat, _lat, _grunt, _infantry]],
        ["blufor_AR_SOLDIER_X",       [_ar, _mg, _grunt, _infantry]],
        ["blufor_AT_SOLDIER_X",       [_hat, _lat, _aa, _grunt, _infantry]],
        ["blufor_GL_SOLDIER_X",       [_gl, _grunt, _infantry]],
        ["blufor_LAT_SOLDIER_X",      [_lat, _hat, _aa, _grunt, _infantry]],
        ["blufor_SL_SOLDIER_X",       [_sl, _tl, _officer, _grunt, _infantry]],
        ["blufor_TL_SOLDIER_X",       [_tl, _sl, _grunt, _infantry]],
        ["blufor_MARK_SOLDIER_X",     [_marksman, _sniper, _grunt, _infantry]],
        ["blufor_SNIPER_SOLDIER_X",   [_sniper, _marksman, _grunt, _infantry]],
        ["blufor_OFFICER_X",          [_officer, _sl, _tl, _grunt, _infantry]],

        ["blufor_ARMED_CAR1_X",       [_carArmed, _apcWheeled, _carTransport]],
        ["blufor_APC1_X",             [_apcTracked, _apcWheeled, _carArmed]],
        ["blufor_APC2_X",             [_apcWheeled, _apcTracked, _carArmed]],
        ["blufor_MBT_TANK1_X",        [_tank, _apcTracked, _apcWheeled]],
        ["blufor_TRANS_HELI_X",       [_heliTransport, _heliDoorGun, _heliArmed]],
        ["blufor_ATTACK_HELI_X",      [_heliArmed, _droneAirArmed, _heliDoorGun, _heliTransport]],
        ["blufor_MISC_AIR_X",         [_planeArmed, _droneAirArmed]],

        ["blufor_TURRET_AA",          [_turretAA, _turretAT, _turretHMG, _turretAny]],
        ["blufor_TURRET_AT",          [_turretAT, _turretAA, _turretHMG, _turretAny]],
        ["blufor_TURRET_HMG",         [_turretHMG, _turretGMG, _turretAny]],
        ["blufor_TURRET_GMG",         [_turretGMG, _turretHMG, _turretAny]],
        // The GMG rung before the MG one: a grenade launcher is the nearest thing a faction with no
        // tube has to arcing HE.
        ["blufor_TURRET_MORTAR",      [_turretMortar, _turretGMG, _turretHMG, _turretAny]],

        ["blufor_SPECOPS_X",          [_spec_sl, _spec, _sl, _grunt, _infantry]],
        ["blufor_SPECOPS_GL_X",       [_spec_gl, _gl, _grunt, _infantry]],
        ["blufor_SPECOPS_LAT_X",      [_spec_lat, _lat, _hat, _grunt, _infantry]],
        ["blufor_SPECOPS_HAT_X",      [_spec_hat, _hat, _lat, _grunt, _infantry]],
        ["blufor_SPECOPS_AA_X",       [_spec_aa, _aa, _hat, _grunt, _infantry]],
        ["blufor_SPECOPS_MG_X",       [_spec_mg, _spec_ar, _mg, _ar, _grunt, _infantry]],
        ["blufor_SPECOPS_MEDIC_X",    [_spec_medic, _medic, _grunt, _infantry]],
        ["blufor_SPECOPS_MARK_X",     [_spec_marksman, _marksman, _sniper, _grunt]],
        ["blufor_SPECOPS_SNIPER_X",   [_spec_sniper, _sniper, _marksman, _grunt]],
        ["blufor_SPECOPS_EXP_X",      [_spec_exp, _exp, _eng, _grunt, _infantry]],
        ["blufor_SPECOPS_ENG_X",      [_spec_eng, _eng, _exp, _grunt, _infantry]],

        ["blufor_COVERED_TRUCK_X",    [_carTransport, _carArmed]],
        ["blufor_TRANS_TRUCK_X",      [_carTransport, _carArmed]],

        ["blufor_HELI_PILOT_X",       [_pilot, _crew, _grunt]],
        ["blufor_BOAT_ARMED_X",       [_boatArmed]],
        ["blufor_BOAT_CREW_X",        [_crew]],
        ["blufor_BOAT_TRANS_X",       [_boat, _boatArmed]],
        ["blufor_HELI_TRANS_ARM_X",   [_heliDoorGun, _heliTransport]]
    ]
};

// A class no rung of the role's ladder holds stands alone rather than borrow siblings from a bucket that
// feeds another role. Class first, where fnc_faction_pools_publish reads the representative. Callers pass
// a cached parse or it parses here.
fnc_faction_pool_for_role = {
    params ["_key", "_class", ["_parsed", []]];
    if (_class isEqualTo "") exitWith { [] };
    if (_parsed isEqualTo []) then {
        _parsed = [getText (configFile >> "CfgVehicles" >> _class >> "faction")] call fnc_parseFaction;
    };
    private _side = if (_key select [0, 6] isEqualTo "opfor_") then {"opfor"} else {"blufor"};
    private _row = ([_side, _parsed] call fnc_faction_ladders) select { (_x select 0) isEqualTo _key };
    if (_row isEqualTo []) exitWith { [_class] };
    private _ladder = (_row select 0) select 1;
    private _i = _ladder findIf { _class in _x };
    if (_i < 0) exitWith { [_class] };
    [_class] + ((_ladder select _i) - [_class])
};
