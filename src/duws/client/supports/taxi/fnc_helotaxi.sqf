// Locality: client; the addAction bodies below run on the machine that triggers them, not
// here (invoked from the comm menu, shared/includes/supports_radio_modern.hpp:157).

#include "..\..\..\shared\includes\action_style.hpp"

_posplayer = _this select 0;
_radius = _this select 1;
_foundPickupPos = [];
taxiCanTakeOff = false;
_helo_maxDamage = 0.7;
_helo_minFuel = 0.4;
_music = [] call fnc_taxi_music;

_foundPickupPos = [_posplayer, 20,_radius,20,0,0.5,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;

if (0 == _foundPickupPos select 0 && 0 == _foundPickupPos select 1) exitWith {hint localize "STR_DUWS_T_nolz"; sleep 10; ["helo_taxi"] call fnc_support_comm_add;};

// One-time use: an LZ was found and the taxi is committed, so spend it. Deferred to here so the
// no-LZ exit above leaves the item for the player to keep.
["helo_taxi"] call fnc_support_consume;

_speakeracteam = localize "STR_DUWS_T_actionteam";
_message = localize "STR_DUWS_T_helotaxicall0";
[_speakeracteam, _message, "", name player] remoteExec ["fnc_duws_dialogue", 0];
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = format[localize "STR_DUWS_T_helotaxicall1", localize "STR_DUWS_T_chariot"];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
_speaker = localize "STR_DUWS_T_chariot";
_message = localize "STR_DUWS_T_helotaxicall";
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

_markerpickup = format["lz%1%2",_foundPickupPos];
_markerstr = createMarker [str(_markerpickup), _foundPickupPos];
_markerstr setMarkerShape "ICON";
str(_markerpickup) setMarkerType "hd_end";
str(_markerpickup) setMarkerColor "ColorGreen";
str(_markerpickup) setMarkerText "LZ";

_vehpos = _posplayer;
_vec =[random [-1,0,1], random [-1,0,1], 0];
_dist = 2000;
_vehpos = ((vectorNormalized _vec) vectorMultiply _dist) vectorAdd _vehpos;

_veh = [_vehpos,0,blufor_TRANS_HELI_X,WEST] call bis_fnc_spawnvehicle;

_helo = _veh select 0 ;// vehicle object
_helo setPos [_vehpos select 0, _vehpos select 1, 200];// set height

_helo flyInHeight 50;
_helo addAction [ACT_MOVE("STR_DUWS_T_helotaxi_action_wp"), fnc_mapclickhelo, [], 70, true, true, "", "vehicle _this == _target"];
 
_heloGroup = _veh select 2;
_heloGroup deleteGroupWhenEmpty true;

_pilot = currentPilot _helo;
_pilot allowfleeing 0;
_pilot disableAI "Target";
// Cosmetic taxi: hold fire and don't acquire, so the crew flies the ferry instead of engaging.
_pilot disableAI "AUTOTARGET";
_heloGroup setCombatMode "BLUE";

// Disable VCOM on CREW
{
	_x setVariable ["Vcm_Disable",true];
} forEach units _heloGroup;

_helipad1 = createVehicle ["Land_HelipadEmpty_F", _foundPickupPos, [], 0, "NONE"]; 
_wp = _helogroup addWaypoint [_foundPickupPos, 0];
_wp setWaypointType "MOVE";
[_helogroup, 1] setWaypointCombatMode "BLUE";



// check damage and exit function
_check_damage = compile "((vehicle _pilot == _pilot) or (damage _helo > _helo_maxDamage) or (fuel _helo < _helo_minFuel))";
_abort = {
	params ["_helo","_helogroup","_helipad1","_markerpickup"];
	deleteVehicle _helipad1;
	deleteMarker str(_markerpickup);
	_message = format[localize "STR_DUWS_T_helotaxidamaged", localize "STR_DUWS_T_chariot"];
	_speaker = localize "STR_DUWS_T_OVERLORD";
	[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
	[_helo, _helogroup, 45, true] call fnc_support_despawn;
};

waitUntil {sleep 0.5;(_foundpickuppos distance _helo < 350) or (call _check_damage)}; 

if (call _check_damage) exitWith {
	[_helo,_helogroup,_helipad1,_markerpickup] spawn _abort;
}; 

_smokePos = [_foundpickuppos select 0, (_foundpickuppos select 1)+ random 5];
"SmokeShellGreen" createVehicle _smokePos;
"Chemlight_green" createVehicle _smokePos;

_helo land "GET IN";

_pickupSpawnopen = [_helo,_foundpickuppos] spawn {
	_helo = _this select 0;
	_lzPos = _this select 1;
	waitUntil {sleep 0.5;getpos _helo distance _lzPos < 10};
	sleep 1;
	_helo animateDoor ['door_R', 1];
	sleep 3;
	_helo animateDoor ['door_L', 1];
};

_inVehCheck = true;
while {_inVehCheck} do {
	waitUntil {sleep 0.5;vehicle player == _helo or (call _check_damage)};
	sleep 1;
	if (call _check_damage) exitWith {}; 

	hint localize "STR_DUWS_T_pilotwp";
	_message = localize "STR_DUWS_T_pilotwhere";
	_speaker = localize "STR_DUWS_T_chariot";
	[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
	waitUntil {sleep 0.5;taxiCanTakeOff or (call _check_damage)};
	sleep 1;
	if (call _check_damage) exitWith {}; 
	if (vehicle player != _helo) then {
		taxiCanTakeOff = false; 
		[localize "STR_DUWS_T_chariot", localize "STR_DUWS_T_helotaxi_notaboard"] remoteExec ["fnc_duws_dialogue", 0];
		_helo addAction [ACT_MOVE("STR_DUWS_T_helotaxi_action_lz"), fnc_mapclickhelo, [], 70, true, true, "", "vehicle _this == _target"];
	} else {
		_inVehCheck = false;
	};
};

if (call _check_damage) exitWith {
	[_helo,_helogroup,_helipad1,_markerpickup] spawn _abort;
}; 

playMusic [_music, 0];
_helo setEffectiveCommander player;  // turn helo "blue" while player is on board.

	_message = localize "STR_DUWS_T_helotaxioscmk";
	_speaker = localize "STR_DUWS_T_chariot";
	[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
str(_markerpickup) setMarkerPos ClickedTaxiPos;
sleep 2;
openMap false;
hint "";

_helipad = createVehicle ["Land_HelipadEmpty_F", ClickedTaxiPos, [], 0, "NONE"];
_wp1 = _helogroup addWaypoint [getMarkerPos str(Taximarker1),0];
_wp1 setWaypointType "MOVE";
_wp1 setWaypointStatements ["true", "deleteMarker str(Taximarker1)"]; 
_wp2 = _helogroup addWaypoint [getMarkerPos str(Taximarker2),0];
_wp2 setWaypointType "MOVE";
_wp2 setWaypointStatements ["true", "deleteMarker str(Taximarker2)"]; 
_wp3 = _helogroup addWaypoint [ClickedTaxiPos,0];
_wp3 setWaypointType "MOVE";
[_helogroup, 1] setWaypointCombatMode "BLUE";

_pickupSpawnclose = [_helo,_foundpickuppos] spawn {
	_helo = _this select 0;
	_lzPos = _this select 1;
	waitUntil {sleep 0.5;getpos _helo distance _lzPos > 10};
	sleep 1;
	_helo animateDoor ['door_R', 0];
	sleep 3;
	_helo animateDoor ['door_L', 0];
};

waitUntil {sleep 0.5;_helo distance _helipad1 > 350 or (call _check_damage)};
sleep 1;

if (call _check_damage) exitWith {
	[_helo,_helogroup,_helipad1,_markerpickup] spawn _abort;
	deleteVehicle _helipad;
	_helo lock false;
	deleteMarker str(Taximarker1);
	deleteMarker str(Taximarker2);
}; 

waitUntil {sleep 0.5;ClickedTaxiPos distance _helo < 350  or (call _check_damage)}; 
sleep 1;

if (call _check_damage) exitWith {
	[_helo,_helogroup,_helipad1,_markerpickup] spawn _abort;
	deleteVehicle _helipad;
	_helo lock false;
	deleteMarker str(Taximarker1);
	deleteMarker str(Taximarker2);
}; 

_helo land "GET OUT";

_LzSpawnopen = [_helo] spawn {
	_helo = _this select 0;
	waitUntil {sleep 0.5;getpos _helo distance ClickedTaxiPos < 20};
	sleep 1;
	_helo animateDoor ['door_R', 1];
	sleep 3;
	_helo animateDoor ['door_L', 1];
};


// time to move ppl out of the helo;
waitUntil {sleep 0.5;(getposATL _helo select 2 < 4) or (call _check_damage)};
sleep 1;

_helo setEffectiveCommander _pilot;

if (call _check_damage) exitWith {
	[_helo,_helogroup,_helipad1,_markerpickup] spawn _abort;
	deleteVehicle _helipad;
	_helo lock false;
	deleteMarker str(Taximarker1);
	deleteMarker str(Taximarker2);
}; 

	_message = localize "STR_DUWS_T_helotaxiarrival";
	_speaker = localize "STR_DUWS_T_chariot";
	[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
_helo lock false;
// Everyone the taxi carried, not just the caller's group. doGetOut is an order only AI take, so the
// player who called the taxi was the one passenger it never turned out, and anyone riding in another
// group stayed seated with them. moveOut needs its unit local, so each passenger is turned out on
// the machine that owns them. The flight crew is excluded or the helo is abandoned at the LZ.
{
	if !(_x in units _helogroup) then {
		_x remoteExec ["moveOut", _x];
		sleep 1;
	};
} forEach crew _helo;

sleep 12;

_wp = _helogroup addWaypoint [[0,0,0],0];   // tell the helo to leave
_wp setWaypointType "MOVE";
deleteMarker str(_markerpickup);
deleteVehicle _helipad;
playMusic "";

_LzSpawnclose = [_helo] spawn {
	_helo = _this select 0;
	sleep 2;
	_helo animateDoor ['door_R', 0];
	sleep 3;
	_helo animateDoor ['door_L', 0];
};

waitUntil {sleep 0.5;_helo distance player > 100 or (call _check_damage)};
sleep 1;

if (call _check_damage) exitWith {
	_message = format[localize "STR_DUWS_T_helotaxirtbdown", localize "STR_DUWS_T_chariot"];
	_speaker = localize "STR_DUWS_T_OVERLORD";
	[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
	[_helo, _helogroup, 45, true] call fnc_support_despawn;
};

	_message = localize "STR_DUWS_T_helotaxirtb";
	_speaker = localize "STR_DUWS_T_chariot";
	[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

sleep 118;

terminate _pickupSpawnopen;
terminate _pickupSpawnclose;
terminate _LzSpawnopen;
terminate _LzSpawnclose;

[_helo, _helogroup] call fnc_support_despawn;
