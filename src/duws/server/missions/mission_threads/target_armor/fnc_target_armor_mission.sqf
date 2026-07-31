// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
if (!([7, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};


_radius = 200;
_cpreward = 15;
_apreward = 15;
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_armorletsdothis";
_message1 = ([localize "STR_DUWS_T_armorend"] call fnc_cs);

_markerText2 = localize "STR_DUWS_T_c7";

private _site = [_MissionPos, _radius, 7] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];

_vehpos = [_targetpos, 10, 30,10,0,0.15,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;

_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;

[_targetpos, _radius] spawn fnc_missionPatrolswithintel;

// Damaged Tank
// The objective itself: kept for the mission's duration so the abandoned-vehicle clause
// cannot collect it. A player who disables it and takes half an hour would otherwise find
// the thing they were sent for gone, with no way left to finish.
_vehicle_1 = opfor_MBT_TANK1_X createVehicle (_vehpos);
[_vehicle_1, "mission_target_armor"] call fnc_duws_keep;
_vehicle_1 setDamage 0.8;

_obj1 = createVehicle ["CamoNet_OPFOR_open_F", _targetpos, [], 0, "CAN_COLLIDE"];
[_obj1, "mission_target_armor"] call fnc_duws_keep;
_obj2 = createVehicle ["Land_WoodenTable_large_F", [(_targetpos select 0)+1, (_targetpos select 1)+1], [], 0, "CAN_COLLIDE"];
[_obj2, "mission_target_armor"] call fnc_duws_keep;

[_targetpos, _radius] call fnc_garrisonBuildings;

// Commander group
_group = [_targetpos, EAST, [opfor_OFFICER_X, opfor_CREW_X, opfor_OPERATOR_X, opfor_ENG_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
_target = units _group select 0;

// No hat for OPTRE, HL2 or TIOW
if !(("OPTRE" in BLUFOR_FactionFile_X)
    or ("HL2ECR" in BLUFOR_FactionFile_X)
    or ("TIOW" in BLUFOR_FactionFile_X)) then {
    removeheadgear _target;
    _target addHeadgear "H_HelmetCrew_I";
};

if (hardcore_mode_enable) then {
    [[_target], "objective"] call fnc_search_flag_group;
};

_wp = _group addWaypoint [_vehpos, 0];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointTimeout [30, 45, 60];

_wp = _group addWaypoint [_targetpos, 0];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointTimeout [30, 45, 60];

_wp2 = _group addWaypoint [[(_targetpos select 0)+10, (_targetpos select 1)+10], 0];
_wp2 setWaypointType "CYCLE";
_wp2 setWaypointBehaviour "SAFE";
_wp2 setWaypointTimeout [30, 45, 60];

// ========== 添加死亡情报动作 ==========
{
    if (!isNull _x) then {
        [_x, "mission"] call fnc_search_flag_group;
    };
} forEach [_group];
// ====================================
// 为坦克指挥官添加机密情报
[_target] spawn {
    params ["_unit"];
    sleep 5;
    _unit addMagazineGlobal "FileTopSecret";
};
{
    [_x] call fnc_addRandomLoot;
} forEach units _group;
// TASK AND NOTIFICATION
private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["targetarmor%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_VARtaskgeneratedName, localize "STR_DUWS_T_y7z1cx6j", _mission_name, _randomPos, "destroy"] call fnc_missionTaskCreate;

// 设置任务目标位置（军官位置）
["info", [localize "STR_DUWS_T_SEARCH_CORPSE", localize "STR_DUWS_T_sidemissionloc"]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];

sleep 5; // 等待巡逻队生成完毕


// MISSION COMPLETED ?
waitUntil {sleep 2; !alive _target};

[_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
deleteMarker str(_markername2);

[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;

sleep 1;

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;

[_targetpos,_radius, "mission_target_armor"] call fnc_mission_end;
