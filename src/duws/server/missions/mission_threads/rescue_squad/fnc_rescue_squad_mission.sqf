// Locality: server -- callers remoteExec to target 2; the sub-threads spawned here inherit it.
//
// Rescue an elite squad pinned in a building by an enemy cordon. The win is breaking the cordon, not
// reaching the squad: the squad is held captive -- unkillable and passive -- until the player closes
// to UNCAPTIVE_RANGE or the cordon is wiped, whichever comes first. Only then does it come out and
// fight as its own group (it never joins the player). Once the cordon is dead an evac helicopter
// flies the squad off the map (see fnc_rescue_squad_success), captive so nothing downs it, and the
// player cannot board. Deadline, or the squad being wiped after it comes out, fail the mission --
// both voiced by Overlord rather than dropped as a hint.
//
// The site is filtered off held zones and civilian towns: a captive squad and a building-suppressing
// cordon read wrong inside a garrison or a town street, and the cordon fight wants open ground.
params ["_MissionPos", "_mission_name"];
if (!([0, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

#define SEARCH_R        400
#define ZONE_MARGIN     150
#define SUPPRESS_RANGE  300
#define UNCAPTIVE_RANGE 50
#define CORDON_RING     80

private _compKey = "mission_rescue_squad";
private _radius = 300;
private _cpreward = DUWS_curReward select 0;
private _apreward = DUWS_curReward select 1;
private _deadline = DUWS_curDeadlineAt;

// Site: usable buildings near the offer, minus any sitting in a zone (its own radius plus a margin)
// or inside a civilian town. fnc_civ_townAt is -1 when clear -- and always -1 with civilians off, so
// the town half of the filter simply passes then.
private _zoneMeta = missionNamespace getVariable ["zone_meta_array", []];
private _candidates = ([_MissionPos, 5, SEARCH_R] call fnc_usableBuildings) select {
    private _bp = getPos _x;
    ([_bp] call fnc_civ_townAt < 0)
    && {(_zoneMeta findIf { _bp distance2D (_x select 1) < ((_x select 2) + ZONE_MARGIN) }) < 0}
};
if (_candidates isEqualTo []) exitWith {
    [0, "STR_DUWS_T_mission_no_building"] call fnc_mission_abort;
};
private _Building = selectRandom _candidates;
private _BuildingPos = getPos _Building;

// Marked on the building itself, not the offer point: the building can sit up to SEARCH_R away, and
// the ellipse and the task are the only things pointing the player at the objective.
private _marker = [_BuildingPos, _radius] call fnc_missionMarkerData;
private _taskId = format ["rescue%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_taskId, localize "STR_DUWS_T_kievbwmd", _mission_name, _BuildingPos, "help"] call fnc_missionTaskCreate;
[localize "STR_DUWS_T_c0", {hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];

// Elite BLUFOR squad, holed up in the building and captive: passive and unkillable until relieved,
// so the cordon cannot wipe them before the player arrives. Raised from the "recon" roster (SPECOPS)
// through the shared token vocabulary, so it is both elite and faction-safe -- fnc_faction_pick /
// backfill covers a role a given pack never named, where a hardcoded blufor_SPECOPS_* list would
// spawn a man short on one that omits it. Maxed skill: once they come out they fight their own corner.
private _squadClasses = ["recon", "blufor"] call DUWS_fnc_teamRoster;
private _squadGroup = [_BuildingPos, WEST, _squadClasses, [], [], 1] call BIS_fnc_spawnGroup;
_squadGroup deleteGroupWhenEmpty true;
[_squadGroup] call fnc_mission_claim;
private _squadUnits = units _squadGroup;
{
    private _bpos = _Building buildingPos (3 + _forEachIndex);
    if ((_bpos select 0) == 0) then { _bpos = _BuildingPos };
    _x setPosATL _bpos;
    _x setCaptive true;
    _x disableAI "PATH";
    _x setSkill 1;
    // switchMove is local, so posing from the server alone leaves every client a squad standing
    // about. Keyed by netId so a joiner finds them held; the key is dropped when they are freed.
    [_x, "acts_CrouchingIdleRifle01"] remoteExec ["switchMove", 0, format ["rescue_pose_%1", netId _x]];
} forEach _squadUnits;

// The cordon: four OPFOR teams held at the cardinal points on a ring round the building -- three
// rifle teams and one weapons team, from the shared token vocabulary. Posture "none" so fnc_spawn_team
// drops each on the exact ring point rather than in its own band; then each holds facing in on combat
// mode YELLOW (fire at will, keep formation) so it works the ring and never charges the objective. The
// ring keeps them off the building -- the player owns the last UNCAPTIVE_RANGE metres, where the squad
// is reached. One rifle team suppresses (below); the rest hold and engage on contact.
private _cordonTokens = ["team", "team", "team", "wp_team"];
private _cordonUnits = [];
private _suppressUnits = [];
{
    private _bearing = _forEachIndex * 90;
    private _cpos = _BuildingPos getPos [CORDON_RING, _bearing];
    private _g = [_x, _BuildingPos, _radius, "none", _cpos] call fnc_spawn_team;
    if (!isNull _g) then {
        [_g] call fnc_mission_claim;
        _g setBehaviour "COMBAT";
        _g setCombatMode "YELLOW";
        _g setFormDir (_cpos getDir _BuildingPos);
        private _wp = _g addWaypoint [_cpos, 0];
        _wp setWaypointType "HOLD";
        { _cordonUnits pushBack _x } forEach units _g;
        if (_forEachIndex == 0) then { _suppressUnits = units _g };
    };
} forEach _cordonTokens;

// One armed car on a wide patrol, screening the approaches. Its crew count toward the relief like the
// ring teams -- breaking the cordon means the car as well -- so its units join the win set. Killing
// the car kills them; a crew that bails is mopped up on foot like any other cordon man.
private _car = [["car"] call DUWS_fnc_tokenClass, _BuildingPos, 400, "widepatrol"] call fnc_spawn_vehicle;
if (!isNull _car) then {
    [_car] call fnc_mission_claim;
    { _cordonUnits pushBack _x } forEach units _car;
};

[localize "STR_DUWS_T_Signal", localize "STR_DUWS_T_squadletsdothis"] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_squadoverlord"] remoteExec ["fnc_duws_dialogue", 0];

// Relief flag: raised the moment the squad comes out, read by the suppression thread (which stops
// hosing the building once its occupants are up) and guarding the un-captive against a double fire.
DUWS_rsq_relieved = false;

// Suppressive fire, gated on a player closing to SUPPRESS_RANGE. Before that the cordon just holds --
// no point firing on an empty building while the player is still at HQ. Once someone is near and the
// squad is still holed up, living cordon units fire on the building. Stops when the cordon breaks,
// the squad comes out, or the deadline passes.
[_suppressUnits, _Building, _deadline] spawn {
    params ["_shooters", "_bld", "_dl"];
    while { (time < _dl) && {(_shooters findIf {alive _x}) >= 0} && {!DUWS_rsq_relieved} } do {
        if (((call BIS_fnc_ListPlayers) findIf { alive _x && {(_x distance2D _bld) < SUPPRESS_RANGE} }) >= 0) then {
            { if (alive _x) then { _x doSuppressiveFire _bld } } forEach _shooters;
        };
        sleep 6;
    };
};

// Un-captive on the first of: player within UNCAPTIVE_RANGE, or the cordon wiped (so a player who
// clears it from range still gets the squad out). Not on the deadline -- a timed-out squad is lost,
// not freed. The greeting is order-independent on purpose: it must read whether the cordon is still
// up or already gone (see fnc_duws_dialogue notes / player_facing_text.md).
[_squadUnits, _Building, _cordonUnits, _deadline] spawn {
    params ["_sq", "_bld", "_cordon", "_dl"];
    waitUntil {
        sleep 1;
        DUWS_rsq_relieved
        || {time > _dl}
        || {(_cordon findIf {alive _x}) < 0}
        || {((call BIS_fnc_ListPlayers) findIf { alive _x && {(_x distance2D _bld) < UNCAPTIVE_RANGE} }) >= 0}
    };
    if (!DUWS_rsq_relieved && {time <= _dl}) then {
        DUWS_rsq_relieved = true;
        {
            if (alive _x) then {
                _x setCaptive false;
                _x enableAI "PATH";
                [_x, ""] remoteExec ["switchMove", 0];
                remoteExec ["", format ["rescue_pose_%1", netId _x]];
            };
        } forEach _sq;
        [localize "STR_DUWS_T_Signal", localize "STR_DUWS_T_lyjjiteq"] remoteExec ["fnc_duws_dialogue", 0];
    };
};

// Win = cordon broken with the squad still alive. Deadline (cordon not cleared in time) or the squad
// wiped after it came out both fail.
waitUntil {
    sleep 2;
    ((_cordonUnits findIf {alive _x}) < 0)
    || {time > _deadline}
    || {(_squadUnits findIf {alive _x}) < 0}
};

if (((_cordonUnits findIf {alive _x}) >= 0) || {(_squadUnits findIf {alive _x}) < 0}) exitWith {
    DUWS_rsq_relieved = true;
    [localize "STR_DUWS_T_OVERLORD", [localize "STR_DUWS_T_squadfail"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
    [_marker] call fnc_missionMarkerClear;
    [_taskId, "FAILED"] call fnc_missionTaskEnd;
    [_BuildingPos, _radius, _compKey] call fnc_mission_end;
};

DUWS_rsq_relieved = true;
[_squadUnits, _Building, _marker, _taskId, _BuildingPos, _radius, _compKey, _mission_name, _cpreward, _apreward] call fnc_rescue_squad_success;
