_target = _this select 0;
_cost = _this select 1;
_location = getpos _target;

if (commandpointsblu1 < _cost) exitWith  
{
  ["info",[localize "STR_DUWS_T_e95mc4lv",format[localize "STR_DUWS_T_p6sb3ply",_cost]]] call bis_fnc_showNotification;
};
[-_cost] remoteExec ["fnc_cp_adjust", 2];

hint localize "STR_DUWS_T_q76uei82";
_speaker = localize "STR_DUWS_T_actionteam";
_speaker1 = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_vehdropcall";
_message1 = localize "STR_DUWS_T_vehdropcallend";
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];

// SEND A PLANE
_group = "";
_vehicle = "";

// FIND A RANDOM LOCATION
_spawnPos = _location;
_vec =[random [-1,0,1], random [-1,0,1], 0];
_dist = 1200;
_spawnPos = ((vectorNormalized _vec) vectorMultiply _dist) vectorAdd _spawnPos;
_grouptype = "";
onStation = false;

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
_wp1 setWaypointStatements ["true", "onStation = true"]; 
_wp2 = _group addWaypoint [[0,0], 100];
_wp2 setWaypointType "MOVE";
_wp2 setWaypointBehaviour "CARELESS";

hint localize "STR_DUWS_T_6cwj6h8z";
sleep 18;
[_speaker1, _message1] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
hint localize "STR_DUWS_T_9tpm5uf6";
waitUntil {sleep 0.5;onStation||!alive _vehicle};

if (!alive _vehicle) exitWith {hint localize "STR_DUWS_T_7h0bmzi7"};

_parachute = "Steerable_Parachute_F" CreateVehicle _location;
_parachute setPos [_location select 0, _location select 1, (_location select 2)+100];
_cargo = "";
switch (VERSION_X) do {
	case "MODERN": {
		_cargo = CreateVehicle ["C_Offroad_01_F", [_location select 0,_location select 1,(_location select 2)+50], [], 0, "CAN_COLLIDE"];
	};
};
_cargo attachTo [_parachute,[0,0,0]];

hint localize "STR_DUWS_T_iv3s5xlc";

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

