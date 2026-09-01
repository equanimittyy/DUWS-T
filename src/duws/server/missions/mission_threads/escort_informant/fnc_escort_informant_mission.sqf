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
private _spawnPos = [[_hqPos select 0, _hqPos select 1], 10, 120, 8, 0, 0.4, 0, [], []] call BIS_fnc_findSafePos;
if (_spawnPos isEqualTo [] || { (_spawnPos select 0) == 0 && { (_spawnPos select 1) == 0 } }) then { _spawnPos = _hqPos };

private _civClasses = ["C_man_1", "C_man_polo_1_F", "C_man_polo_2_F", "C_man_polo_4_F", "C_man_p_fugitive_F", "C_man_hunter_1_F", "C_Man_casual_1_F", "C_Man_casual_4_F"];
private _grp = [_spawnPos, WEST, [selectRandom _civClasses]] call BIS_fnc_spawnGroup;
private _inf = leader _grp;
_grp deleteGroupWhenEmpty true;
[_grp] call fnc_mission_claim;
_inf setCaptive false;
_inf allowDamage true;
_inf setBehaviour "CARELESS";
_inf disableAI "MOVE";     // holds at HQ until recruited
_inf disableAI "PATH";
// Off the ACE/AIS revive path, so death is death, not an unconscious state the win poll never sees end.
_inf setVariable ["AIS_noReviveInit", true, true];

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

private _hqMarker = format ["escortinf_hq_%1", DUWS_mission_token];
createMarker [_hqMarker, _spawnPos];
_hqMarker setMarkerShape "ICON";
_hqMarker setMarkerType "hd_pickup";
_hqMarker setMarkerColor "ColorBlue";
_hqMarker setMarkerText "Informant";
[_hqMarker] spawn { params ["_m"]; sleep 120; deleteMarker _m };

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

private _cleanup = { deleteMarker _hqMarker; if (!isNull _inf) then { deleteVehicle _inf } };

if (alive _inf && _inf distance2D _townPos < _deliverDist) exitWith {
    [_townIdx, DUWS_curReward select 2, "escort_informant_success"] call fnc_town_rep_adjust;
    call _cleanup;
    [_mission_name, _taskId, "SUCCEEDED", _townPos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_escortinformant_close"], true] call fnc_mission_finish;
};

[_townIdx, -(DUWS_curReward select 2), "escort_informant_fail"] call fnc_town_rep_adjust;
call _cleanup;
[_mission_name, _taskId, "FAILED", _townPos, _radius, [_marker]] call fnc_mission_finish;
