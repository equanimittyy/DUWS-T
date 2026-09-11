// Locality: server -- callers remoteExec to target 2.
//
// Informant is a WEST unit in civilian dress: friendly to the player but a target OPFOR will engage, so
// the escort to the surveyed town is contested. He holds at HQ until a group leader recruits him; the
// outcome moves that town's rep by the row's REP figure.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;
if (!([20, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

private _radius = 50;
private _deliverDist = 50;
private _deadline = DUWS_curDeadlineAt;

// duws_town_circles is index-aligned with civ_locations, so a circle's index is the one
// fnc_town_rep_adjust takes.
private _enemyTowns = missionNamespace getVariable ["DUWS_enemy_town_pos", []];
private _circles = missionNamespace getVariable ["duws_town_circles", []];
private _townIdx = -1;
private _townPos = [];
private _bestD = 1e9;
{
    _x params ["_c", ""];
    if ((_enemyTowns findIf { _x distance2D _c < 5 }) < 0) then {
        private _d = _c distance2D _MissionPos;
        if (_d < _bestD) then { _bestD = _d; _townPos = _c; _townIdx = _forEachIndex };
    };
} forEach _circles;
if (_townIdx < 0) exitWith { [20, _requester, "no_delivery_town"] call fnc_mission_abort };

private _hqPos = if (!isNil "bluHQ_object" && { !isNull bluHQ_object }) then { getPosATL bluHQ_object } else { +PosOfBLUHQ };
private _spawnPos = [_hqPos, 120, 10, 8, 0.4] call fnc_mission_safepos;

private _civClasses = ["C_man_1", "C_man_polo_1_F", "C_man_polo_2_F", "C_man_polo_4_F", "C_man_p_fugitive_F", "C_man_hunter_1_F", "C_Man_casual_1_F", "C_Man_casual_4_F"];
private _grp = [_spawnPos, WEST, [selectRandom _civClasses]] call BIS_fnc_spawnGroup;
private _inf = leader _grp;
_grp deleteGroupWhenEmpty true;
_inf setCaptive false;
_inf allowDamage true;
_inf setBehaviour "CARELESS";
_inf disableAI "MOVE";     // holds at HQ until recruited; disable MOVE only, never PATH
// Off the ACE/AIS revive path, so death is death, not an unconscious state the win poll never sees end.
_inf setVariable ["AIS_noReviveInit", true, true];

// No local reader: a client drawer (client/missions/fnc_protect_civ_markers.sqf) consumes this global to
// mark him. Reusing protect_civ's global is safe because only one side mission runs at a time.
DUWS_float_informant = _inf; publicVariable "DUWS_float_informant";

// Manhunt-style track: a map marker on the informant whose position is refreshed on the UAV scan
// cadence (fnc_uav_scanner.sqf, _scanInterval) rather than per frame, so the feed reads like a drone
// ping. The loop ends on its own once _cleanup deletes the marker (markerType of a deleted one is "").
private _trackMarker = format ["escortinf_trk_%1", DUWS_mission_token];
createMarker [_trackMarker, getPosATL _inf];
_trackMarker setMarkerShape "ICON";
_trackMarker setMarkerType "mil_warning";
_trackMarker setMarkerColor "ColorBlue";
_trackMarker setMarkerText "Informant";
[_inf, _trackMarker] spawn {
    params ["_inf", "_mk"];
    while { !isNull _inf && { alive _inf } && { markerType _mk != "" } } do {
        _mk setMarkerPos (getPosATL _inf);
        sleep 5;
    };
};

// Leader gate is in the action body, not the condition: a non-leader still sees the action and gets told
// why it did nothing, instead of it silently vanishing.
[_inf, [localize "STR_DUWS_T_escortinformant_join",
    {
        params ["_target", "_caller"];
        if (_caller != leader group _caller) exitWith { hint localize "STR_DUWS_T_escortinformant_notleader" };
        [_target, _caller, true] remoteExec ["fnc_escort_informant_group", 2];
    },
    [], 1.5, false, false, "", "_this distance _target < 6 && !(_target in units group _this)"]
] remoteExec ["addAction", [0, -2] select isDedicated, _inf];

[_inf, [localize "STR_DUWS_T_escortinformant_leave",
    {
        params ["_target", "_caller"];
        if (_caller != leader group _caller) exitWith { hint localize "STR_DUWS_T_escortinformant_notleader" };
        [_target, _caller, false] remoteExec ["fnc_escort_informant_group", 2];
    },
    [], 1.5, false, false, "", "_this distance _target < 6 && (_target in units group _this)"]
] remoteExec ["addAction", [0, -2] select isDedicated, _inf];

[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;
sleep 2;

private _taskId = format ["escortinf%1%2", round (_townPos select 0), round (_townPos select 1)];
private _marker = [_townPos, _radius, _taskId, localize "STR_DUWS_T_ESCORT_INFORMANT_DESC", _mission_name, "move",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_escortinformant_brief", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_escortinformant_copy"]]
] call fnc_mission_present;

waitUntil {
    sleep 2;
    (!alive _inf) || (_inf distance2D _townPos < _deliverDist) || (time > _deadline)
};

// Common teardown; each outcome adds its own informant send-off below.
private _cleanup = {
    DUWS_float_informant = objNull; publicVariable "DUWS_float_informant";
    deleteMarker _trackMarker;
};

// Handed-friendly cleanup (like rescue_hostage): peel a live informant out of the player's group and
// despawn him after a grace. Never claimed -- a player-side unit must not ride the enemy-cleanup sweep --
// and the grace lets a recruited informant walk off rather than blink out of the squad mid-stride.
private _despawn = {
    params ["_u"];
    [_u] spawn {
        params ["_h"];
        [_h] joinSilent (createGroup [WEST, true]);
        _h setCaptive true;
        _h setUnitPos "AUTO";
        sleep 300;
        if (!isNull _h) then { deleteVehicle _h };
    };
};

// fnc_mission_finish localises its _msg as a stringtable key, so it cannot take a line already
// formatted with the town name (localize of a finished sentence just logs "String ... not found").
// The win branch speaks that line itself and hands finish [] instead.
private _place = [_townPos] call fnc_place_name;

if (alive _inf && _inf distance2D _townPos < _deliverDist) exitWith {
    [_townIdx, DUWS_curReward select 2, "escort_informant_success"] call fnc_town_rep_adjust;
    call _cleanup;
    // Delivered: hand him off gracefully -- peel from the player's group and despawn after a grace.
    [_inf] call _despawn;
    [localize "STR_DUWS_T_OVERLORD", [format [localize "STR_DUWS_T_escortinformant_close", _place]] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
    [_mission_name, _taskId, "SUCCEEDED", _townPos, _radius, [_marker], [], true] call fnc_mission_finish;
};

[_townIdx, -(DUWS_curReward select 2), "escort_informant_fail"] call fnc_town_rep_adjust;
call _cleanup;

if (alive _inf) exitWith {
    // Timed out but alive: same graceful hand-off despawn as the win path.
    [_inf] call _despawn;
    [_mission_name, _taskId, "FAILED", _townPos, _radius, [_marker]] call fnc_mission_finish;
};

// Informant dead: the corpse rides the general dead-body census (any body, claimed or not), nothing to do.
[_mission_name, _taskId, "FAILED", _townPos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_escortinformant_fail"]] call fnc_mission_finish;
