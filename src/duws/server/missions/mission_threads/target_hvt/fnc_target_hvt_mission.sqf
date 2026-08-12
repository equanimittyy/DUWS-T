// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
if (!([2, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

_radius = 600;
_cpreward = DUWS_curReward select 0;
_apreward = DUWS_curReward select 1;
_deadline = DUWS_curDeadlineAt;
_speaker = localize "STR_DUWS_T_OVERLORD";
_speaker1 = localize "STR_DUWS_T_Viper";
_message = localize "STR_DUWS_T_hvtletsdothis";
_message0 = localize "STR_DUWS_T_hvtseen";
_message1 = ([localize "STR_DUWS_T_hvtend"] call fnc_cs);

_markerText2 = localize "STR_DUWS_T_c2";

private _site = [_MissionPos, _radius, 2] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// Marked before anything is built. The ellipse and the task are the only things telling the
// player where the objective is, and the spawn-up below runs for tens of seconds.
_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;
private _VARtaskgeneratedName = format ["rescue%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[_VARtaskgeneratedName, localize "STR_DUWS_T_19ajhe1d", _mission_name, _randomPos, "kill"] call fnc_missionTaskCreate;

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn",  [0,-2] select isDedicated];

_vehpos = [_targetpos, 10, 30,10,0,0.1,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;


sleep 1;
[_targetpos, _radius] spawn fnc_missionPatrolswithintel;

// Create Statics
// The objective itself: kept for the mission's duration so the abandoned-vehicle clause
// cannot collect it. A player who disables it and takes half an hour would otherwise find
// the thing they were sent for gone, with no way left to finish.
_apc = opfor_APC1_X createVehicle (_vehpos);
[_apc, "mission_target_hvt"] call fnc_duws_keep;

_static1 = "";
_static2 = "";
_static3 = "";
switch (VERSION_X) do {
    case "MODERN": {
        _static1 = "VirtualReammoBox_camonet_F";
        _static2 = "CargoNet_01_barrels_F";
        _static3 = "CamoNet_INDP_open_F";
    };
};
_obj1 = createVehicle [_static1, [(_targetpos select 0)+1, (_targetpos select 1)+1], [], 0, "CAN_COLLIDE"];
[_obj1, "mission_target_hvt"] call fnc_duws_keep;
sleep 1;
_obj2 = createVehicle [_static2, [(_targetpos select 0)-2, (_targetpos select 1)-2], [], 0, "CAN_COLLIDE"];
[_obj2, "mission_target_hvt"] call fnc_duws_keep;
sleep 1;
_obj3 = createVehicle [_static3, _targetpos, [], 0, "CAN_COLLIDE"];
[_obj3, "mission_target_hvt"] call fnc_duws_keep;
sleep 1;

[[_targetpos, _radius] call fnc_garrisonBuildings] call fnc_mission_claim;
// TASK AND NOTIFICATION
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
 [_speaker1, _message0] remoteExec ["fnc_duws_dialogue", 0];

// CREATE THE HVT GROUP
_group = [_targetpos, EAST, [opfor_OFFICER_X, opfor_OPERATOR_X, opfor_MARK_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
[_group] call fnc_mission_claim;
_target = units _group select 0;

[_target] spawn {
    params ["_unit"];
    sleep 5;
    _unit addHeadgear "H_Beret_blk";
};
[_target] spawn {
    params ["_unit"];
    sleep 5;
    _unit addMagazineGlobal "FileTopSecret";
};
_wp = _group addWaypoint [_vehpos, 0];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointTimeout [30, 45, 60];

_wp = _group addWaypoint [_targetpos, 0];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointTimeout [30, 45, 60];

// _Building may be an array when no building was found; skip the waypoint then.
if (_Building isEqualType objNull) then {
    _posBuilding = getpos _Building;
    _wp = _group addWaypoint [_posBuilding, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointBehaviour "SAFE";
    _wp setWaypointTimeout [30, 45, 60];
} else {
    ["WARN", "MISSION", "_Building is not an object, skipping waypoint."] call fnc_log;
};

_wp2 = _group addWaypoint [[(_targetpos select 0)+10, (_targetpos select 1)+10], 0];
_wp2 setWaypointType "CYCLE";
_wp2 setWaypointBehaviour "SAFE";
_wp2 setWaypointTimeout [30, 45, 60];

{
    if (!isNull _x) then {
        [_x, "mission"] call fnc_search_flag_group;
    };
} forEach [_group];

{
    [_x] call fnc_addRandomLoot;
} forEach units _group;


sleep 5; // let the patrols finish spawning


waitUntil {sleep 0.5; !alive _target || time > _deadline};

if (alive _target && time > _deadline) exitWith {
    [{hint localize "STR_DUWS_T_abc1abc2"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [_VARtaskgeneratedName, "FAILED"] call fnc_missionTaskEnd;
    [_markername2] call fnc_missionMarkerClear;
    [_targetpos,_radius, "mission_target_hvt"] call fnc_mission_end;
};

[_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
[_markername2] call fnc_missionMarkerClear;

[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;

sleep 1;

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;

// Mission over: releases the mission_target_hvt composition, so the APC and statics kept alive
// above are collected here too, along with the claimed groups.
[_targetpos,_radius, "mission_target_hvt"] call fnc_mission_end;
