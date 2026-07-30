// Locality: client -- invoked from the comm menu (shared/includes/supports_radio_modern.hpp:87).
// The crate's scroll entries are attached by shared/functions/fnc_ammobox_actions.sqf, which this
// broadcasts to every machine.


_target = _this select 0;
_cost = _this select 1;
_location = getpos _target;

if !(["CP", _cost] call fnc_pool_spend) exitWith  
{
  ["info",[localize "STR_DUWS_T_e95mc4lv",format[localize "STR_DUWS_T_p6sb3ply",_cost]]] call bis_fnc_showNotification;
};

hint localize "STR_DUWS_T_y91vei53";

// SEND A PLANE
_group = "";
_vehicle = "";

// FIND A RANDOM LOCATION
_spawnPos = _location;
_vec =[random [-1,0,1], random [-1,0,1], 0];
_dist = 1600;
_spawnPos = ((vectorNormalized _vec) vectorMultiply _dist) vectorAdd _spawnPos;
_grouptype = "";
// 移除全局变量 onStation，改为在载具上存储状态
_speaker = localize "STR_DUWS_T_actionteam";
_speaker1 = localize "STR_DUWS_T_courier";
_message = ([localize "STR_DUWS_T_supplydropcall"] call fnc_cs);
_message1 = localize "STR_DUWS_T_supplydropcallend";
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

switch (VERSION_X) do {
	case "MODERN": {
		_spawnPos = [_spawnPos select 0, _spawnPos select 1, (_spawnPos select 2)+400];
		_grouptype = [blufor_HELI_TRANS_UNARM_X];
		//_grouptype = ["O_Heli_Light_02_unarmed_F"];
	};
};

_group = [_spawnPos, WEST, _grouptype, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
_pilot = units _group select 0;
_vehicle = vehicle _pilot;
_vehicle setVehicleAmmo 0;
_vehicle allowdamage false;
_vehicle engineOn true;

// 初始化载具状态变量（取代全局 onStation）
_vehicle setVariable ["DUWS_onStation", false];

	
_wp1 = _group addWaypoint [_location, -1];
_wp1 setWaypointType "MOVE";
_wp1 setWaypointBehaviour "CARELESS";
// 航点语句中修改载具变量，注意使用 vehicle this 获取实际载具
_wp1 setWaypointStatements ["true", "(vehicle this) setVariable ['DUWS_onStation', true];"]; 
_wp2 = _group addWaypoint [[0,0], 100];
_wp2 setWaypointType "MOVE";
_wp2 setWaypointBehaviour "CARELESS";
sleep 8;
[_speaker1, _message1] remoteExec ["fnc_duws_dialogue", 0];

hint localize "STR_DUWS_T_17hh9rx4";
sleep 30;
hint localize "STR_DUWS_T_zhiugl0g";
// 等待载具到达或损毁，使用载具变量判断
waitUntil {sleep 0.1; (_vehicle getVariable ["DUWS_onStation", false]) || !alive _vehicle};

if (!alive _vehicle) exitWith {hint localize "STR_DUWS_T_trkhanzi"};

_parachute = "Steerable_Parachute_F" CreateVehicle _location;
_parachute setPos [_location select 0, _location select 1, (_location select 2)+100];
_ammobox = "";
switch (VERSION_X) do {
	case "MODERN": {
		_ammobox = CreateVehicle ["B_supplyCrate_F", [_location select 0,_location select 1,(_location select 2)+50], [], 0, "CAN_COLLIDE"];
	};
};
_ammobox attachTo [_parachute,[0,0,0]];

hint localize "STR_DUWS_T_wdttb5b8";

waitUntil {sleep 1; getpos _ammobox select 2 < 0.2};

// 为补给箱添加唯一标记（使用 netId 确保多人游戏中不会冲突）
[getPos _ammobox, _ammobox] spawn {
	params ["_spawnPos", "_box"];
	private _markername = format ["ammobox_%1", netId _box];
	createMarker [_markername, _spawnPos];
	_markername setMarkerShape "ICON";
	_markername setMarkerType "hd_objective";
	_markername setMarkerColor "ColorYellow";
	_markername setMarkerSize [.5,.5]; 
	_markername setMarkerText "Supply Drop";
	sleep 60;
	deleteMarker _markername;
};

_smoke = "SmokeShellGreen" CreateVehicle (getpos _ammobox);
["info",[localize "STR_DUWS_T_lyxq9zpm",localize "STR_DUWS_T_5p6d9535"]] call bis_fnc_showNotification;
[_ammobox] remoteExec ["fnc_ammobox_actions", [0,-2] select isDedicated, _ammobox];
// 往补给箱中添加物品
[_ammobox,"blufor"] spawn fnc_fill_ammobox; 

// 延迟后删除飞机及机组
sleep 60;
{
	deleteVehicle _x;
} foreach units _group;

deleteVehicle _vehicle;