// Parse pasted custom-faction text into ["<var> = <class>", ...] assignment
// fragments, then report which required faction keys the paste failed to define.
// Shared by the paste screen's submit validation (client) and the deferred faction
// build (server).
//
// Side effect: compiling the fragments assigns the faction globals. That is the
// intent server-side; on the client it is a transient pre-check, overwritten when
// the server's data is applied. Every required key is cleared first so a leftover
// value from a previous faction/paste can't mask a key this paste never defines --
// a misspelled key (blufor_SOLDER_X) leaves its canonical name (blufor_SOLDIER_X)
// cleared, so it is reported missing rather than silently accepted.
//
// Returns [_pairs, _valid, _missing]:
//   _pairs   - compiled assignment fragments (consumed by the server build)
//   _valid   - true when no required key is missing
//   _missing - full names of required keys left unset (e.g. "blufor_SOLDIER_X")

params ["_side", "_text"];

private _isOpfor = (_side == "opfor");
private _prefix = if (_isOpfor) then {"opfor_"} else {"blufor_"};

// Core combat keys a faction must define, mirroring the preset faction files (and
// the AutoDetect *_arraysToRandomize lists). The numbered RQST_UNIT/RQST_VEHICLE
// request-menu catalogue is intentionally excluded: it is variable-length and has
// code fallbacks, so it isn't required for the war itself to run.
private _requiredKeys = if (_isOpfor) then {[
    "opfor_SOLDIER_X","opfor_AA_SOLDIER_X","opfor_AR_SOLDIER_X","opfor_AT_SOLDIER_X",
    "opfor_GL_SOLDIER_X","opfor_LAT_SOLDIER_X","opfor_SL_SOLDIER_X","opfor_TL_SOLDIER_X",
    "opfor_MARK_SOLDIER_X","opfor_CREW_X","opfor_ENG_SOLDIER_X","opfor_SNIPER_SOLDIER_X",
    "opfor_OFFICER_X","opfor_OPERATOR_X","opfor_COVERED_TRUCK_X","opfor_TRANS_TRUCK_X",
    "opfor_AMMO_TRUCK_X","opfor_REPAIR_TRUCK_X","opfor_APC1_X","opfor_ARMED_CAR1_X",
    "opfor_MBT_TANK1_X","opfor_APC2_X","opfor_AA_APC_X","opfor_TRANS_HELI_X",
    "opfor_ATTACK_HELI_X","opfor_MISC_AIR_X","opfor_TURRET_HMG","opfor_SPECOPS_X",
    "opfor_SPECOPS_GL_X","opfor_SPECOPS_LAT_X","opfor_SPECOPS_HAT_X","opfor_SPECOPS_AA_X",
    "opfor_SPECOPS_MG_X","opfor_SPECOPS_MEDIC_X","opfor_SPECOPS_MARK_X","opfor_SPECOPS_SNIPER_X",
    "opfor_SPECOPS_EXP_X","opfor_SPECOPS_ENG_X"
]} else {[
    "blufor_SOLDIER_X","blufor_SOLDIER_LAT_X","blufor_SOLDIER_GL_X","blufor_SOLDIER_TL_X",
    "blufor_SOLDIER_SL_X","blufor_SOLDIER_AR_X","blufor_MARKSMAN_X","blufor_OFFICER_X",
    "blufor_HELI_PILOT_X","blufor_BOAT_ARMED_X","blufor_BOAT_CREW_X","blufor_HELI_TRANS_ARM_X",
    "blufor_HELI_TRANS_UNARM_X","blufor_HELI_ATTACK_X","blufor_PLANE_CAS_X","blufor_CAR_PATROL1_X",
    "blufor_APC_PATROL1_X","blufor_APC_PATROL2_X","blufor_TANK_PATROL1_X","blufor_TURRET_AA",
    "blufor_TURRET_AT","blufor_TURRET_HMG","blufor_TURRET_GMG","blufor_SPECOPS_X",
    "blufor_SPECOPS_GL_X","blufor_SPECOPS_LAT_X","blufor_SPECOPS_HAT_X","blufor_SPECOPS_AA_X",
    "blufor_SPECOPS_MG_X","blufor_SPECOPS_MEDIC_X","blufor_SPECOPS_MARK_X","blufor_SPECOPS_SNIPER_X",
    "blufor_SPECOPS_EXP_X","blufor_SPECOPS_ENG_X"
]};

// keep only "<prefix>..." lines, break each on ";", drop path-like junk
private _pairs = (_text splitString (toString [13,10])) select { _prefix in _x };
_pairs = flatten (_pairs apply { _x splitString ";" });
_pairs = _pairs select { !(["/", _x] call BIS_fnc_inString) };

// Clear the required keys, then apply the paste over the top.
{ missionNamespace setVariable [_x, ""]; } forEach _requiredKeys;
{ call compile _x; } forEach _pairs;

// "Set" = a non-empty string or a non-empty array (faction authors may list
// several classnames for a role, as the AutoDetect path does).
private _fnc_isSet = {
    private _v = missionNamespace getVariable [_this, ""];
    if (_v isEqualType []) exitWith { count _v > 0 };
    (_v isEqualType "") && {_v != ""}
};

private _missing = _requiredKeys select { !(_x call _fnc_isSet) };
private _valid = _missing isEqualTo [];

[_pairs, _valid, _missing]
