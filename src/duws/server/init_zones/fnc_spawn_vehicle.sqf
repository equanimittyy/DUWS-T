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
params ["_class", "_patrolCenter", "_radius", ["_posture", "closepatrol"], ["_spawnPos", []]];
if (_class == "") exitWith { grpNull };

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
        [_patrolCenter, _minR, _maxR, 15, 0, 0.5, 0, [], []] call BIS_fnc_findSafePos
    }
};

private _created = [_vehpos, 0, _class, EAST] call BIS_fnc_spawnVehicle;
private _veh = _created select 0;
private _vehGroup = _created select 2;
_vehGroup deleteGroupWhenEmpty true;

if (_isAir) then {
    _veh engineOn true;
    _veh flyInHeight 150;
};

[_vehGroup, _posture, _patrolCenter, _radius] call fnc_apply_posture;

{
    [_x] call fnc_addRandomLoot;
    // Crew in a mod's own flight suit read as that mod's faction on a body search. Skipped for the
    // BLUFOR faction files that dress their own pilots, which would otherwise be overwritten.
    if (_isAir && {!(("OPTRE" in BLUFOR_FactionFile_X)
        || {"HL2ECR" in BLUFOR_FactionFile_X}
        || {"TIOW" in BLUFOR_FactionFile_X})}) then {
        _x forceAddUniform "U_I_pilotCoveralls";
    };
    _x setSkill opfor_ai_skill_random;
} forEach units _vehGroup;

_vehGroup
