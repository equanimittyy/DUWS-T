// Locality: client -- invoked from the comm menu (shared/includes/supports_radio_modern.hpp:117).
_target = _this select 0;
_cost = _this select 1;
_location = getpos _target;

if !(["CP", _cost] call fnc_pool_spend) exitWith  
{
  ["info",[localize "STR_DUWS_T_e95mc4lv",format[localize "STR_DUWS_T_p6sb3ply",_cost]]] call bis_fnc_showNotification;
};
hint localize "STR_DUWS_T_sawpdown";
_speaker = localize "STR_DUWS_T_actionteam";
_speaker1 = localize "STR_DUWS_T_courier3";
_message = ([localize "STR_DUWS_T_sawpcall"] call fnc_cs);
_message1 = ([localize "STR_DUWS_T_sawpcallend"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

sleep 8;
// SEND A PLANE
_group = "";
_vehicle = "";

// FIND A RANDOM LOCATION
_spawnPos = _location;
_vec =[random [-1,0,1], random [-1,0,1], 0];
_dist = 1200;
_spawnPos = ((vectorNormalized _vec) vectorMultiply _dist) vectorAdd _spawnPos;
_grouptype = "";
// mission-namespace variable instead of a global onStation
missionNamespace setVariable ["SAWP_onStation", false];

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
	
_wp1 = _group addWaypoint [_location, -1];
_wp1 setWaypointType "MOVE";
_wp1 setWaypointBehaviour "CARELESS";
_wp1 setWaypointStatements ["true", "missionNamespace setVariable ['SAWP_onStation', true]"]; 
_wp2 = _group addWaypoint [[0,0], 100];
_wp2 setWaypointType "MOVE";
_wp2 setWaypointBehaviour "CARELESS";
sleep 8;
hint localize "STR_DUWS_T_sawpibnd";
[_speaker1, _message1] remoteExec ["fnc_duws_dialogue", 0];
sleep 18;
hint localize "STR_DUWS_T_sawposdt";

// plane destroyed while waiting?
if (!alive _vehicle) exitWith {
    hint localize "STR_DUWS_T_sawpfail";
    missionNamespace setVariable ["SAWP_onStation", nil];
    { deleteVehicle _x } forEach units _group;
    deleteVehicle _vehicle;
};

waitUntil {sleep 0.5; missionNamespace getVariable "SAWP_onStation" || !alive _vehicle};

// re-check the plane is alive; this branch runs if it was destroyed
if (!alive _vehicle) exitWith {
    hint localize "STR_DUWS_T_sawpfail";
    missionNamespace setVariable ["SAWP_onStation", nil];
    { deleteVehicle _x } forEach units _group;
    deleteVehicle _vehicle;
};

_parachute = "Steerable_Parachute_F" CreateVehicle _location;
_parachute setPos [_location select 0, _location select 1, (_location select 2)+100];
_ammobox = "";
switch (VERSION_X) do {
	case "MODERN": {
		_ammobox = CreateVehicle ["Box_NATO_Equip_F", [_location select 0,_location select 1,(_location select 2)+50], [], 0, "CAN_COLLIDE"];
	};
};
_ammobox attachTo [_parachute,[0,0,0]];

hint localize "STR_DUWS_T_sawpnts1";

waitUntil {sleep 1; getpos _ammobox select 2 < 0.2};

// give ammobox a marker
[getPos _ammobox] spawn {
	_spawnPos = _this select 0;
	_markername = format["lbl%1",_spawnPos]; // Define marker name
	createMarker [_markername, _spawnPos];
	_markername setMarkerShape "ICON";
	_markername setMarkerType "hd_objective";
	_markername setMarkerColor "ColorYellow";
	_markername setMarkerSize [.5,.5]; 
	_markername setMarkerText "SAWP Pos";
	sleep 60;
	deletemarker _markername;
};

"SmokeShellGreen" CreateVehicle (getpos _ammobox);
["info",[localize "STR_DUWS_T_sawpinfo",localize "STR_DUWS_T_sawpnts2"]] call bis_fnc_showNotification;

// Put SAWP System in the ammobox
[_ammobox,"blufor"] spawn fnc_fill_sawpbox;


//DELETE THE PLANE
sleep 60;
{
	deleteVehicle _x;
} foreach units _group;

deleteVehicle _vehicle;

missionNamespace setVariable ["SAWP_onStation", nil];