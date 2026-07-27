// Locality: client -- invoked from the comm menu (shared/includes/supports_radio_modern.hpp:107).
_target = _this select 0;
_cost = _this select 1;
_location = getpos _target;

if !(["CP", _cost] call fnc_pool_spend) exitWith  
{
  ["info",[localize "STR_DUWS_T_e95mc4lv",format[localize "STR_DUWS_T_p6sb3ply",_cost]]] call bis_fnc_showNotification;
};

hint localize "STR_DUWS_T_q76uei82";
_speaker = localize "STR_DUWS_T_actionteam";
_speaker1 = localize "STR_DUWS_T_stork";
_message = ([localize "STR_DUWS_T_sivacall"] call fnc_cs);
_message1 = localize "STR_DUWS_T_sivacallend";
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

// SEND A PLANE
_group = "";
_vehicle = "";

// FIND A RANDOM LOCATION
_spawnPos = _location;
_vec =[random [-1,0,1], random [-1,0,1], 0];
_dist = 1200;
_spawnPos = ((vectorNormalized _vec) vectorMultiply _dist) vectorAdd _spawnPos;
_grouptype = "";
// 使用任务命名空间变量替代全局 onStation
missionNamespace setVariable ["SIVA_onStation", false];


_spawnPos = [_spawnPos select 0, _spawnPos select 1, (_spawnPos select 2)+400];
_grouptype = [blufor_HELI_TRANS_UNARM_X];

_group = [_spawnPos, WEST, _grouptype, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
_pilot = units _group select 0;
_vehicle = vehicle _pilot;
_vehicle setVehicleAmmo 0;
_vehicle allowdamage false;
_vehicle engineOn true;
	
_wp1 = _group addWaypoint [_location, -1];
_wp1 setWaypointType "MOVE";
_wp1 setWaypointBehaviour "CARELESS";
// 航点到达时设置任务变量为 true
_wp1 setWaypointStatements ["true", "missionNamespace setVariable ['SIVA_onStation', true]"]; 
_wp2 = _group addWaypoint [[0,0], 100];
_wp2 setWaypointType "MOVE";
_wp2 setWaypointBehaviour "CARELESS";

hint localize "STR_DUWS_T_jjzzkt03";
sleep 18;
[_speaker1, _message1] remoteExec ["fnc_duws_dialogue", 0];
hint localize "STR_DUWS_T_9tpm5uf6";

// 第一次检查：飞机是否在等待期间被击毁
if (!alive _vehicle) exitWith {
    hint localize "STR_DUWS_T_7h0bmzi7";
    missionNamespace setVariable ["SIVA_onStation", nil];
    // 清理飞机及组
    { deleteVehicle _x } forEach units _group;
    deleteVehicle _vehicle;
};

waitUntil {sleep 0.5; missionNamespace getVariable "SIVA_onStation" || !alive _vehicle};

// 第二次检查：飞机是否在到达前被击毁
if (!alive _vehicle) exitWith {
    hint localize "STR_DUWS_T_7h0bmzi7";
    missionNamespace setVariable ["SIVA_onStation", nil];
    { deleteVehicle _x } forEach units _group;
    deleteVehicle _vehicle;
};

_parachute = "Steerable_Parachute_F" CreateVehicle _location;
_parachute setPos [_location select 0, _location select 1, (_location select 2)+100];
_cargo = "";
switch (VERSION_X) do {
	case "MODERN": {
		_cargo = CreateVehicle [blufor_CAR_PATROL1_X, [_location select 0,_location select 1,(_location select 2)+50], [], 0, "CAN_COLLIDE"];
	};
};
_cargo attachTo [_parachute,[0,0,0]];

hint localize "STR_DUWS_T_jjzzkt04";

sleep 30;

deleteVehicle _parachute;

sleep 7;

_smoke = "SmokeShellGreen" CreateVehicle (getpos _cargo);
["info",[localize "STR_DUWS_T_2oefoo3j",localize "STR_DUWS_T_pvue8vst"]] call bis_fnc_showNotification;
_cargo setVehicleArmor 1;

//DELETE THE PLANE
sleep 60;
{
	deleteVehicle _x;
} foreach units _group;

deleteVehicle _vehicle;

// 清理任务变量
missionNamespace setVariable ["SIVA_onStation", nil];