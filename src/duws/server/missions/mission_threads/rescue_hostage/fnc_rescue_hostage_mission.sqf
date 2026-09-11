// Locality: server; the recruit-action bodies remoteExec fnc_escort_informant_group to target 2.
//
// Covert rescue: reach the captive unseen and kill his building garrison. Being seen raises suspicion you can
// still slip away from; a confirmed sighting arms an execution clock that cannot be called off -- only killing
// the garrison first saves him. Killing it frees him and brings the cordon in. Win: captive at HQ.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;
if (!([24, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

_radius = 350;
private _deadline = DUWS_curDeadlineAt;

// Same test the finder used (fnc_usableBuildings), so the cluster is one the offer vetted; abort if it evaporated.
private _usable = [_MissionPos, 3, _radius] call fnc_usableBuildings;
if (_usable isEqualTo []) exitWith { [24, _requester, "no_building"] call fnc_mission_abort };
private _hostageBldg = selectRandom _usable;

// Closest town to the objective takes the REP reward on a win, single-sourced from the reward table.
// duws_town_circles is index-aligned with civ_locations, so its index is the one fnc_town_rep_adjust takes.
private _circles = missionNamespace getVariable ["duws_town_circles", []];
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

// Foot-only patrol ring: no vehicles, so the fight stays a light-infantry stealth problem.
private _tokens = [];
for "_i" from 1 to (floor random 2)     do { _tokens pushBack "closepatrol:team" };
for "_i" from 1 to (2 + floor random 5) do { _tokens pushBack "widepatrol:patrol" };
private _ring = [];
{
    private _grp = [_x, _MissionPos, _radius] call DUWS_fnc_zoneSpawnOne;
    if (!isNull _grp) then { _ring pushBack _grp };
} forEach _tokens;
[_ring] call fnc_mission_claim;

// Search circle points at the cluster, not the building; the hostage track marker appears only once he is
// freed (below), so his hiding place is never given away.
private _markername = [_MissionPos, _radius, _VARtaskgeneratedName, localize "STR_DUWS_T_RESCUE_HOSTAGE_DESC", _mission_name, "help",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_rescuehostage_brief", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_rescuehostage_copy", 0]]
] call fnc_mission_present;

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

// Shared marker name so the watcher (creates on free) and the finish branches (delete) agree without
// threading a handle; deleteMarker no-ops on an absent one, so an un-freed teardown stays correct.
private _trk = format ["rescuehostage_trk_%1", missionNamespace getVariable ["DUWS_mission_token", 0]];
private _clearIcons = { deleteMarker _trk; DUWS_float_hostage = objNull; publicVariable "DUWS_float_hostage"; };

// Guard watcher: a two-stage alarm. The whole cordon spots you -- a garrison OR patrol sighting raises the one
// global alarm -- but detection reads each observer's OWN knowsAbout plus a line-of-sight check within range,
// never side-wide east knowsAbout, which reads flat-high off any distant firefight (arma_engine_gotchas.md).
// Suspicion is escapable and its reset keys on LINE OF SIGHT (knowsAbout lingers for minutes after contact is
// lost); a confirmed sighting arms the clock for good, and killing the garrison is what frees the hostage.
[_hostage, _garrison, _ring, _hostageBldg, _trk] spawn {
    params ["_hostage", "_garrison", "_ring", "_bldg", "_trk"];
    #define CONFIRM   1.5     // knowsAbout for a confirmed ID (engine scale: 0 unknown .. 4 identified)
    #define SUS_KNOWS 0.3
    #define LOS_RANGE 150
    #define GRACE_SUS 8
    #define CLOCK_BASE 60     // armed once and never called off
    #define GRACE_KILL 1      // seconds after a cordon death the alarm can't arm, for chained takedowns

    // Bring the cordon in to hunt the building. Reused when the hostage is freed.
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

    private _hintTgt = [0, -2] select isDedicated;
    private _state = "CALM";
    private _alarmAt = -1;               // in-game time the execution clock expires; -1 = disarmed
    private _lastSeen = -1e9;            // last time any player was in a guard's sight
    private _seenPrev = [];              // players seen last tick, so "spotted" fires once per player
    private _lastKill = -1e9;            // time of the last cordon death; opens the takedown grace
    private _prevObsAlive = -1;          // cordon alive count last tick; a drop stamps _lastKill
    // Called by call, so it reads and writes the loop's own _alarmAt / _state.
    private _arm = {
        _alarmAt = time + CLOCK_BASE;
        _state = "ALARM";
        call _convergeRing;
    };

    while { alive _hostage } do {
        // Garrison dead -> freed. Checked first so a wipe mid-countdown cancels the clock.
        if ({ alive _x } count units _garrison == 0) exitWith {
            _hostage setCaptive false;
            _hostage setVariable ["DUWS_hostage_freed", true, true];
            call _convergeRing;
            [localize "STR_DUWS_T_OVERLORD", [localize "STR_DUWS_T_rescuehostage_freed"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
            DUWS_float_hostage = _hostage; publicVariable "DUWS_float_hostage";
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
        };

        // Clock expired with a guard alive: setCaptive false + reveal + RED so the co-located guards engage at
        // once; the setDamage backstop covers a stuck-AI edge (scripted damage bypasses his clamp).
        if (_state == "ALARM" && { time > _alarmAt }) exitWith {
            _hostage setCaptive false;
            { _x reveal [_hostage, 4] } forEach units _garrison;
            _garrison setCombatMode "RED";
            [_hostage] spawn { params ["_h"]; sleep 5; if (alive _h) then { _h setDamage 1 }; };
        };

        // Observers: the whole cordon spots you -- garrison and patrols alike raise the one global alarm. Each
        // reads its OWN knowsAbout (graded suspicion vs confirmed) plus a line-of-sight check within range.
        private _players = allPlayers select { side _x == west && { alive _x } };
        private _obs = units _garrison select { alive _x };
        { _obs append (units _x select { alive _x }) } forEach _ring;
        // A cordon death opens a brief grace where the alarm can't arm, so a coordinated team can drop the
        // spotters in one burst before a survivor radios it in.
        private _obsAlive = count _obs;
        if (_obsAlive < _prevObsAlive) then { _lastKill = time };
        _prevObsAlive = _obsAlive;
        private _seenNow = [];
        private _confirmed = false;
        {
            private _pl = _x;
            private _losP = false;
            private _knowsP = 0;
            {
                private _u = _x;
                private _k = _u knowsAbout _pl;
                if (_k > _knowsP) then { _knowsP = _k };
                if (!_losP && { _u distance _pl < LOS_RANGE } && { (lineIntersectsSurfaces [eyePos _u, eyePos _pl, _u, _pl]) isEqualTo [] }) then { _losP = true };
            } forEach _obs;
            if (_losP && { _knowsP > SUS_KNOWS }) then { _seenNow pushBack _pl };
            if (_losP && { _knowsP > CONFIRM }) then { _confirmed = true };
        } forEach _players;
        if (count _seenNow > 0) then { _lastSeen = time };

        if (_state == "ALARM") then {
            // Committed. Countdown broadcast until freed (garrison dead) or executed (clock expired).
            [format [localize "STR_DUWS_T_rescuehostage_detected", ceil (_alarmAt - time)]] remoteExec ["hint", _hintTgt];
        } else {
            if (_confirmed && { time - _lastKill > GRACE_KILL }) then { call _arm } else {
                if (count _seenNow > 0) then {
                    _state = "SUS";
                    // Warn only the players newly in a guard's sight, each on his own machine.
                    {
                        private _owner = owner _x;
                        [localize "STR_DUWS_T_rescuehostage_spotted"] remoteExec ["hint", _owner];
                    } forEach (_seenNow select { !(_x in _seenPrev) });
                } else {
                    if (_state == "SUS" && { time - _lastSeen > GRACE_SUS }) then { _state = "CALM" };
                };
            };
        };
        _seenPrev = _seenNow;

        sleep 1;
    };
};

// Main poll: only the hostage at HQ alive (win), his death (executed or crossfire), or the deadline ends it now.
waitUntil {
    sleep 1;
    (!alive _hostage) || { (_hostage distance PosOfBLUHQ) < 20 } || { time > _deadline }
};

if (!alive _hostage) exitWith {
    call _clearIcons;
    [_mission_name, _VARtaskgeneratedName, "FAILED", _MissionPos, _radius, [_markername], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_rescuehostage_lost"], false, "", false, false] call fnc_mission_finish;
};
if (time > _deadline) exitWith {
    call _clearIcons;
    if (alive _hostage) then { deleteVehicle _hostage };   // unclaimed, so the token sweep never takes him
    // _line empty + _notify true: speak the shared "out of time" call, since a missed deadline is exactly that.
    [_mission_name, _VARtaskgeneratedName, "FAILED", _MissionPos, _radius, [_markername], [], false, "", false, true] call fnc_mission_finish;
};

// Win: peel the hostage out of the player's group and despawn him after a spell, so a rescued NPC doesn't
// ride the roster for the rest of the campaign.
call _clearIcons;
if (_townIdx >= 0) then { [_townIdx, DUWS_curReward select 2, "rescue_hostage_success"] call fnc_town_rep_adjust };
[_hostage] spawn {
    params ["_h"];
    [_h] joinSilent (createGroup [WEST, true]);
    _h setUnitPos "AUTO";
    sleep 300;
    if (!isNull _h) then { deleteVehicle _h };
};
[_mission_name, _VARtaskgeneratedName, "SUCCEEDED", _MissionPos, _radius, [_markername], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_rescuehostage_home"], true, "", false, false] call fnc_mission_finish;
