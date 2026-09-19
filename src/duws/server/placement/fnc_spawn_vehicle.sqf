// Locality: server -- called from the zone spawn path and the mission patrol builders, all
// server-side.
//
// Places one named vehicle and gives it a patrol circuit -- the vehicle half of fnc_spawn_team, and
// named to match it. It picks nothing: which vehicle a token fields, and whether the side may field
// it at all, is DUWS_spawnVehicles and DUWS_fnc_tokenClass.
//
// Returned rather than spawned into the void, for the callers that count what they raised.
//
// _posture is fnc_apply_posture's, the same vocabulary a rifle section is ordered in: a vehicle is a
// group like any other once it is standing. The postures that put men inside a structure answer for
// a mounted group by patrolling instead, so a composition may name any of them without having to
// know what it is naming.
//
// _spawnPos is the reserve path's, as in fnc_spawn_team: a reinforcement vehicle is placed on the
// point the pass chose. It reaches ground vehicles only -- air still enters from off the map, since a
// reserve gunship makes no sense parked on the far ridge at zero altitude.
params ["_class", "_patrolCenter", "_radius", ["_posture", "closepatrol"], ["_spawnPos", []], ["_side", "opfor"]];
if (_class == "") exitWith { grpNull };

// _side ("opfor"/"blufor") sets the engine side and the crew skill, and defaults to opfor so the
// existing callers spawn as before. Which vehicle a token fields for a side is resolved upstream by
// DUWS_fnc_tokenClass, so the class reaching this file is already the right side's -- _side here only
// mans and colours the hull.
private _army = [EAST, WEST] select (_side isEqualTo "blufor");

// Air enters from off the map at altitude and everything else from a safe spot on the ground. Keyed
// on the class rather than on the token that asked for it: the engine's own answer cannot disagree
// with what was actually spawned, where a table row can be mistyped.
private _isAir = _class isKindOf "Air";
private _vehpos = if (_isAir) then {
    private _bearing = random 360;
    private _dist = 2000 + random 3000;
    private _p = _patrolCenter getPos [_dist, _bearing];
    [_p select 0, _p select 1, 800]
} else {
    // Ground vehicles follow the posture band like a rifle section, so a wide vehicle patrol does not
    // spawn on top of the objective it is meant to screen. Air stays unbanded: it enters from off the
    // map. A caller-supplied point overrides the band, the way it does for a team.
    if (_spawnPos isNotEqualTo []) then { _spawnPos } else {
        private _band = DUWS_postureBands getOrDefault [_posture, []];
        private _minR = 100;
        private _maxR = 200;
        if (_band isNotEqualTo []) then {
            _minR = (_band select 0) * _radius;
            _maxR = (_band select 1) * _radius;
        };
        [_patrolCenter, _maxR, _minR, 15, 0.5] call fnc_mission_safepos
    }
};

private _created = [_vehpos, 0, _class, _army] call BIS_fnc_spawnVehicle;
private _veh = _created select 0;
private _vehGroup = _created select 2;
_vehGroup deleteGroupWhenEmpty true;

if (_isAir) then {
    _veh engineOn true;
    _veh flyInHeight 150;
};

[_vehGroup, _posture, _patrolCenter, _radius] call fnc_apply_posture;

{
    // Random loot is OPFOR's alone: a friendly crew the player fights alongside should not drop it.
    if (_side isEqualTo "opfor") then { [_x] call fnc_addRandomLoot; };
    // Crew in a mod's own flight suit read as that mod's faction on a body search. OPFOR only: the
    // coveralls are an independent-side pilot suit, wrong on a BLUFOR crew, and body-search identity
    // only matters for the enemy the player searches. Skipped for the BLUFOR faction files that dress
    // their own pilots, which would otherwise be overwritten.
    if (_side isEqualTo "opfor" && {_isAir} && {!(("OPTRE" in BLUFOR_FactionFile_X)
        || {"HL2ECR" in BLUFOR_FactionFile_X}
        || {"TIOW" in BLUFOR_FactionFile_X})}) then {
        _x forceAddUniform "U_I_pilotCoveralls";
    };
    _x setSkill (missionNamespace getVariable [format ["%1_ai_skill_random", _side], opfor_ai_skill_random]);
} forEach units _vehGroup;

_vehGroup
