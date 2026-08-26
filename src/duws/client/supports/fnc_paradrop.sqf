// Locality: client -- invoked from the comm menu (shared/includes/supports_radio_modern.hpp:127).
_target = _this select 0;
_cost = _this select 1;
_location = getpos _target;

if !(["CP", _cost] call fnc_pool_spend) exitWith  
{
  ["info",[localize "STR_DUWS_T_e95mc4lv",format[localize "STR_DUWS_T_p6sb3ply",_cost]]] call bis_fnc_showNotification;
};

_speaker = localize "STR_DUWS_T_actionteam";
_speaker1 = localize "STR_DUWS_T_chalk";
_message = ([localize "STR_DUWS_T_paradropcall"] call fnc_cs);
_message1 = localize "STR_DUWS_T_paradropcallend";
[_speaker, _message, "", name player] remoteExec ["fnc_duws_dialogue", 0];
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_paradropack"] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_speaker1, localize "STR_DUWS_T_paradropinbound"] remoteExec ["fnc_duws_dialogue", 0];

// SEND A PLANE
_group = "";
_vehicle = "";

// FIND A RANDOM LOCATION
_spawnPos = _location;
_vec =[random [-1,0,1], random [-1,0,1], 0];
_dist = 3100;
_spawnPos = ((vectorNormalized _vec) vectorMultiply _dist) vectorAdd _spawnPos;
_grouptype = "";
// mission-namespace variable instead of a global onStation
missionNamespace setVariable ["PARADROP_onStation", false];

switch (VERSION_X) do {
	case "MODERN": {
		_spawnPos = [_spawnPos select 0, _spawnPos select 1, (_spawnPos select 2)+400];
		_grouptype = [blufor_TRANS_HELI_X];
	};
};

