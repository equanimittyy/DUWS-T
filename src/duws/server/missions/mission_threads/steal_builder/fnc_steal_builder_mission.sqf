// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];

// Ahead of fnc_mission_begin: a builder still standing means the last one was never
// collected, and refusing after the launcher would stamp a full hour of cooldown for a
// mission that never started.
if (!isNil "BLD1" && {alive BLD1}) exitWith {
    [{hint localize "STR_DUWS_T_mfxb090t"}] remoteExec ["BIS_fnc_Spawn", 0];
    ["INFO", "MISSION", "steal_builder refused: previous builder still alive"] call fnc_log;
};

if (!([6, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

_cpreward = 15;
_apreward = 15;


_radius = 500;

_markerText2 = localize "STR_DUWS_T_c6";

private _site = [_MissionPos, _radius, 6] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn", 0];

_vehpos = _targetpos;

_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;

// CREATE Mobile builder vehicle
// The objective itself: kept for the mission's duration so the abandoned-vehicle clause
// cannot collect it. A player who disables it and takes half an hour would otherwise find
// the thing they were sent for gone, with no way left to finish.
_bld1 = opfor_REPAIR_TRUCK_X createVehicle (_vehPos);
[_bld1, "mission_steal_builder"] call fnc_duws_keep;
_Varname = "BLD1";
_bld1 SetVehicleVarName _VarName;
_bld1 Call Compile Format ["%1=_This ; PublicVariable ""%1""",_VarName];

_static1 = "";
_static2 = "";
switch (VERSION_X) do {
    case "MODERN": {
        _static1 = "CargoNet_01_barrels_F";
        _static2 = "CamoNet_INDP_open_F";
    };
};

_obj1 = createVehicle [_static1, [(_vehpos select 0)-12, (_vehpos select 1)], [], 0, "CAN_COLLIDE"];
[_obj1, "mission_steal_builder"] call fnc_duws_keep;
sleep 1;
_obj2 = createVehicle [_static1, [(_vehpos select 0)-10, (_vehpos select 1)], [], 0, "CAN_COLLIDE"];
[_obj2, "mission_steal_builder"] call fnc_duws_keep;
sleep 1;
_obj3 = createVehicle [_static1, [(_vehpos select 0)-8, (_vehpos select 1)], [], 0, "CAN_COLLIDE"];
[_obj3, "mission_steal_builder"] call fnc_duws_keep;
sleep 1;
_obj4 = createVehicle [_static2, [(_vehpos select 0)-10, (_vehpos select 1)], [], 0, "CAN_COLLIDE"];
[_obj4, "mission_steal_builder"] call fnc_duws_keep;
sleep 1;

// Vehicle Guards
_group = [_vehPos, EAST, [opfor_SL_SOLDIER_X, opfor_LAT_SOLDIER_X, opfor_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
{
    [_x] call fnc_addRandomLoot;
} forEach units _group;
[_targetpos, _radius] call fnc_garrisonBuildings;

{
    if (!isNull _x) then {
        [_x, "mission"] call fnc_search_flag_group;
    };
} forEach [_group];
sleep 1;
[_targetpos, _radius] spawn fnc_missionPatrolswithintel;

private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["rescue%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];

[_VARtaskgeneratedName, localize "STR_DUWS_T_czpvn5z1", _mission_name, _randomPos, "getin"] call fnc_missionTaskCreate;

// 设置任务目标位置
["info", [localize "STR_DUWS_T_SEARCH_CORPSE", localize "STR_DUWS_T_sidemissionloc"]] remoteExec ["BIS_fnc_showNotification", 0];

sleep 5; // 等待巡逻队生成完毕


waitUntil {sleep 2; ((getdammage BLD1)>0.95 || (BLD1 distance PosOfBLUHQ)<50)};

deleteMarker str(_markername2);

if (getdammage BLD1>0.95) exitWith {
    [{hint localize "STR_DUWS_T_obc4591x"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [_VARtaskgeneratedName, "FAILED"] call fnc_missionTaskEnd;
    [_targetpos,_radius, "mission_steal_builder"] call fnc_mission_end;
};

[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;
[[{hint localize "STR_DUWS_T_125f39s4"}],"BIS_fnc_Spawn",true] call BIS_fnc_MP;
sleep 2;

_init_code = {
    waitUntil {!isNil "BLD1"};
    [BLD1, -1, west, "LIGHT"] execVM "modules\R3F_LOG\USER_FUNCT\init_creation_factory.sqf";
    [BLD1, "mil_triangle", "ColorBlue", "2", "2", "BLD-1"] call kndr_assignMarker;
};
[[[], _init_code], "BIS_fnc_spawn", true, true] spawn BIS_fnc_MP;

sleep 5;
[{hint localize "STR_DUWS_T_rw65exr8"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;

[_targetpos,_radius, "mission_steal_builder"] call fnc_mission_end;
