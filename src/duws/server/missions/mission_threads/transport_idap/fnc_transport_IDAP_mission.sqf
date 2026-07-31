// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
if (!([15, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};


_radius = 600;
_cpreward = 20;
_apreward = 0;
_speakerIDAP = localize "STR_DUWS_T_IDAP";
_speaker = localize "STR_DUWS_T_OVERLORD";
_speakeracteam  = localize "STR_DUWS_T_actionteam";
_message = localize "STR_DUWS_T_idapletsdothis";
_message1 = ([localize "STR_DUWS_T_idapcopy"] call fnc_cs);
_message2 = ([localize "STR_DUWS_T_idapacteamgo"] call fnc_cs);
_message3 = localize "STR_DUWS_T_idapend";
_markerText2 = localize "STR_DUWS_T_c15";

private _site = [_MissionPos, _radius, 15] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// Marked before anything is built. The ellipse and the task are the only things telling the
// player where the objective is, and the spawn-up below runs for tens of seconds.
_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;
private _VARtaskgeneratedName = format ["rescue%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[_VARtaskgeneratedName, localize "STR_DUWS_T_transIDAP", _mission_name, _randomPos, "truck"] call fnc_missionTaskCreate;

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn",  [0,-2] select isDedicated];

_vehPos = _targetpos;


// 生成卡车
_truck1 = "C_IDAP_Truck_02_Transport_F" createVehicle (_vehpos);
[_truck1, "mission_transport_idap"] call fnc_duws_keep;

// 生成补给箱
_box1 = "";
_box2 = "";
_static1 = "";
_static2 = "";
switch (VERSION_X) do {
    case "MODERN": {
        _box1 = "Land_FoodSacks_01_cargo_white_idap_F" createVehicle (_missionpos);
        _box2 = "Land_FoodSacks_01_cargo_white_idap_F" createVehicle (_missionpos);
        { [_x, "mission_transport_idap"] call fnc_duws_keep; } forEach [_box1, _box2];
        _box1 attachTo [_truck1,[0,-0.5,0]];
        _box1 setDir 90;
        _box2 attachTo [_truck1,[0,-2.2,0]];
        _box2 setDir 75;
        _static1 = "CargoNet_01_barrels_F";
        _static2 = "CamoNet_INDP_open_F";
    };
};

_obj1 = createVehicle [_static1, [(_vehpos select 0)-12, (_vehpos select 1)-10], [], 0, "CAN_COLLIDE"];
[_obj1, "mission_transport_idap"] call fnc_duws_keep;
sleep 1;
_obj2 = createVehicle [_static1, [(_vehpos select 0)-10, (_vehpos select 1)-10], [], 0, "CAN_COLLIDE"];
[_obj2, "mission_transport_idap"] call fnc_duws_keep;
sleep 1;
_obj3 = createVehicle [_static1, [(_vehpos select 0)-8, (_vehpos select 1)-10], [], 0, "CAN_COLLIDE"];
[_obj3, "mission_transport_idap"] call fnc_duws_keep;
sleep 1;
_obj4 = createVehicle [_static2, [(_vehpos select 0)-10, (_vehpos select 1)-10], [], 0, "CAN_COLLIDE"];
[_obj4, "mission_transport_idap"] call fnc_duws_keep;
sleep 1;

// Vehicle guards
_group = [_vehPos, EAST, [opfor_SL_SOLDIER_X, opfor_LAT_SOLDIER_X, opfor_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;

// CREATE PATROLS
sleep 1;
[_targetpos, _radius] spawn fnc_missionPatrolswithintel;

{
    if (!isNull _x) then {
        [_x, "mission"] call fnc_search_flag_group;
    };
} forEach [_group];
{
    [_x] call fnc_addRandomLoot;
} forEach units _group;
// 生成随机交付点
private _targetDeliveryPos = [];
private _deliveryMarkerName = format ["delivery_%1", floor random 10000];
private _minDist = 1000;
private _maxDist = 2000;
private _attempts = 0;
while {_attempts < 100 && _targetDeliveryPos isEqualTo []} do {
    _targetDeliveryPos = [_MissionPos, _minDist, _maxDist, 1, 0, 20, 0] call BIS_fnc_findSafePos;
    _attempts = _attempts + 1;
};
if (_targetDeliveryPos isEqualTo []) then {
    private _dir = random 360;
    private _dist = _minDist + random (_maxDist - _minDist);
    _targetDeliveryPos = [_MissionPos, _dist, _dir] call BIS_fnc_relPos;
};

// 创建交付点标记
_deliveryMarkerName = format ["civ_marker_%1", round(time + random 1000)];
createMarker [_deliveryMarkerName, _targetDeliveryPos];
_deliveryMarkerName setMarkerShape "ICON";
_deliveryMarkerName setMarkerType "o_unknown";
_deliveryMarkerName setMarkerColor "ColorGreen";
_deliveryMarkerName setMarkerText "IDAP";
_deliveryMarkerName setMarkerSize [1, 1];

// 定义清理函数
_cleanupDelivery = {
    if (!isNil "_deliverySmokeScript") then { terminate _deliverySmokeScript; };
    if (!isNil "_smokeObjects") then { { deleteVehicle _x } forEach _smokeObjects; };
    if (!isNil "_groupDelivery") then { { deleteVehicle _x } forEach units _groupDelivery; deleteGroup _groupDelivery; };
};

// 生成 5 名 IDAP 工作人员
_unitClasses = [
    "C_IDAP_Man_Aidworker_01_F",
    "C_IDAP_Man_Aidworker_02_F",
    "C_IDAP_Man_Aidworker_03_F",
    "C_IDAP_Man_Aidworker_04_F",
    "C_IDAP_Man_Aidworker_05_F",
    "C_IDAP_Man_Aidworker_06_F"
];
_groupUnits = [];
for "_i" from 1 to 5 do {
    _groupUnits pushBack (selectRandom _unitClasses);
};
_groupDelivery = [_targetDeliveryPos, civilian, _groupUnits, [], [], [0.5, 0.6]] call BIS_fnc_spawnGroup;

{
    private _offsetDist = 5 + random 3;
    private _offsetDir = random 360;
    private _newPos = _targetDeliveryPos getPos [_offsetDist, _offsetDir];
    _x setPos _newPos;
    _x disableAI "MOVE";
    _x disableAI "PATH";
    _x setBehaviour "CARELESS";
    [_x] spawn {
        params ["_unit"];
        while {alive _unit} do {
            _unit switchmove "Acts_JetsShooterNavigate_loop_m";
            sleep 5;
        };
    };
} forEach units _groupDelivery;

_smokeObjects = [];
_deliverySmokeScript = [_targetDeliveryPos, _smokeObjects] spawn {
    params ["_pos", "_smokeObjects"];
    while {true} do {
        if (count _smokeObjects > 0) then {
            deleteVehicle (_smokeObjects select 0);
            _smokeObjects deleteAt 0;
        };
        _smoke = "SmokeShellGreen" createVehicle _pos;
        _smoke setPos _pos;
        _smokeObjects pushBack _smoke;
        sleep 30;
    };
};

// 任务前对话
[_speakerIDAP, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 12;
[_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_speakeracteam, _message2] remoteExec ["fnc_duws_dialogue", 0];
sleep 5;

// TASK AND NOTIFICATION

// 设置任务目标位置（卡车位置）
["info", [localize "STR_DUWS_T_SEARCH_CORPSE", localize "STR_DUWS_T_sidemissionloc"]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];

sleep 5; // 等待巡逻队生成完毕


// 监控任务完成条件
waitUntil {
    sleep 2;
    (getdammage _truck1>0.95) || (_truck1 distance _targetDeliveryPos) < 50
};

// 删除任务区域标记
deleteMarker str(_markername2);

// 失败分支
if (getdammage _truck1>0.95) exitWith {
    deleteMarker _deliveryMarkerName;
    call _cleanupDelivery;
    _truck1 setDamage 1;
    [{hint localize "STR_DUWS_T_jsg7ys0w"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [_VARtaskgeneratedName, "FAILED"] call fnc_missionTaskEnd;
    // Reputation is a civilian-system currency: skip its change when civilians are off. The
    // town is resolved from the delivery point, falling back to the global outside every radius.
    if (CIV_PRESENCE != "NONE") then {
        [[_targetpos] call fnc_civ_townAt, -5, "idap_failed"] call fnc_town_rep_adjust;
    };
    [_targetpos,_radius, "mission_transport_idap"] call fnc_mission_end;
};

// 成功分支
deleteMarker _deliveryMarkerName;
[_speakerIDAP, _message3] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;
if (CIV_PRESENCE != "NONE") then {
    [[_targetpos] call fnc_civ_townAt, 5, "idap_success"] call fnc_town_rep_adjust;
};
sleep 2;
deleteVehicle _box2;
sleep 2;
deleteVehicle _box1;
sleep 8;
deleteVehicle _truck1;
call _cleanupDelivery;


[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[_targetpos,_radius, "mission_transport_idap", true] call fnc_mission_end;
