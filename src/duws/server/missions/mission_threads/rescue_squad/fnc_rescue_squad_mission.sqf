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
#define SUPPRESS_MAX    150
#define UNCAPTIVE_RANGE 50
#define CORDON_RING     80

private _compKey = "mission_rescue_squad";
private _radius = 300;
private _cpreward = DUWS_curReward select 0;
private _apreward = DUWS_curReward select 1;
private _deadline = DUWS_curDeadlineAt;

// The elite BLUFOR squad, raised first so the building check can be sized to it: from the "recon"
// roster (SPECOPS) through the shared token vocabulary, so it is both elite and faction-safe --
// fnc_faction_pick / backfill covers a role a given pack never named, where a hardcoded
// blufor_SPECOPS_* list would spawn a man short on one that omits it.
private _squadClasses = ["recon", "blufor"] call DUWS_fnc_teamRoster;
private _squadSize = count _squadClasses;

// Site: enterable buildings near the offer that can garrison the whole squad, minus any sitting in a
// zone (its own radius plus a margin) or inside a civilian town. fnc_civ_townAt is -1 when clear -- and
// always -1 with civilians off, so the town half of the filter simply passes then. The seating check
// counts BIS_fnc_buildingPositions -- the same list fnc_spreadIntoBuildings places into -- so a chosen
// building actually holds the squad indoors rather than spilling it into the open around a stub.
private _zoneMeta = missionNamespace getVariable ["zone_meta_array", []];
private _candidates = ([_MissionPos, 2, SEARCH_R] call fnc_usableBuildings) select {
    private _bp = getPos _x;
    (count ([_x] call BIS_fnc_buildingPositions) >= _squadSize)
    && {[_bp] call fnc_civ_townAt < 0}
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

// Holed up in the building and captive: passive and unkillable until relieved, so the cordon cannot
// wipe them before the player arrives. Maxed skill: once they come out they fight their own corner.
private _squadGroup = [_BuildingPos, WEST, _squadClasses, [], [], 1] call BIS_fnc_spawnGroup;
_squadGroup deleteGroupWhenEmpty true;
[_squadGroup] call fnc_mission_claim;
private _squadUnits = units _squadGroup;
{ _x setCaptive true; _x setSkill 1 } forEach _squadUnits;

// Garrison the building through the shared hold system rather than pinning them with disableAI "PATH":
// fnc_spreadIntoBuildings drops each man on a building position and starts a per-unit doMove loop
// (fnc_holdBuildingPost) that keeps pathing on, so they work the windows and fight from cover instead of
// freezing on one spot. "MIDDLE" keeps the holed-up crouch; the hold re-asserts it each pass, so it never
// sticks the way the old raw switchMove pose did. Released per unit via DUWS_postReleased on break-out.
[_squadGroup, [_Building], (count _squadUnits), "MIDDLE"] call fnc_spreadIntoBuildings;

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

// Scripted small-arms suppression on the held building, to sell the squad being pinned. Fires only
// while a player is in the outer band (SUPPRESS_RANGE) and the squad is still holed up. It backs off --
// and the cordon reverts to fighting the player normally -- once any of: a suppress unit takes fire (the
// assault has begun), SUPPRESS_MAX seconds of firing elapse, the cordon breaks, or the deadline passes.
// Not on mere proximity -- a player sneaking to within a few dozen metres should not silence the cordon.
// The timeout counts from the first shot, not from spawn, so a slow approach still gets the full show.
//
// forceWeaponFire on the primary weapon, not doSuppressiveFire on the building: doSuppressiveFire needs
// line of sight -- nothing happens when the shooter cannot see the building -- and picks whatever weapon
// the unit holds, so a launcher levels the building on the first shot. Forcing the rifle keeps it to
// small arms and fires in the held direction with no target or LOS needed; doWatch points them in, and
// is dropped when suppression ends so they re-acquire the player instead of staring at the wall.
[_suppressUnits, _Building, _BuildingPos, _deadline] spawn {
    params ["_shooters", "_bld", "_bpos", "_dl"];
    private _startedAt = -1;
    while {
        (time < _dl)
        && {(_shooters findIf {alive _x}) >= 0}
        && {!DUWS_rsq_relieved}
        && {(_shooters findIf {(damage _x) > 0}) < 0}
        && {_startedAt < 0 || {(time - _startedAt) < SUPPRESS_MAX}}
    } do {
        if (((call BIS_fnc_ListPlayers) findIf { alive _x && {(_x distance2D _bld) < SUPPRESS_RANGE} }) >= 0) then {
            if (_startedAt < 0) then { _startedAt = time };
            {
                if (alive _x) then {
                    _x doWatch _bpos;
                    private _w = primaryWeapon _x;
                    if (_w != "") then {
                        private _modes = getArray (configFile >> "CfgWeapons" >> _w >> "modes");
                        private _mode = if (_modes isEqualTo []) then {_w} else {_modes select 0};
                        // Some weapons list ["this"], meaning the mode config sits on the weapon itself.
                        if (_mode == "this") then { _mode = _w };
                        _x forceWeaponFire [_w, _mode];
                    };
                };
            } forEach _shooters;
        };
        sleep 3;
    };
    { if (alive _x) then { _x doWatch objNull } } forEach _shooters;
};

// Un-captive on the first of: player within UNCAPTIVE_RANGE, or the cordon wiped (so a player who
// clears it from range still gets the squad out). Not on the deadline -- a timed-out squad is lost,
// not freed. The greeting is order-independent on purpose: it must read whether the cordon is still
// up or already gone (see fnc_duws_dialogue notes / player_facing_text.md).
//
// Un-captive turns them active and killable but leaves them garrisoned -- PATH stays off, so they defend
// the building from cover instead of charging a still-intact cordon. They break out and path freely only
// once the tide has turned enough to keep them alive: at least half the cordon down AND the armed car
// destroyed (a car that never spawned counts as gone, so the gate falls back to the half-cordon check).
[_squadUnits, _Building, _cordonUnits, _car, _deadline] spawn {
    params ["_sq", "_bld", "_cordon", "_carv", "_dl"];
    waitUntil {
        sleep 1;
        DUWS_rsq_relieved
        || {time > _dl}
        || {(_cordon findIf {alive _x}) < 0}
        || {((call BIS_fnc_ListPlayers) findIf { alive _x && {(_x distance2D _bld) < UNCAPTIVE_RANGE} }) >= 0}
    };
    if (!DUWS_rsq_relieved && {time <= _dl}) then {
        DUWS_rsq_relieved = true;
        // Active and killable, but still holding their posts -- they fight from the building, not out in
        // the open. Stance stays with the hold loop (crouched) until the post is released below.
        { if (alive _x) then { _x setCaptive false } } forEach _sq;
        [localize "STR_DUWS_T_Signal", localize "STR_DUWS_T_lyjjiteq"] remoteExec ["fnc_duws_dialogue", 0];

        // Hold the garrison until the tide turns, then release the posts so they can manoeuvre and, once
        // the cordon is fully broken, walk to the evac. Standing them up here lets the crouch drop as they
        // break cover; the hold loop stops re-asserting it once DUWS_postReleased is set.
        private _half = (count _cordon) / 2;
        waitUntil {
            sleep 2;
            time > _dl
            || {(_cordon findIf {alive _x}) < 0}
            || { (({alive _x} count _cordon) <= _half) && {isNull _carv || {!alive _carv}} }
        };
        { if (alive _x) then { _x setVariable ["DUWS_postReleased", true]; _x setUnitPos "AUTO" } } forEach _sq;
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
    // Stand the posts down at once: cleanup deletes the squad on a timed sweep, and a held loop would
    // keep reissuing doMove on the survivors until then.
    { _x setVariable ["DUWS_postReleased", true] } forEach _squadUnits;
    [localize "STR_DUWS_T_OVERLORD", [localize "STR_DUWS_T_squadfail"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
    [_marker] call fnc_missionMarkerClear;
    [_taskId, "FAILED"] call fnc_missionTaskEnd;
    [_BuildingPos, _radius, _compKey] call fnc_mission_end;
};

DUWS_rsq_relieved = true;
[_squadUnits, _Building, _marker, _taskId, _BuildingPos, _radius, _compKey, _mission_name, _cpreward, _apreward] call fnc_rescue_squad_success;
