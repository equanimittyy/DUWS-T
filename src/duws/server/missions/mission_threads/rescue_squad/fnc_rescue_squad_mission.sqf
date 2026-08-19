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
#define CORDON_RING     120

// Faked-suppression audio: a firefight heard from the house, played via playSound3D so it leans on no
// mod content and no AI weapon choice. RSQ_FIRE_SND is a vanilla MX full-auto rifle sample; .wss, not
// .ogg, since ogg carries a start delay that reads wrong on a weapon. If BI's folder move ever silences
// it, the newer path is "a3\sounds_f\arsenal\weapons\rifles\mx\mx_short_01.wss", or drop in any weapon file.
#define RSQ_FIRE_SND    "A3\sounds_f\weapons\mx\mx-st-full-1.wss"
#define RSQ_FIRE_VOL    5
#define RSQ_FIRE_MAXD   400

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
// counts BIS_fnc_buildingPositions -- the same list each man is later dropped on by index -- so a chosen
// building has a distinct indoor slot per man rather than spilling the squad into the open around a stub.
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

// Settlement by the building, for the distress call's "near %1". Keyed on the building -- which can
// sit up to SEARCH_R off the offer point -- so it names the squad's ground, not the offer's.
private _place = [_BuildingPos] call fnc_place_name;

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

// Pinned inside the building and inert while captive: each man dropped on his own building position,
// movement off (disableAI "PATH") so he cannot wander out, and firing off (combat mode BLUE, autotarget
// off) so the squad does not one-sidedly shoot the cordon that -- being captive -- will not shoot back.
// A roaming garrison hold read wrong here: doMove walked them out of the building and combat pulled them
// into a fight the cordon could not answer. setUnitPos "MIDDLE" holds the crouch with a living idle.
private _positions = [_Building] call BIS_fnc_buildingPositions;
{
    _x setCaptive true;
    _x setSkill 1;
    _x setPosATL (_positions select _forEachIndex);
    _x setUnitPos "MIDDLE";
    _x disableAI "PATH";
    _x disableAI "AUTOTARGET";
} forEach _squadUnits;
_squadGroup setCombatMode "BLUE";

// The cordon: four OPFOR teams held at the cardinal points on a ring round the building -- three
// rifle teams and one weapons team, from the shared token vocabulary. Posture "none" so fnc_spawn_team
// drops each on the exact ring point rather than in its own band; then each holds facing in on combat
// mode YELLOW. CORDON_RING sits past 100 m and PATH is disabled on every cordon man, so the ring holds
// static -- no one advances inside 100 m of the building while the hold stands. Movement is handed back
// only when the player breaks the hold (below); until then the ring just holds while a firefight is heard
// from the house, and the player owns the ground inside it, where the squad is reached.
private _cordonTokens = ["team", "team", "team", "wp_team"];
private _cordonUnits = [];
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
        {
            _x disableAI "PATH";          // hold the ring static; no advance inside 100 m of the building
            _cordonUnits pushBack _x;
        } forEach units _g;
    };
} forEach _cordonTokens;

// One armed car idling near the building rather than patrolling. Posture "none" parks it ~100-200 m out
// (the band table's fallback for an unlisted posture) on SAFE with no circuit -- a static overwatch that
// the engine wakes to fight the moment it detects the player. Its crew count toward the relief like the
// ring teams -- breaking the cordon means the car as well -- so its units join the win set. Killing
// the car kills them; a crew that bails is mopped up on foot like any other cordon man.
private _car = [["car"] call DUWS_fnc_tokenClass, _BuildingPos, 400, "none"] call fnc_spawn_vehicle;
if (!isNull _car) then {
    [_car] call fnc_mission_claim;
    { _cordonUnits pushBack _x } forEach units _car;
};

[localize "STR_DUWS_T_Signal", format [localize "STR_DUWS_T_squadletsdothis", _place]] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_squadoverlord"] remoteExec ["fnc_duws_dialogue", 0];

// Relief flag: raised the moment the squad comes out, read by the firefight-audio thread (which cuts the
// house audio once its occupants are up) and guarding the un-captive against a double fire.
DUWS_rsq_relieved = false;
// Hold flag: raised when the player breaks the cordon's hold -- the assault lands (a cordon man takes
// fire), the cordon starts dropping, or the squad is relieved. Cuts the house audio and hands movement
// back to the ring (below). Separate from _relieved: the squad can be freed by the cordon being cleared
// from range, and the hold can break before the squad is out.
DUWS_rsq_holdBroken = false;

