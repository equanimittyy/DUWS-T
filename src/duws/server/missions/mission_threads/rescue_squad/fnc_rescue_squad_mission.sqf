// Locality: server -- callers remoteExec to target 2; the sub-threads spawned here inherit it.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;
if (!([0, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

#define SEARCH_R        400
#define ZONE_MARGIN     150
#define DRY_RADIUS      100     // reject a building with water this close: a shoreline site drowns the fight
#define UNCAPTIVE_RANGE 100
#define CORDON_RING     120
#define SUPPRESS_RANGE  400     // suppression plays only while a player is this close to the building
#define SUPPRESS_MAX    150     // seconds of suppression from the first burst before it lapses on its own

private _compKey = "mission_rescue_squad";
private _radius = 300;
private _deadline = DUWS_curDeadlineAt;

// The elite BLUFOR squad. Its size is counted from the "recon" token up front (DUWS_fnc_tokenMenCount
// raises no men) so the building check below can be sized to it; the squad itself is raised from the
// same token at the chosen building, staying elite and faction-safe where a hardcoded list would spawn
// a man short on a pack that omits the role.
private _squadSize = ["recon"] call DUWS_fnc_tokenMenCount;

// Site: enterable buildings near the offer that can garrison the whole squad, minus any in a zone (radius
// plus margin), in a civilian town (fnc_civ_townAt, always -1 with civilians off), or on the waterline.
// The seating check counts BIS_fnc_buildingPositions -- the same list each man is dropped on by index --
// so the squad gets a slot each. Water is sampled at the centre and a DRY_RADIUS ring (surfaceIsWater is
// point-wise), rejecting a shoreline lot whose cordon ring reaches the sea.
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
    [0, _requester, "no_building"] call fnc_mission_abort;
};
private _Building = selectRandom _candidates;
private _BuildingPos = getPos _Building;

// Settlement by the building, for the distress call's "near %1". Keyed on the building -- which can
// sit up to SEARCH_R off the offer point -- so it names the squad's ground, not the offer's.
private _place = [_BuildingPos] call fnc_place_name;

// Marked on the building itself, not the offer point (it can sit up to SEARCH_R away).
private _taskId = format ["rescue%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;

// Holed up in the building and captive: passive and unkillable until relieved, so the cordon cannot
// wipe them before the player arrives. Maxed skill: once they come out they fight their own corner.
private _squadGroup = ["recon", _BuildingPos, 0, "none", _BuildingPos, "blufor"] call fnc_spawn_team;
[_squadGroup] call fnc_mission_claim;
private _squadUnits = units _squadGroup;

// Pinned and inert while captive: each man on his own building position, PATH off so he cannot wander out,
// firing off (combat mode BLUE, autotarget off) so the squad does not one-sidedly shoot a cordon that,
// being captive, cannot shoot back. setUnitPos "MIDDLE" holds a crouch with a living idle.
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

// The cordon: four OPFOR teams (three rifle, one weapons) held at the cardinal ring points round the
// building. Posture "none" drops each on its point; a per-man setPos loosens the clump. CORDON_RING is
// past 100 m and the scatter capped under 20 m, so even a building-ward man stays outside 100 m; PATH off
// on every cordon man holds the ring static until the player breaks the hold (below).
//
// Who suppresses: not a grenadier or launcher man -- a 40 mm or rocket into the building wrecks the hostage
// backdrop -- so a unit with an underbarrel GL (a muzzle past the bare "this") or a secondary launcher is
// cut, riflemen/AR/MG kept. Weapon-based, so it holds across faction packs that never named a role.
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

// One armed car idling near the building (posture "none" parks it ~100-200 m out on SAFE, no circuit) --
// a static overwatch the engine wakes on detecting the player. Its crew count toward the relief like the
// ring teams, so their units join the win set; a bailed crew is mopped up on foot.
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

// The cordon hoses the building on full auto to sell the squad being pinned. Armed by the first player
// inside SUPPRESS_RANGE, then fires to completion regardless of range -- fire-and-forget, so backing out
// past the edge does not cut it short. Stops on hold-break, relief, SUPPRESS_MAX, all shooters down, or deadline.
//
// forceWeaponFire, not doSuppressiveFire: the latter fires nothing without a sightline and may pick the
// heaviest weapon (a rifleman levels the building with his launcher). forceWeaponFire discharges the named
// primary regardless of LOS, so every shooter fires and nothing explosive is selected (grenadiers/launchers
// already cut upstream); doWatch aims them first. Each shooter re-fires on its own jittered interval so the
// bursts overlap rather than ripping in unison, and reloads from its own mags, so the ring thins and quiets.
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
        ((call fnc_campaign_now) < _dl)
        && {(_shooters findIf {alive _x}) >= 0}
        && {!DUWS_rsq_relieved}
        && {!DUWS_rsq_holdBroken}
        && {_startedAt < 0 || {(time - _startedAt) < SUPPRESS_MAX}}
    } do {
        if (_startedAt < 0) then {
            if (((call BIS_fnc_ListPlayers) findIf { alive _x && {(_x distance2D _bld) < SUPPRESS_RANGE} }) >= 0) then {
                _startedAt = time;
                // Stagger the opening: seed each shooter due within the first 0.6s so the ring does not all
                // fire on the same instant it starts up.
                { _x set [3, time + random 0.6] } forEach _plan;
            } else {
                sleep 1;
            };
        };
        if (_startedAt >= 0) then {
            {
                _x params ["_u", "_w", "_mode", "_next"];
                if (alive _u && {time >= _next}) then {
                    _u doWatch _bld;
                    _u forceWeaponFire [_w, _mode];
                    _x set [3, time + 0.4 + random 0.6];   // desynced auto: 0.4-1.0s to this shooter's next burst
                };
            } forEach _plan;
            sleep 0.15;   // fine master tick so each shooter fires close to its scheduled time
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
        ([_dl] call fnc_time_expired)
        || {DUWS_rsq_relieved}
        || {(_cordon findIf {alive _x && {(damage _x) > 0}}) >= 0}
        || {(_cordon findIf {!alive _x}) >= 0}
    };
    DUWS_rsq_holdBroken = true;
    { if (alive _x) then { _x enableAI "PATH" } } forEach _cordon;
};

// Un-captive on the first of: player within UNCAPTIVE_RANGE, or the cordon wiped (a player who clears it
// from range still frees them). Not on the deadline -- a timed-out squad is lost, not freed. Un-captive
// makes them active and killable but leaves PATH off, so they defend from cover rather than charge an
// intact cordon; they path out only once the tide turns -- half the cordon down AND the armed car gone
// (a car that never spawned counts as gone).
[_squadUnits, _squadGroup, _Building, _cordonUnits, _car, _deadline] spawn {
    params ["_sq", "_grp", "_bld", "_cordon", "_carv", "_dl"];
    waitUntil {
        sleep 1;
        DUWS_rsq_relieved
        || {[_dl] call fnc_time_expired}
        || {(_cordon findIf {alive _x}) < 0}
        || {((call BIS_fnc_ListPlayers) findIf { alive _x && {(_x distance2D _bld) < UNCAPTIVE_RANGE} }) >= 0}
    };
    if (!DUWS_rsq_relieved && {(call fnc_campaign_now) <= _dl}) then {
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

        // Player is at the wire: the ring collapses onto the building so the fight converges on the hostages,
        // not a static cordon picked apart from outside. LIMITED to close as a line, not a race. PATH re-enabled
        // in case hold-break never fired -- a player who reached the wire without drawing a shot.
        private _opforGroups = [];
        { if (alive _x) then { _opforGroups pushBackUnique (group _x) } } forEach _cordon;
        {
            private _g = _x;
            { _x enableAI "PATH" } forEach units _g;
            for "_i" from (count (waypoints _g)) - 1 to 0 step -1 do { deleteWaypoint [_g, _i] };
            _g setBehaviour "COMBAT";
            private _wp = _g addWaypoint [_bld, 0];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "LIMITED";
            _wp setWaypointBehaviour "COMBAT";
        } forEach _opforGroups;

        // Hold in the building until the tide turns, then release movement so they can manoeuvre and, once
        // the cordon is fully broken, walk to the evac. Standing them up lets the crouch drop as they move.
        private _half = (count _cordon) / 2;
        waitUntil {
            sleep 2;
            [_dl] call fnc_time_expired
            || {(_cordon findIf {alive _x}) < 0}
            || { (({alive _x} count _cordon) <= _half) && {isNull _carv || {!alive _carv}} }
        };
        { if (alive _x) then { _x enableAI "PATH"; _x setUnitPos "AUTO" } } forEach _sq;
    };
};

// Brief stays manual: fixed speakers, no callsign substitution.
private _marker = [_BuildingPos, _radius, _taskId, localize "STR_DUWS_T_kievbwmd", _mission_name, "help"] call fnc_mission_present;
[localize "STR_DUWS_T_Signal", format [localize "STR_DUWS_T_squadletsdothis", _place]] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_squadoverlord"] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_squadcopy"] remoteExec ["fnc_duws_dialogue", 0];

// Win = cordon broken with the squad still alive. Deadline (cordon not cleared in time) or the squad
// wiped after it came out both fail.
waitUntil {
    sleep 2;
    ((_cordonUnits findIf {alive _x}) < 0)
    || {[_deadline] call fnc_time_expired}
    || {(_squadUnits findIf {alive _x}) < 0}
};

if (((_cordonUnits findIf {alive _x}) >= 0) || {(_squadUnits findIf {alive _x}) < 0}) exitWith {
    DUWS_rsq_relieved = true;
    [_mission_name, _taskId, "FAILED", _BuildingPos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_squadfail"], false, _compKey, false, false] call fnc_mission_finish;
};

DUWS_rsq_relieved = true;
[_squadUnits, _Building, _marker, _taskId, _BuildingPos, _radius, _compKey, _mission_name] call fnc_rescue_squad_success;
