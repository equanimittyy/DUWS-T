/*
 * fnc_ammobox.sqf
 * 功能：呼叫空投补给箱，消耗指挥点，空中载具运送并投放。
 * 修改：移除全局变量 onStation，改用载具变量；标记名使用 netId 确保唯一。
 */

_target = _this select 0;
_cost = _this select 1;
_location = getpos _target;

if (commandpointsblu1 < _cost) exitWith  
{
  ["info",[localize "STR_DUWS_T_e95mc4lv",format[localize "STR_DUWS_T_p6sb3ply",_cost]]] call bis_fnc_showNotification;
};
[-_cost] remoteExec ["fnc_cp_adjust", 2];

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
_speaker1 = localize "STR_DUWS_T_pilot";
_message = localize "STR_DUWS_T_supplydropcall";
_message1 = localize "STR_DUWS_T_supplydropcallend";
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];

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
[_speaker1, _message1] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];

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
[[_ammobox,[localize "STR_DUWS_T_160jkc3a",fnc_duws_Arsenal,[], 0, false, false, "", "_this distance _target < 8"]],"addAction",true,true] call BIS_fnc_MP;
[[_ammobox,[localize "STR_DUWS_T_xfgokhbc",fnc_AI_rearm,[], 0, false, false, "", "_this distance _target < 8"]],"addAction",true,true] call BIS_fnc_MP;
// 往补给箱中添加物品
[_ammobox,"blufor"] spawn fnc_fill_ammobox; 

// 延迟后删除飞机及机组
sleep 60;
{
	deleteVehicle _x;
} foreach units _group;

deleteVehicle _vehicle;