// The pinned squad is sold with sound, not fire. The cordon does not shoot the building: a weapon-choice
// mod (VCOM et al.) overrides the forced rifle and sends a launcher into it, so the "suppression" is a
// firefight heard from the house instead -- a positional gunfire sample looped from the building via
// playSound3D, which depends on no AI weapon and no mod content. Plays only while a player is in the outer
// band (SUPPRESS_RANGE) and the squad is holed up; stops on the first of the hold breaking, the squad
// being relieved, SUPPRESS_MAX seconds, or the deadline. Not on mere proximity -- a player sneaking to
// within a few dozen metres should not silence it. The timeout counts from the first burst, so a slow
// approach still gets the show. remoteExec'd to every client because a server-thread playSound3D is heard
// only on the host; the 3D falloff (RSQ_FIRE_MAXD) then mutes it for anyone out of earshot.
[_Building, _deadline] spawn {
    params ["_bld", "_dl"];
    private _startedAt = -1;
    while {
        (time < _dl)
        && {!DUWS_rsq_relieved}
        && {!DUWS_rsq_holdBroken}
        && {_startedAt < 0 || {(time - _startedAt) < SUPPRESS_MAX}}
    } do {
        if (((call BIS_fnc_ListPlayers) findIf { alive _x && {(_x distance2D _bld) < SUPPRESS_RANGE} }) >= 0) then {
            if (_startedAt < 0) then { _startedAt = time };
            [RSQ_FIRE_SND, _bld, false, getPosASL _bld, RSQ_FIRE_VOL, 1, RSQ_FIRE_MAXD] remoteExec ["playSound3D", 0];
            sleep (0.5 + random 0.6);
        } else {
            sleep 1;
        };
    };
};

// Breaks the hold and hands movement back to the ring. Watches for the assault landing (a cordon man
// takes fire), the cordon starting to drop, the squad being relieved, or the deadline; on any of them the
// ring's PATH is re-enabled so survivors manoeuvre and fight instead of holding static.
[_cordonUnits, _deadline] spawn {
    params ["_cordon", "_dl"];
    waitUntil {
        sleep 1;
        (time > _dl)
        || {DUWS_rsq_relieved}
        || {(_cordon findIf {alive _x && {(damage _x) > 0}}) >= 0}
        || {(_cordon findIf {!alive _x}) >= 0}
    };
    DUWS_rsq_holdBroken = true;
    { if (alive _x) then { _x enableAI "PATH" } } forEach _cordon;
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
[_squadUnits, _squadGroup, _Building, _cordonUnits, _car, _deadline] spawn {
    params ["_sq", "_grp", "_bld", "_cordon", "_carv", "_dl"];
    waitUntil {
        sleep 1;
        DUWS_rsq_relieved
        || {time > _dl}
        || {(_cordon findIf {alive _x}) < 0}
        || {((call BIS_fnc_ListPlayers) findIf { alive _x && {(_x distance2D _bld) < UNCAPTIVE_RANGE} }) >= 0}
    };
    if (!DUWS_rsq_relieved && {time <= _dl}) then {
        DUWS_rsq_relieved = true;
        // Now active and killable, and cleared to fire back (autotarget on, combat mode RED), but still
        // pinned in the building -- PATH stays off, so they defend from cover instead of charging out.
        {
            if (alive _x) then {
                _x setCaptive false;
                _x enableAI "AUTOTARGET";
            };
        } forEach _sq;
        _grp setCombatMode "RED";
        [localize "STR_DUWS_T_Signal", localize "STR_DUWS_T_lyjjiteq"] remoteExec ["fnc_duws_dialogue", 0];

        // Hold in the building until the tide turns, then release movement so they can manoeuvre and, once
        // the cordon is fully broken, walk to the evac. Standing them up lets the crouch drop as they move.
        private _half = (count _cordon) / 2;
        waitUntil {
            sleep 2;
            time > _dl
            || {(_cordon findIf {alive _x}) < 0}
            || { (({alive _x} count _cordon) <= _half) && {isNull _carv || {!alive _carv}} }
        };
        { if (alive _x) then { _x enableAI "PATH"; _x setUnitPos "AUTO" } } forEach _sq;
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
