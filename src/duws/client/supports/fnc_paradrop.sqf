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
_message = localize "STR_DUWS_T_paradropcall";
[_speaker, _message, "", name player] remoteExec ["fnc_duws_dialogue", 0];
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_paradropack"] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_speaker1, localize "STR_DUWS_T_paradropinbound"] remoteExec ["fnc_duws_dialogue", 0];

_group = "";
_vehicle = "";

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
// Cosmetic transport: crew hold fire and don't acquire, so it flies the drop run instead of engaging.
_pilot disableAI "Target";
_pilot disableAI "AUTOTARGET";
_group setCombatMode "BLUE";
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

private _soldiers = [];
switch (VERSION_X) do {
	case "MODERN": {
		private _roster = [
			blufor_SOLDIER_X, blufor_LAT_SOLDIER_X, blufor_GL_SOLDIER_X, blufor_SPECOPS_ENG_X,
			blufor_AR_SOLDIER_X, blufor_SOLDIER_X, blufor_SPECOPS_MEDIC_X, blufor_AR_SOLDIER_X,
			blufor_AR_SOLDIER_X, blufor_SOLDIER_X, blufor_SPECOPS_MEDIC_X, blufor_AR_SOLDIER_X
		];
		_soldiers = _roster apply { _group2 createUnit [_x, [0,0,0], [], 0, "form"] };
	};
};

_lz = _location;
// Soldiers 1 and 4 drop on the LZ centre; the rest scatter within _radius. Same 150 m release height.
{
	private _chute = "Steerable_Parachute_F" createVehicle _lz;
	private _chutePos = if (_forEachIndex in [0, 3]) then {
		[_lz select 0, _lz select 1, (_lz select 2)+150]
	} else {
		[(_lz select 0)+(random _radius)-(random _radius), (_lz select 1)+(random _radius)-(random _radius), (_lz select 2)+150]
	};
	_chute setPos _chutePos;
	_x moveindriver _chute;
	if (player_fatigue == 0) then { _x enablefatigue false };
} forEach _soldiers;

sleep 1; // beat after the green light before the chutes-away call
[_speaker1, localize "STR_DUWS_T_paradropdeployed"] remoteExec ["fnc_duws_dialogue", 0];

sleep 5;

{[_x] joinSilent player} forEach units _group2;

sleep 60;
{
	deleteVehicle _x;
} foreach units _group;

deleteVehicle _vehicle;

missionNamespace setVariable ["PARADROP_onStation", nil];