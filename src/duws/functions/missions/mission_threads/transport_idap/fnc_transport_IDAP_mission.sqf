// 任务冷却检查
private _missionType = 15;
private _cooldownVar = missionNamespace getVariable [format ["mission_cooldown_%1", _missionType], 0];
if (_cooldownVar > diag_tickTime) then {
    private _remaining = _cooldownVar - diag_tickTime;
    private _minutes = floor (_remaining / 60);
    private _seconds = _remaining % 60;
    hint format [localize "STR_DUWS_T_MISSION_COOLDOWN", _minutes, _seconds];
    if (isNil "fnc_scriptName") then {
        breakOut "main";
    } else {
        if (true) exitWith {};
    };
};
mission_cooldown_15 = diag_tickTime + 3600;
publicVariable format ["mission_cooldown_15", _missionType];
params ["_MissionPos", "_mission_name"];

// ========== 增援系统变量 ==========
private _varSuffix = format ["%1_%2", round(_MissionPos select 0), round(_MissionPos select 1)];
private _initialCountVar = format ["opf_initial_%1", _varSuffix];
private _triggeredVar = format ["opf_reinforce_%1", _varSuffix];
// ====================================

Mission_available = false;
publicVariable "Mission_available";

_radius = 600;
_cpreward = 20;
_apreward = 0;
_speakerIDAP = localize "STR_DUWS_T_IDAP";
_speaker = localize "STR_DUWS_T_OVERLORD";
_speakeracteam  = localize "STR_DUWS_T_actionteam";
_message = localize "STR_DUWS_T_idapletsdothis";
_message1 = localize "STR_DUWS_T_idapcopy";
_message2 = localize "STR_DUWS_T_idapacteamgo";
_message3 = localize "STR_DUWS_T_idapend";
_randomPos = [];
_Building = [];
_Posfound = false;
_targetpos = [];
_failSafe = 0;
_markerText = "IDAP";
_markerText2 = localize "STR_DUWS_T_c15";

_POSdata = [_MissionPos, _radius, _Posfound, _targetpos, _failSafe] call fnc_missionTargetPos;

_randomPos = _POSdata select 0;
_Building = _POSdata select 1;
_Posfound = _POSdata select 2;
_targetpos = _POSdata select 3;
_failSafe = _POSdata select 4;

if (_failsafe > 10 && _Posfound == false) exitWith {
    Mission_available = true;
    publicVariable "Mission_available";
    [{hint localize "STR_DUWS_T_crtzxs0j"}] remoteExec ["BIS_fnc_Spawn", 0];
};

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn",  player1];

_vehPos = _targetpos;

_markerData = [_randomPos, _markerText, _markerText2, _radius] call fnc_missionMarkerData;
_markername = _markerData select 0;
_markername2 = _markerData select 1;

private _missionObjects = [];

// 生成卡车
_truck1 = "C_IDAP_Truck_02_Transport_F" createVehicle (_vehpos);
_missionObjects pushBack _truck1;

// 生成补给箱
_box1 = "";
_box2 = "";
_static1 = "";
_static2 = "";
switch (VERSION_X) do {
    case "MODERN": {
        _box1 = "Land_FoodSacks_01_cargo_white_idap_F" createVehicle (_missionpos);
        _box2 = "Land_FoodSacks_01_cargo_white_idap_F" createVehicle (_missionpos);
        _box1 attachTo [_truck1,[0,-0.5,0]];
        _box1 setDir 90;
        _box2 attachTo [_truck1,[0,-2.2,0]];
        _box2 setDir 75;
        _static1 = "CargoNet_01_barrels_F";
        _static2 = "CamoNet_INDP_open_F";
    };
};

_obj1 = createVehicle [_static1, [(_vehpos select 0)-12, (_vehpos select 1)-10], [], 0, "CAN_COLLIDE"];
_missionObjects pushBack _obj1;
sleep 1;
_obj2 = createVehicle [_static1, [(_vehpos select 0)-10, (_vehpos select 1)-10], [], 0, "CAN_COLLIDE"];
_missionObjects pushBack _obj2;
sleep 1;
_obj3 = createVehicle [_static1, [(_vehpos select 0)-8, (_vehpos select 1)-10], [], 0, "CAN_COLLIDE"];
_missionObjects pushBack _obj3;
sleep 1;
_obj4 = createVehicle [_static2, [(_vehpos select 0)-10, (_vehpos select 1)-10], [], 0, "CAN_COLLIDE"];
_missionObjects pushBack _obj4;
sleep 1;

