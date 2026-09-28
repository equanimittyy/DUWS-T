// Locality: server; the recruit-action bodies remoteExec fnc_escort_informant_group to target 2.
//
// Covert rescue: reach the captive unseen and kill his building garrison. A sighting held a few seconds arms an
// execution clock that cannot be called off -- only killing the garrison first saves him. Killing it frees him and
// brings the cordon in. Win: captive at HQ.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;
if (!([24, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

_radius = 350;
private _deadline = DUWS_curDeadlineAt;

// Re-derive the vetted building, re-applying the finder's covert filters (fnc_site_cluster, allow-neutral +
// 300 m zone standoff): a seat-count-only re-pick could seat the hostage in a side-held town or a zone the
// offer was built to keep him clear of. Abort if the cluster evaporated.
private _zones = missionNamespace getVariable ["zone_meta_array", []];
private _circles = missionNamespace getVariable ["duws_town_circles", []];
private _held = (missionNamespace getVariable ["DUWS_enemy_town_pos", []]) + (missionNamespace getVariable ["DUWS_blufor_town_pos", []]);
private _usable = ([_MissionPos, 3, _radius] call fnc_usableBuildings) select {
    private _bp = getPos _x;
    ((_circles findIf { _x params ["_tc", "_r"]; (_bp distance2D _tc < _r) && {(_held findIf { _x distance2D _tc < 5 }) >= 0} }) < 0)
    && {(_zones findIf { _x params ["", "_zp", "_zs"]; (_bp distance2D _zp) < (_zs + 300) }) < 0}
};
if (_usable isEqualTo []) exitWith { [24, _requester, "no_building"] call fnc_mission_abort };
private _hostageBldg = selectRandom _usable;

// Closest town to the objective takes the REP reward on a win, single-sourced from the reward table.
// duws_town_circles is index-aligned with civ_locations, so its index is the one fnc_town_rep_adjust takes.
private _townIdx = -1;
private _bestD = 1e9;
{
    _x params ["_c", ""];
    private _d = _c distance2D _MissionPos;
    if (_d < _bestD) then { _bestD = _d; _townIdx = _forEachIndex };
} forEach _circles;

private _VARtaskgeneratedName = format ["hostage%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;
sleep 1;

// Hostage on the Escort Informant rig (walks once freed, never carried): captive so the guards hold fire,
// MOVE disabled -- not PATH -- so he waits in the building yet can still path out once recruited.
private _civClasses = ["C_man_1", "C_man_polo_1_F", "C_man_polo_2_F", "C_man_polo_4_F", "C_man_p_fugitive_F", "C_man_hunter_1_F", "C_Man_casual_1_F", "C_Man_casual_4_F"];
private _slots = [_hostageBldg] call BIS_fnc_buildingPositions;
private _hpos = if (_slots isEqualTo []) then { getPosATL _hostageBldg } else { selectRandom _slots };
private _hgrp = [_hpos, WEST, [selectRandom _civClasses]] call BIS_fnc_spawnGroup;
private _hostage = leader _hgrp;
_hgrp deleteGroupWhenEmpty true;
_hostage setPosATL _hpos;
_hostage setDir (random 360);
_hostage setCaptive true;
_hostage setBehaviour "CARELESS";
_hostage setUnitPos "MIDDLE";
_hostage disableAI "MOVE";
// Death is death, not an unconscious state the win poll never sees end.
_hostage setVariable ["AIS_noReviveInit", true, true];
// Halve every hit so a stray round can't instakill him mid-firefight; scripted setDamage (the execution
// backstop) skips HandleDamage, so that still lands (per rescue_pilot).
_hostage addEventHandler ["HandleDamage", {
    params ["_u", "", "_dmg", "", "", "_hi"];
    private _old = if (_hi < 0) then { damage _u } else { _u getHitIndex _hi };
    _old + ((_dmg - _old) * 0.5)
}];

// Garrison hand-spread into the hostage building, not via the garrison posture (which could seat them in a
// bigger neighbour). DUWS_garrisonedBy stops an overlapping town garrison double-occupying the house.
private _garrison = ["garrison:team", getPosATL _hostageBldg, 30, "none", getPosATL _hostageBldg] call DUWS_fnc_zoneSpawnOne;
if (isNull _garrison) exitWith {
    deleteVehicle _hostage;
    [24, _requester, "no_garrison"] call fnc_mission_abort;
};
_hostageBldg setVariable ["DUWS_garrisonedBy", _garrison];
[_garrison, [_hostageBldg], count units _garrison, "AUTO"] call fnc_spreadIntoBuildings;
[_garrison] call fnc_mission_claim;
sleep 1;

// Foot-only patrol ring: no vehicles, so the fight stays a light-infantry stealth problem. Centred on the
// hostage rather than _MissionPos, since the building can sit anywhere in the search circle.
private _tokens = [];
for "_i" from 1 to (floor random 2)     do { _tokens pushBack "closepatrol:team" };
for "_i" from 1 to (2 + floor random 5) do { _tokens pushBack "widepatrol:patrol" };
for "_i" from 1 to (floor random 2)     do { _tokens pushBack "widepatrol:recon" };
private _ring = [];
{
    private _grp = [_x, _hpos, _radius] call DUWS_fnc_zoneSpawnOne;
    if (!isNull _grp) then { _ring pushBack _grp };
} forEach _tokens;
[_ring] call fnc_mission_claim;

// Night-blind everyone but the recon squad, so a night approach is a stealth problem against recon and a
// blackout gamble against the rest. srcToken (set in DUWS_fnc_zoneSpawnOne) marks the exempt groups.
private _blind = +(units _garrison);
{ if (((_x getVariable ["DUWS_srcToken", ""]) find "recon") < 0) then { _blind append units _x }; } forEach _ring;
{
    private _nvg = hmd _x;
    if (_nvg != "") then { _x unlinkItem _nvg };
    private _ptr = (primaryWeaponItems _x) param [1, ""];
    if (_ptr != "") then { _x removePrimaryWeaponItem _ptr };
    _x addPrimaryWeaponItem "acc_flashlight";
} forEach _blind;

private _trk = format ["rescuehostage_trk_%1", missionNamespace getVariable ["DUWS_mission_token", 0]];
createMarker [_trk, getPosATL _hostage];
_trk setMarkerShape "ICON";
_trk setMarkerType "mil_warning";
_trk setMarkerColor "ColorBlue";
_trk setMarkerText "Hostage";
[_hostage, _trk] spawn {
    params ["_hostage", "_mk"];
    while { !isNull _hostage && { alive _hostage } && { markerType _mk != "" } } do {
        _mk setMarkerPos (getPosATL _hostage);
        sleep 5;
    };
};

private _markername = [_MissionPos, _radius, _VARtaskgeneratedName, localize "STR_DUWS_T_RESCUE_HOSTAGE_DESC", _mission_name, "help",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_rescuehostage_brief", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_rescuehostage_copy", 0]]
] call fnc_mission_present;

// Additive to the cordon's own detection: this slows how fast the guards acquire a careful approach, it
// does not gate the alarm.
DUWS_stealth_active = true;
publicVariable "DUWS_stealth_active";
[_MissionPos, _radius + 300] remoteExec ["fnc_stealth_layer", 0, "DUWS_stealth_layer_jip"];

// Recruit gated on DUWS_hostage_freed (stamped when the garrison dies), so it can't be used through a wall
// while the guards are up. Leader check sits in the body, not the condition, so a non-leader is told why it
// did nothing. Reuses the Escort Informant handler -- it carries no informant-only side effects.
private _joinCond = "_target getVariable ['DUWS_hostage_freed', false] && {_this distance _target < 6} && {!(_target in units group _this)}";
private _leaveCond = "_target getVariable ['DUWS_hostage_freed', false] && {_this distance _target < 6} && {_target in units group _this}";
[_hostage, [localize "STR_DUWS_T_escortinformant_join",
    {
        params ["_target", "_caller"];
        if (_caller != leader group _caller) exitWith { hint localize "STR_DUWS_T_escortinformant_notleader" };
        [_target, _caller, true] remoteExec ["fnc_escort_informant_group", 2];
    },
    [], 1.5, false, false, "", _joinCond]
] remoteExec ["addAction", [0, -2] select isDedicated, _hostage];
[_hostage, [localize "STR_DUWS_T_escortinformant_leave",
    {
        params ["_target", "_caller"];
        if (_caller != leader group _caller) exitWith { hint localize "STR_DUWS_T_escortinformant_notleader" };
        [_target, _caller, false] remoteExec ["fnc_escort_informant_group", 2];
    },
    [], 1.5, false, false, "", _leaveCond]
] remoteExec ["addAction", [0, -2] select isDedicated, _hostage];

private _clearIcons = {
    deleteMarker _trk;
    DUWS_float_hostage = objNull; publicVariable "DUWS_float_hostage";
    DUWS_stealth_active = false; publicVariable "DUWS_stealth_active";
    remoteExec ["", "DUWS_stealth_layer_jip"];
};

// Guard watcher: one alarm threshold. The whole cordon spots you -- a garrison OR patrol sighting raises the one
// global alarm. "Sensing now" is the engine's own nearTargets fix (age ~0 while watched), NOT knowsAbout, which
// is a decaying, side-wide memory scalar: it reads flat-high off any distant firefight and can't tell a watched
// mover from a guard who merely remembers you, and an ad-hoc lineIntersectsSurfaces ray is no substitute
// (arma_engine_gotchas.md). knowsAbout still grades a live sighting, but only for a guard
// with a current fix -- so breaking contact drains it. A sighting that holds arms the clock for good, and killing
// the garrison is what frees the hostage.
[_hostage, _garrison, _ring, _hostageBldg, _VARtaskgeneratedName] spawn {
    params ["_hostage", "_garrison", "_ring", "_bldg", "_taskId"];
    #define CONFIRM   1.5     // knowsAbout for a confirmed ID (engine scale: 0 unknown .. 4 identified)
    #define DET_RANGE 300     // nearTargets query radius: how far a cordon guard's live fix on the player counts
    #define DET_FRESH 5       // engine re-fixes a target's nearTargets age every few seconds, so a tighter gate drops a watched player between refreshes; matches OPCOM_TICK_PERIOD (arma_engine_gotchas.md)
    #define CLOCK_BASE 180    // armed once and never called off
    #define CONFIRM_HOLD 3    // seconds a sighting must hold unbroken before arming -- short, so the guard's knowsAbout cannot drain out from under the hold

    // Held off the alarm and fired only on the freed branch: the execution clock is a race to wipe the
    // garrison, and pulling the outer ring onto the house mid-countdown swamped that fight before the player
    // could win it.
    private _convergeRing = {
        {
            private _p = _x;
            if (!isNull _p && { { alive _x } count units _p > 0 }) then {
                while { count waypoints _p > 0 } do { deleteWaypoint [_p, 0]; };
                _p setBehaviour "AWARE";
                _p setCombatMode "RED";
                _p setSpeedMode "FULL";
                private _wp = _p addWaypoint [getPosATL _bldg, 0];
                _wp setWaypointType "SAD";
                _wp setWaypointSpeed "FULL";
                (_p addWaypoint [getPosATL _bldg, 30]) setWaypointType "CYCLE";
            };
        } forEach _ring;
    };

    // The approach ends the moment the cordon reacts or the captive is loose, so the coef is handed back
    // rather than riding units through the firefight. Idempotent: the thread's teardown calls it again.
    private _endStealth = {
        DUWS_stealth_active = false;
        publicVariable "DUWS_stealth_active";
        remoteExec ["", "DUWS_stealth_layer_jip"];
    };

    private _hintTgt = [0, -2] select isDedicated;
    private _alarmAt = -1;               // in-game time the execution clock expires; -1 = disarmed
    private _confirmSince = -1;          // time the current unbroken sighting began; -1 = no contact

    while { alive _hostage } do {
        // Garrison dead -> freed. Checked first so a wipe mid-countdown cancels the clock.
        if ({ alive _x } count units _garrison == 0) exitWith {
            _hostage setCaptive false;
            _hostage setVariable ["DUWS_hostage_freed", true, true];
            call _convergeRing;
            call _endStealth;
            // Overwrites the execution countdown: this branch stops the loop, so its last "Ns" would otherwise hang frozen in the box.
            [localize "STR_DUWS_T_rescuehostage_captors"] remoteExec ["hint", _hintTgt];
            [localize "STR_DUWS_T_OVERLORD", [localize "STR_DUWS_T_rescuehostage_freed"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
            DUWS_float_hostage = _hostage; publicVariable "DUWS_float_hostage";
            // 2D: a below-surface Z sinks the task diamond (arma_engine_gotchas.md).
            [_taskId, PosOfBLUHQ select [0, 2]] call BIS_fnc_taskSetDestination;
        };

        // Clock expired: hand him to the cordon to be shot. Drop his damage clamp so rounds land full, then
        // walk the nearest guard onto him and fire -- the garrison roams the house, so the closest may be
        // rooms away. setDamage is a failsafe for a guard that can't path to him, timed to land after the walk.
        if (_alarmAt >= 0 && { time > _alarmAt }) exitWith {
            _hostage removeAllEventHandlers "HandleDamage";
            _hostage setCaptive false;
            private _guards = units _garrison select { alive _x };
            { _x reveal [_hostage, 4] } forEach _guards;
            _garrison setBehaviour "COMBAT";
            _garrison setCombatMode "RED";
            private _shooter = objNull;
            { if (isNull _shooter || { _x distance _hostage < _shooter distance _hostage }) then { _shooter = _x } } forEach _guards;
            if (!isNull _shooter) then {
                [_shooter, _hostage] spawn {
                    params ["_g", "_h"];
                    private _by = time + 12;
                    // Re-issue the move each tick so group formation can't pull him off it.
                    waitUntil { sleep 1; _g doMove getPosATL _h; !alive _h || !alive _g || _g distance _h < 4 || time > _by };
                    if (alive _h && { alive _g }) then { _g doTarget _h; _g doFire _h };
                };
            };
            [_hostage] spawn { params ["_h"]; sleep 20; if (alive _h) then { _h setDamage 1 }; };
        };

        // Observers: the whole cordon spots you -- garrison and patrols alike raise the one global alarm. Skipped
        // once armed, since nothing calls the alarm off.
        if (_alarmAt < 0) then {
            private _players = allPlayers select { side _x == west && { alive _x } };
            private _obs = units _garrison select { alive _x };
            { _obs append (units _x select { alive _x }) } forEach _ring;
            // A guard with a CURRENT nearTargets fix on a player: the engine's own live sighting decides who counts,
            // knowsAbout grades how sure they are. A guard who only remembers you (age > DET_FRESH) is excluded, so
            // the alarm drains when the cordon loses contact. One nearTargets query per guard serves every player.
            private _confirmed = (_obs findIf {
                private _u = _x;
                ((_u nearTargets DET_RANGE) findIf {
                    (_x select 5) <= DET_FRESH && { (_x select 4) in _players } && { (_u knowsAbout (_x select 4)) > CONFIRM }
                }) >= 0
            }) >= 0;

            if (_confirmed) then {
                if (_confirmSince < 0) then { _confirmSince = time };
            } else {
                _confirmSince = -1;
            };

            if (_confirmSince >= 0 && { time - _confirmSince >= CONFIRM_HOLD }) then {
                _alarmAt = time + CLOCK_BASE;
                call _endStealth;
            };
        };

        if (_alarmAt >= 0) then {
            // Committed. Countdown broadcast until freed (garrison dead) or executed (clock expired).
            [format [localize "STR_DUWS_T_rescuehostage_detected", ceil (_alarmAt - time)]] remoteExec ["hint", _hintTgt];
        };

        sleep 1;
    };
};

// Main poll: only the hostage at HQ alive (win), his death (executed or crossfire), or the deadline ends it now.
waitUntil {
    sleep 1;
    (!alive _hostage) || { (_hostage distance PosOfBLUHQ) < 20 } || { [_deadline] call fnc_time_expired }
};

if (!alive _hostage) exitWith {
    call _clearIcons;
    [_mission_name, _VARtaskgeneratedName, "FAILED", _MissionPos, _radius, [_markername], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_rescuehostage_lost"], false, "", false, false] call fnc_mission_finish;
};
if ([_deadline] call fnc_time_expired) exitWith {
    call _clearIcons;
    if (alive _hostage) then { deleteVehicle _hostage };   // unclaimed, so the token sweep never takes him
    // _line empty + _notify true: speak the shared "out of time" call, since a missed deadline is exactly that.
    [_mission_name, _VARtaskgeneratedName, "FAILED", _MissionPos, _radius, [_markername], [], false, "", false, true] call fnc_mission_finish;
};

// Win: peel him off the player's group so a rescued NPC never rides the roster. Leave Group turns MOVE off, so
// the walk turns it back on; the 300 s is only a blocked-path cap, not the despawn trigger.
call _clearIcons;
if (_townIdx >= 0) then { [_townIdx, DUWS_curReward select 2, "rescue_hostage_success"] call fnc_town_rep_adjust };
[_hostage] spawn {
    params ["_h"];
    [_h] joinSilent (createGroup [WEST, true]);
    if (vehicle _h != _h) then {
        moveOut _h;
        private _outBy = time + 1;
        waitUntil { vehicle _h == _h || time > _outBy };
    };
    _h enableAI "MOVE";
    _h setUnitPos "AUTO";
    private _tent = objectFromNetId (missionNamespace getVariable ["HQ_medTent_netId", ""]);
    if (!isNull _tent) then {
        _h doMove (getPosATL _tent);
        private _walkTimeout = time + 300;
        waitUntil { sleep 1; !(alive _h) || (_h distance _tent < 5) || time > _walkTimeout };
    };
    if (!isNull _h) then { deleteVehicle _h };
};
[_mission_name, _VARtaskgeneratedName, "SUCCEEDED", _MissionPos, _radius, [_markername], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_rescuehostage_home"], true, "", false, false] call fnc_mission_finish;
