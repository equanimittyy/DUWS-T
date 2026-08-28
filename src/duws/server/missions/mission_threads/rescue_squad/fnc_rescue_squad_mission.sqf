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
#define DRY_RADIUS      100     // reject a building with water this close: a shoreline site drowns the fight
#define UNCAPTIVE_RANGE 50
#define CORDON_RING     120
#define SUPPRESS_RANGE  300     // suppression plays only while a player is this close to the building
#define SUPPRESS_MAX    150     // seconds of suppression from the first burst before it lapses on its own

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
// zone (its own radius plus a margin), inside a civilian town, or on the waterline. fnc_civ_townAt is -1
// when clear -- and always -1 with civilians off, so the town half of the filter simply passes then. The
// seating check counts BIS_fnc_buildingPositions -- the same list each man is later dropped on by index --
// so a chosen building has a distinct indoor slot per man rather than spilling the squad into the open
// around a stub. The water guard samples the centre and a ring at DRY_RADIUS (surfaceIsWater is point-wise,
// so a shoreline lot with the cordon ring reaching into the sea is rejected on any wet sample).
private _zoneMeta = missionNamespace getVariable ["zone_meta_array", []];
private _candidates = ([_MissionPos, 2, SEARCH_R] call fnc_usableBuildings) select {
    private _bp = getPos _x;
    (count ([_x] call BIS_fnc_buildingPositions) >= _squadSize)
    && {[_bp] call fnc_civ_townAt < 0}
    && {(_zoneMeta findIf { _bp distance2D (_x select 1) < ((_x select 2) + ZONE_MARGIN) }) < 0}
    && {!surfaceIsWater _bp}
    && {([0, 45, 90, 135, 180, 225, 270, 315] findIf { surfaceIsWater (_bp getPos [DRY_RADIUS, _x]) }) < 0}
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

// Brief opens the mission, before the squad/cordon spawn below: those spawns cost seconds and must not
// delay the opening line. Signal calls it in, Overlord confirms 8s on; neither reads the spawned units.
[localize "STR_DUWS_T_Signal", format [localize "STR_DUWS_T_squadletsdothis", _place]] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_squadoverlord"] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_squadcopy"] remoteExec ["fnc_duws_dialogue", 0];

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