// Vehicle guards
_group = [_vehPos, EAST, [opfor_SL_SOLDIER_X, opfor_LAT_SOLDIER_X, opfor_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;

// CREATE PATROLS
sleep 1;
[_targetpos, _radius] spawn fnc_missionPatrolswithintel;

{
    if (!isNull _x) then {
        [_x] call fnc_add_intel_to_group;
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
[_speakerIDAP, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 12;
[_speaker, _message1] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 8;
[_speakeracteam, _message2] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 5;

// TASK AND NOTIFICATION
private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["rescue%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[west, [_VARtaskgeneratedName],
[localize "STR_DUWS_T_transIDAP", _mission_name, "(getMarkerPos str(_markername))"], objNull, true] call BIS_fnc_taskCreate;

// 设置任务目标位置（卡车位置）
missionNamespace setVariable ["current_mission_target_pos", getPos _truck1];
["info", [localize "STR_DUWS_T_SEARCH_CORPSE", localize "STR_DUWS_T_sidemissionloc"]] remoteExec ["BIS_fnc_showNotification", 0];

// ========== 统计初始敌军数量 ==========
sleep 5; // 等待巡逻队生成完毕
private _nearbyEnemies = _targetpos nearEntities [["CAManBase", "LandVehicle", "Air"], _radius * 1.5] select { side _x == EAST };
private _initialEnemyCount = count _nearbyEnemies;
missionNamespace setVariable [_initialCountVar, _initialEnemyCount, true];
missionNamespace setVariable [_triggeredVar, false, true];
diag_log format ["[Reinforce] %1: Initial enemy count = %2", _mission_name, _initialEnemyCount];

// ========== 启动直升机增援监控 ==========
[_targetpos, _radius, _initialCountVar, _triggeredVar, _VARtaskgeneratedName] spawn fnc_opf_heli_reinforce;
// ======================================

// 监控任务完成条件
waitUntil {
    sleep 2;
    (getdammage _truck1>0.95) || (_truck1 distance _targetDeliveryPos) < 50
};

// 删除任务区域标记
deleteMarker str(_markername2);
deleteMarker str(_markername);

// 失败分支
if (getdammage _truck1>0.95) exitWith {
    deleteMarker _deliveryMarkerName;
    call _cleanupDelivery;
    _truck1 setDamage 1;
    [{hint localize "STR_DUWS_T_jsg7ys0w"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [_VARtaskgeneratedName, "FAILED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated,true];
    // Reputation is a civilian-system currency: skip its change (and notification) when civilians are off.
    if (CIV_PRESENCE != "NONE") then {
        Player_Reputation = Player_Reputation - 5;
        publicVariable "Player_Reputation";
        ["info", [localize "STR_DUWS_T_shengwangjianshao", format [localize "STR_DUWS_T_0pluxey2", Player_Reputation]]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated, false];
    };
    [] spawn fnc_missionTimer;
    missionNamespace setVariable [_triggeredVar, true, true];
    [_targetpos,_radius] spawn fnc_mission_cleanup;
    missionNamespace setVariable ["current_mission_target_pos", nil];
};

// 成功分支
deleteMarker _deliveryMarkerName;
[_speakerIDAP, _message3] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 8;
[_VARtaskgeneratedName, "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated,true];
if (CIV_PRESENCE != "NONE") then {
    Player_Reputation = Player_Reputation + 5;
    publicVariable "Player_Reputation";
    ["repup", [localize "STR_DUWS_T_rqwho9bq", format [localize "STR_DUWS_T_0pluxey2", Player_Reputation]]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated, false];
};
sleep 2;
deleteVehicle _box2;
sleep 2;
deleteVehicle _box1;
sleep 8;
deleteVehicle _truck1;
call _cleanupDelivery;

[_missionObjects] spawn {
    params ["_objects"];
    sleep 360;
    {
        if (!isNull _x) then {
            deleteVehicle _x;
        };
    } forEach _objects;
};

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[] spawn fnc_missionTimer;
missionNamespace setVariable [_triggeredVar, true, true];
[_targetpos,_radius] spawn fnc_mission_cleanup_agressive;

missionNamespace setVariable ["current_mission_target_pos", nil];