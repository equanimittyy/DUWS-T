// Locality: client -- invoked from the comm menu (shared/includes/supports_radio_modern.hpp:87).
// Drops an empty crate as a field loadout station: its Arsenal + rearm entries come from
// shared/functions/fnc_field_box_actions.sqf and the Quick Kits menu from fnc_addQuickChangeActions,
// both broadcast to every machine.


_target = _this select 0;
_cost = _this select 1;
_location = getpos _target;

if !(["CP", _cost] call fnc_pool_spend) exitWith  
{
  ["info",[localize "STR_DUWS_T_e95mc4lv",format[localize "STR_DUWS_T_p6sb3ply",_cost]]] call bis_fnc_showNotification;
};

_group = "";
_vehicle = "";

_spawnPos = _location;
_vec =[random [-1,0,1], random [-1,0,1], 0];
_dist = 1600;
_spawnPos = ((vectorNormalized _vec) vectorMultiply _dist) vectorAdd _spawnPos;
_grouptype = "";
// state kept on the vehicle rather than a global onStation
_speaker = localize "STR_DUWS_T_actionteam";
_speaker1 = localize "STR_DUWS_T_courier";
_message = localize "STR_DUWS_T_supplydropcall";
_message1 = localize "STR_DUWS_T_supplydropcallend";
[_speaker, _message, "", name player] remoteExec ["fnc_duws_dialogue", 0];
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_supplydropack"] remoteExec ["fnc_duws_dialogue", 0];

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

_vehicle setVariable ["DUWS_onStation", false];

	
_wp1 = _group addWaypoint [_location, -1];
_wp1 setWaypointType "MOVE";
_wp1 setWaypointBehaviour "CARELESS";
// in the waypoint statement use 'vehicle this' to get the real vehicle
_wp1 setWaypointStatements ["true", "(vehicle this) setVariable ['DUWS_onStation', true];"]; 
_wp2 = _group addWaypoint [[0,0], 100];
_wp2 setWaypointType "MOVE";
_wp2 setWaypointBehaviour "CARELESS";
sleep 8;
[_speaker1, _message1] remoteExec ["fnc_duws_dialogue", 0];

sleep 30;
waitUntil {sleep 0.1; (_vehicle getVariable ["DUWS_onStation", false]) || !alive _vehicle};

if (!alive _vehicle) exitWith {[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_supplydropdown"] remoteExec ["fnc_duws_dialogue", 0]};

_parachute = "Steerable_Parachute_F" CreateVehicle _location;
_parachute setPos [_location select 0, _location select 1, (_location select 2)+100];
_ammobox = "";
switch (VERSION_X) do {
	case "MODERN": {
		_ammobox = CreateVehicle ["B_supplyCrate_F", [_location select 0,_location select 1,(_location select 2)+50], [], 0, "CAN_COLLIDE"];
	};
};
// A field loadout station, not a loot crate: strip whatever cargo the class ships with so the box
// is empty and its only gear comes through the Arsenal.
clearWeaponCargoGlobal _ammobox;
clearMagazineCargoGlobal _ammobox;
clearItemCargoGlobal _ammobox;
clearBackpackCargoGlobal _ammobox;
_ammobox attachTo [_parachute,[0,0,0]];

[_speaker1, localize "STR_DUWS_T_supplydroponstation"] remoteExec ["fnc_duws_dialogue", 0];
hint localize "STR_DUWS_T_wdttb5b8";

waitUntil {sleep 1; getpos _ammobox select 2 < 0.2};

// tag the crate with its netId so the marker is unique across MP
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

"SmokeShellGreen" CreateVehicle (getpos _ammobox);
// Two broadcasts, two JIP ids: the Arsenal/rearm pair keys on the box (so its queue entry dies with
// the crate), and Quick Kits takes a distinct string id -- a second broadcast against the same id
// would evict the first and leave late joiners with only one of the two.
[_ammobox] remoteExec ["fnc_field_box_actions", [0,-2] select isDedicated, _ammobox];
[_ammobox] remoteExec ["fnc_addQuickChangeActions", 0, format ["supplydrop_quickchange_%1", netId _ammobox]];

sleep 60;
{
	deleteVehicle _x;
} foreach units _group;

deleteVehicle _vehicle;