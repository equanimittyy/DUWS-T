// Locality: server -- called from the zone spawn path and the mission patrol builders, all
// server-side.
//
// Places one named vehicle and gives it a patrol circuit. It picks nothing: which vehicle a token
// fields, and whether the side may field it at all, is DUWS_spawnVehicles and DUWS_fnc_tokenClass.
// The weighted pools this replaces were a second, invisible composition -- an "armored" slot rolled
// against four trucks, and an air slot with helicopters switched off fell through to the same pool
// and became a truck.
//
// usage: [_class, _pos, _radius] call fnc_random_veh
//
// Returned rather than spawned into the void, for the callers that count what they raised.
params ["_class", "_patrolCenter", "_radius"];
if (_class == "") exitWith { grpNull };

// Air enters from off the map at altitude and everything else from a safe spot on the ground. Keyed
// on the class rather than on the token that asked for it: the engine's own answer cannot disagree
// with what was actually spawned, where a token could be filed under the wrong category.
private _isAir = _class isKindOf "Air";
private _vehpos = if (_isAir) then {
    private _bearing = random 360;
    private _dist = 2000 + random 3000;
    private _p = _patrolCenter getPos [_dist, _bearing];
    [_p select 0, _p select 1, 800]
} else {
    [_patrolCenter, 100, 200, 15, 0, 0.5, 0, [], []] call BIS_fnc_findSafePos
};

private _created = [_vehpos, 0, _class, EAST] call BIS_fnc_spawnVehicle;
private _veh = _created select 0;
private _vehGroup = _created select 2;
_vehGroup deleteGroupWhenEmpty true;

if (_isAir) then {
    _veh engineOn true;
    _veh flyInHeight 150;
    private _speaker = localize "STR_DUWS_T_OVERLORD";
    private _message = localize "STR_DUWS_T_opforairspotted";
    [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
};

_vehGroup setCombatMode "YELLOW";
{
    private _wp = _vehGroup addWaypoint [_patrolCenter, _radius];
    _wp setWaypointType "SAD";
    _wp setWaypointBehaviour "SAFE";
    _wp setWaypointSpeed "LIMITED";
    _wp setWaypointCompletionRadius 100;
    // A ground patrol holds each leg for a minute so a zone is not circled at speed; an aircraft
    // loitering on a waypoint is a stationary target.
    if (!_isAir) then { _wp setWaypointTimeout [60, 61, 62] };
} forEach [1, 2, 3];

private _wp1 = _vehGroup addWaypoint [_patrolCenter, 100];
_wp1 setWaypointType "CYCLE";
_wp1 setWaypointBehaviour "SAFE";
_wp1 setWaypointSpeed "LIMITED";

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