// The cordon: four OPFOR teams held at the cardinal points on a ring round the building -- three rifle
// teams and one weapons team, from the shared token vocabulary. Posture "none" drops each team on its
// cardinal ring point; a small per-man setPos then loosens the clump so the ring reads as spread positions
// rather than four stacks. Each holds facing in on combat mode YELLOW. CORDON_RING sits past 100 m and the
// scatter is capped under 20 m, so even a man thrown building-ward stays outside 100 m; PATH is disabled on
// every cordon man, so the ring holds static -- no one advances inside 100 m while the hold stands. Movement
// is handed back only when the player breaks the hold (below); until then the ring holds and suppresses the
// building, and the player owns the ground inside it, where the squad is reached.
//
// Who suppresses: anyone but a grenadier or a launcher man. A GL lobs 40 mm into the building and a rocket
// levels it -- both wreck the hostage backdrop the suppression sells -- so a unit with an underbarrel GL (a
// primary muzzle past the bare "this") or a launcher in the secondary slot is cut, and every rifleman,
// autorifleman and MG gunner is kept. Weapon-based, so it holds across faction packs that never named a role.
private _canSuppress = {
    private _w = primaryWeapon _this;
    _w != ""
    && {secondaryWeapon _this == ""}
    && {(getArray (configFile >> "CfgWeapons" >> _w >> "muzzles") findIf { _x != "this" }) < 0}
};
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
        {
            _x disableAI "PATH";          // hold the ring static; no advance inside 100 m of the building
            _x setPos (_cpos getPos [4 + random 12, random 360]);   // loosen the clump; under 20 m keeps it past 100 m
            _x setUnitPos "MIDDLE";        // crouched on spawn; released to AUTO once the ring is built (below)
            _cordonUnits pushBack _x;
            if (_x call _canSuppress) then { _suppressUnits pushBack _x };
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

// Crouched on spawn but not pinned there (unlike the captive squad): after a beat AUTO hands the stance
// back, so a cordon man stands, drops or takes cover as the fight tells him to instead of holding a frozen
// crouch. Harmless on the car crew that rode into _cordonUnits -- setUnitPos AUTO is a no-op while mounted.
_cordonUnits spawn { sleep 4; { _x setUnitPos "AUTO" } forEach _this; };

// Relief flag: raised the moment the squad comes out, guarding the un-captive against a double fire and
// read by both the suppression thread (which stops hosing the building once its occupants are up) and the
// ring-release thread below.
DUWS_rsq_relieved = false;
// Hold flag: raised when the ring-release thread fires -- the assault lands (a cordon man takes fire), the
// cordon starts dropping, the squad is relieved, or the deadline. Stops the suppression and hands movement
// back to the ring. Separate from _relieved: the hold can break before the squad is out.
DUWS_rsq_holdBroken = false;

// The cordon hoses the building on full auto to sell the squad being pinned. Fires only while a player is
// in the outer band (SUPPRESS_RANGE) and the squad is still holed up; stops on the first of the hold
// breaking, the squad being relieved, SUPPRESS_MAX seconds, every shooter down, or the deadline. Not on mere
// proximity -- a player inside a few dozen metres should not silence it. The timeout counts from the first
// burst, so a slow approach still gets the show.
//
// forceWeaponFire, not doSuppressiveFire: the latter fires nothing when a ring man has no sightline, and is
// free to pick the heaviest weapon (a rifleman levels the building with his launcher). forceWeaponFire
// discharges the named primary regardless of LOS or target, so every shooter fires and nothing explosive is
// ever selected -- grenadiers and launcher men are already cut upstream. doWatch points each man at the
// building first so the rounds go downrange. One forceWeaponFire is a single auto burst; each shooter is
// re-fired on its own jittered interval -- a shared cadence would rip the whole ring in perfect unison --
// so the bursts overlap into continuous fire. forceWeaponFire reloads from the shooter's own mags, so the
// ring thins and goes quiet as men burn through their loadout.
[_suppressUnits, _Building, _deadline] spawn {
    params ["_shooters", "_bld", "_dl"];
    // Full-auto mode name for a weapon: a mode named auto/full, else the last mode (auto is listed last by
    // convention) -- so the ring fires on auto across faction packs. An empty or ["this"] modes list is a
    // single-mode weapon whose mode name is the weapon name itself.
    private _autoMode = {
        params ["_wpn"];
        private _ms = getArray (configFile >> "CfgWeapons" >> _wpn >> "modes");
        if (_ms isEqualTo [] || {_ms isEqualTo ["this"]}) exitWith { _wpn };
        private _i = _ms findIf { private _l = toLower _x; (_l find "auto" >= 0) || {_l find "full" >= 0} };
        if (_i < 0) then { _i = (count _ms) - 1 };
        _ms select _i
    };
    // Resolve each shooter's weapon + auto mode once (the config walk must not run every tick) plus a
    // per-shooter next-fire time (slot 3) for the jittered schedule below. Every shooter is guaranteed a
    // primary upstream (_canSuppress), so no empty-weapon guard is needed here.
    private _plan = [];
    { _plan pushBack [_x, primaryWeapon _x, [primaryWeapon _x] call _autoMode, 0] } forEach _shooters;
    private _startedAt = -1;
    while {
        (time < _dl)
        && {(_shooters findIf {alive _x}) >= 0}
        && {!DUWS_rsq_relieved}
        && {!DUWS_rsq_holdBroken}
        && {_startedAt < 0 || {(time - _startedAt) < SUPPRESS_MAX}}
    } do {
        if (((call BIS_fnc_ListPlayers) findIf { alive _x && {(_x distance2D _bld) < SUPPRESS_RANGE} }) >= 0) then {
            if (_startedAt < 0) then {
                _startedAt = time;
                // Stagger the opening: seed each shooter due within the first 0.6s so the ring does not all
                // fire on the same instant it starts up.
                { _x set [3, time + random 0.6] } forEach _plan;
            };
            {
                _x params ["_u", "_w", "_mode", "_next"];
                if (alive _u && {time >= _next}) then {
                    _u doWatch _bld;
                    _u forceWeaponFire [_w, _mode];
                    _x set [3, time + 0.4 + random 0.6];   // desynced auto: 0.4-1.0s to this shooter's next burst
                };
            } forEach _plan;
            sleep 0.15;   // fine master tick so each shooter fires close to its scheduled time
        } else {
            sleep 1;
        };
    };
};

// Hands movement back to the ring. Watches for the assault landing (a cordon man takes fire), the cordon
// starting to drop, the squad being relieved, or the deadline; on any of them the hold is marked broken --
// stopping the suppression -- and the ring's PATH is re-enabled so survivors manoeuvre instead of holding.
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
// up or already gone (see fnc_duws_dialogue notes / player_text_style_guide.md).
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