_group = [_spawnPos, WEST, _grouptype, [], [], blufor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
_pilot = units _group select 0;
_vehicle = vehicle _pilot;
_vehicle setVehicleAmmo 0;
_vehicle allowdamage false;
_vehicle engineOn true;

switch (VERSION_X) do {
	case "MODERN": {
		_vehicle flyInHeight 250;
	};
};
	
_wp1 = _group addWaypoint [_location, -1];
_wp1 setWaypointType "MOVE";
_wp1 setWaypointBehaviour "CARELESS";
_wp1 setWaypointStatements ["true", "missionNamespace setVariable ['PARADROP_onStation', true]"]; 
_wp2 = _group addWaypoint [[0,0], 100];
_wp2 setWaypointType "MOVE";
_wp2 setWaypointBehaviour "CARELESS";

sleep 40;

// first check: plane destroyed while waiting?
if (!alive _vehicle) exitWith {
    [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_paradropdown"] remoteExec ["fnc_duws_dialogue", 0];
    missionNamespace setVariable ["PARADROP_onStation", nil];
    { deleteVehicle _x } forEach units _group;
    deleteVehicle _vehicle;
};

waitUntil {sleep 0.5; missionNamespace getVariable "PARADROP_onStation" || !alive _vehicle};

// second check: plane destroyed before arrival?
if (!alive _vehicle) exitWith {
    [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_paradropdown"] remoteExec ["fnc_duws_dialogue", 0];
    missionNamespace setVariable ["PARADROP_onStation", nil];
    { deleteVehicle _x } forEach units _group;
    deleteVehicle _vehicle;
};

_group2 = creategroup WEST;
_radius = 130;
_group2 deleteGroupWhenEmpty true;
[_speaker1, localize "STR_DUWS_T_paradroponstation"] remoteExec ["fnc_duws_dialogue", 0];
[_speaker1, _message1] remoteExec ["fnc_duws_dialogue", 0];

private ["_soldier1","_soldier2","_soldier3","_soldier4","_soldier5","_soldier6","_soldier7","_soldier8","_soldier9","_soldier10","_soldier11","_soldier12"];
switch (VERSION_X) do {
	case "MODERN": {
		_soldier1 = _group2 createUnit [blufor_SOLDIER_X,[0,0,0],[],0,"form"];
		_soldier2 = _group2 createUnit [blufor_LAT_SOLDIER_X,[0,0,0],[],0,"form"];
		_soldier3 = _group2 createUnit [blufor_GL_SOLDIER_X,[0,0,0],[],0,"form"];
		_soldier4 = _group2 createUnit [blufor_SPECOPS_ENG_X,[0,0,0],[],0,"form"];
		_soldier5 = _group2 createUnit [blufor_AR_SOLDIER_X,[0,0,0],[],0,"form"];
		_soldier6 = _group2 createUnit [blufor_SOLDIER_X,[0,0,0],[],0,"form"];
		_soldier7 = _group2 createUnit [blufor_SPECOPS_MEDIC_X,[0,0,0],[],0,"form"];
		_soldier8 = _group2 createUnit [blufor_AR_SOLDIER_X,[0,0,0],[],0,"form"];
		_soldier9 = _group2 createUnit [blufor_AR_SOLDIER_X,[0,0,0],[],0,"form"];
		_soldier10 = _group2 createUnit [blufor_SOLDIER_X,[0,0,0],[],0,"form"];
		_soldier11 = _group2 createUnit [blufor_SPECOPS_MEDIC_X,[0,0,0],[],0,"form"];
		_soldier12 = _group2 createUnit [blufor_AR_SOLDIER_X,[0,0,0],[],0,"form"];
	};
};

_lz = _location;
_parachute1 = "Steerable_Parachute_F" CreateVehicle _lz;  
_parachute1 setPos [_lz select 0, _lz select 1, (_lz select 2)+150];
_soldier1 moveindriver _parachute1;
if (player_fatigue == 0) then {_soldier1 enablefatigue false;};

_parachute2 = "Steerable_Parachute_F" CreateVehicle _lz;  
_parachute2 setPos [(_lz select 0)+(random _radius)-(random _radius), (_lz select 1)+(random _radius)-(random _radius), (_lz select 2)+150];
_soldier2 moveindriver _parachute2;
if (player_fatigue == 0) then {_soldier2 enablefatigue false;};

_parachute3 = "Steerable_Parachute_F" CreateVehicle _lz;  
_parachute3 setPos [(_lz select 0)+(random _radius)-(random _radius), (_lz select 1)+(random _radius)-(random _radius), (_lz select 2)+150];
_soldier3 moveindriver _parachute3;
if (player_fatigue == 0) then {_soldier3 enablefatigue false;};

_parachute4 = "Steerable_Parachute_F" CreateVehicle _lz;  
_parachute4 setPos [_lz select 0, _lz select 1, (_lz select 2)+150];
_soldier4 moveindriver _parachute4;
if (player_fatigue == 0) then {_soldier4 enablefatigue false;};

_parachute5 = "Steerable_Parachute_F" CreateVehicle _lz;  
_parachute5 setPos [(_lz select 0)+(random _radius)-(random _radius), (_lz select 1)+(random _radius)-(random _radius), (_lz select 2)+150];
_soldier5 moveindriver _parachute5;
if (player_fatigue == 0) then {_soldier5 enablefatigue false;};

_parachute6 = "Steerable_Parachute_F" CreateVehicle _lz;  
_parachute6 setPos [(_lz select 0)+(random _radius)-(random _radius), (_lz select 1)+(random _radius)-(random _radius), (_lz select 2)+150];
_soldier6 moveindriver _parachute6;
if (player_fatigue == 0) then {_soldier6 enablefatigue false;};

_parachute7 = "Steerable_Parachute_F" CreateVehicle _lz;  
_parachute7 setPos [(_lz select 0)+(random _radius)-(random _radius), (_lz select 1)+(random _radius)-(random _radius), (_lz select 2)+150];
_soldier7 moveindriver _parachute7;
if (player_fatigue == 0) then {_soldier7 enablefatigue false;};

_parachute8 = "Steerable_Parachute_F" CreateVehicle _lz;  
_parachute8 setPos [(_lz select 0)+(random _radius)-(random _radius), (_lz select 1)+(random _radius)-(random _radius), (_lz select 2)+150];
_soldier8 moveindriver _parachute8;
if (player_fatigue == 0) then {_soldier8 enablefatigue false;};

_parachute9 = "Steerable_Parachute_F" CreateVehicle _lz;  
_parachute9 setPos [(_lz select 0)+(random _radius)-(random _radius), (_lz select 1)+(random _radius)-(random _radius), (_lz select 2)+150];
_soldier9 moveindriver _parachute9;
if (player_fatigue == 0) then {_soldier9 enablefatigue false;};

_parachute10 = "Steerable_Parachute_F" CreateVehicle _lz;  
_parachute10 setPos [(_lz select 0)+(random _radius)-(random _radius), (_lz select 1)+(random _radius)-(random _radius), (_lz select 2)+150];
_soldier10 moveindriver _parachute10;
if (player_fatigue == 0) then {_soldier10 enablefatigue false;};

_parachute11 = "Steerable_Parachute_F" CreateVehicle _lz;  
_parachute11 setPos [(_lz select 0)+(random _radius)-(random _radius), (_lz select 1)+(random _radius)-(random _radius), (_lz select 2)+150];
_soldier11 moveindriver _parachute11;
if (player_fatigue == 0) then {_soldier11 enablefatigue false;};

_parachute12 = "Steerable_Parachute_F" CreateVehicle _lz;  
_parachute12 setPos [(_lz select 0)+(random _radius)-(random _radius), (_lz select 1)+(random _radius)-(random _radius), (_lz select 2)+150];
_soldier12 moveindriver _parachute12;
if (player_fatigue == 0) then {_soldier12 enablefatigue false;};

[_speaker1, localize "STR_DUWS_T_paradropdeployed"] remoteExec ["fnc_duws_dialogue", 0];

sleep 5;

{[_x] joinSilent player} forEach units _group2;

//DELETE THE PLANE
sleep 60;
{
	deleteVehicle _x;
} foreach units _group;

deleteVehicle _vehicle;

missionNamespace setVariable ["PARADROP_onStation", nil];