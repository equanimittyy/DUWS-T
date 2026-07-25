// Locality: client; the addAction bodies below run on the machine that triggers them, not
// here (invoked from the comm menu, shared/includes/supports_radio_modern.hpp:157).

_posplayer = _this select 0;
_radius = _this select 1;
_foundPickupPos = [];
taxiCanTakeOff = false;
_helo_maxDamage = 0.7;
_helo_minFuel = 0.4;
// Dedicated callsign, not a random roll. A support you request answers as the element
// lead, so the digits are fixed at 1-1 and stay the same every time it is called.
_taxiName = "Chariot";
_random1 = 1;
_random2 = 1;
_music = [] call fnc_taxi_music;

_foundPickupPos = [_posplayer, 20,_radius,20,0,0.5,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos; // find a valid pos

// try to find a pos, if no pos is found exit the script
if (0 == _foundPickupPos select 0 && 0 == _foundPickupPos select 1) exitWith {hint localize "STR_DUWS_T_nolz"; sleep 10; _art = [player,"helo_taxi"] call BIS_fnc_addCommMenuItem;};

// A POS NEAR THE PLAYER HAS BEEN FOUND, CHOPPA EN ROUTE
_speakeracteam = ([localize "STR_DUWS_T_actionteam"] call fnc_cs);
_message = ([localize "STR_DUWS_T_helotaxicall0"] call fnc_cs);
[_speakeracteam, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 8;
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = format[localize "STR_DUWS_T_helotaxicall1",_taxiName,_random1,_random2];
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 8;
_speaker = localize "STR_DUWS_T_pilot";
_message = ([localize "STR_DUWS_T_helotaxicall"] call fnc_cs);
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];

// create marker on LZ
_markerpickup = format["lz%1%2",_foundPickupPos]; // Define marker name
_markerstr = createMarker [str(_markerpickup), _foundPickupPos];
_markerstr setMarkerShape "ICON";
str(_markerpickup) setMarkerType "hd_end";
str(_markerpickup) setMarkerColor "ColorGreen";
str(_markerpickup) setMarkerText "LZ";

////////////////////////////////////////////
//   SPAWN THE HELO
///////////////////////////////////////////

_vehpos = _posplayer;
_vec =[random [-1,0,1], random [-1,0,1], 0];
_dist = 2000;
_vehpos = ((vectorNormalized _vec) vectorMultiply _dist) vectorAdd _vehpos;

_veh = [_vehpos,0,blufor_HELI_TRANS_UNARM_X,WEST] call bis_fnc_spawnvehicle;

_helo = _veh select 0 ;// vehicle object
_helo setPos [_vehpos select 0, _vehpos select 1, 200];// set height
//_helo setvelocity [0,0,200];

_helo flyInHeight 50;
_helo addAction ["<t color='#00ff00' size='2'>Give Waypoints to the pilot</t>", fnc_mapclickhelo, "", 0, true, true, "", "vehicle _this == _target"];
 
_heloGroup = _veh select 2;
_heloGroup deleteGroupWhenEmpty true;
//_pilot = units _helogroup select 0;
//_copilot = units _helogroup select 1;
//_gunner1 = units _helogroup select 2;
//_gunner2 = units _helogroup select 3;

_pilot = currentPilot _helo;
_pilot setcaptive true;
_pilot allowfleeing 0;
_pilot disableAI "Target"; 
_pilot allowDamage false;

// Disable VCOM on CREW
{
	_x setVariable ["Vcm_Disable",true];
} forEach units _heloGroup;

///////////////
//  HELI PAD
///////////////

// create the helipad to land and the waypoints
_helipad1 = createVehicle ["Land_HelipadEmpty_F", _foundPickupPos, [], 0, "NONE"]; 
_wp = _helogroup addWaypoint [_foundPickupPos, 0];
_wp setWaypointType "MOVE";
[_helogroup, 1] setWaypointCombatMode "BLUE";



hint localize "STR_DUWS_T_helotaxichopperinbound";

// check damage and exit function
_check_damage = compile "((vehicle _pilot == _pilot) or (damage _helo > _helo_maxDamage) or (fuel _helo < _helo_minFuel))";
_abort = {
	params ["_helo","_helogroup","_helipad1","_markerpickup","_taxiName","_random1","_random2"];
	deleteVehicle _helipad1;
	deleteMarker str(_markerpickup);
	_message = format[([localize "STR_DUWS_T_helotaxidamaged"] call fnc_cs),_taxiName,_random1,_random2];
	_speaker = localize "STR_DUWS_T_OVERLORD";
	[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
    [] remoteExec ["fnc_broadcastRadioChatter", 0];
	_helo land "LAND";
	_helo engineOn false;
	sleep 300;
	_art = [player,"helo_taxi"] call BIS_fnc_addCommMenuItem;
	{deleteVehicle _x;} foreach units _helogroup;
	deleteVehicle _helo;
};

// wait until the helo is near the lz
waitUntil {sleep 0.5;(_foundpickuppos distance _helo < 350) or (call _check_damage)}; 

// IF THE CHOPPA IS DOWN/DAMAGED  **************
if (call _check_damage) exitWith {
	[_helo,_helogroup,_helipad1,_markerpickup,_taxiName,_random1,_random2] spawn _abort;
}; 

////////////////////
// LAND THE HELO
////////////////////

// spawn smokeshell
_smokePos = [_foundpickuppos select 0, (_foundpickuppos select 1)+ random 5];
_smoke = "SmokeShellGreen" createVehicle _smokePos;
_chemlight = "Chemlight_green" createVehicle _smokePos;

_helo land "GET IN";

// spawn the door opening script
_pickupSpawnopen = [_helo,_foundpickuppos] spawn {
	_helo = _this select 0;
	_lzPos = _this select 1;
	waitUntil {sleep 0.5;getpos _helo distance _lzPos < 10};
	sleep 1;
	_helo animateDoor ['door_R', 1];
	sleep 3;
	_helo animateDoor ['door_L', 1];
};

// WAIT FOR PLAYER TO GET IN
_inVehCheck = true;
while {_inVehCheck} do {
	// wait until the player is in choppa or pilot not in choppa
	waitUntil {sleep 0.5;vehicle player == _helo or (call _check_damage)};
	sleep 1;
	// get out of the loop if choppa is down
	if (call _check_damage) exitWith {}; 

	hint localize "STR_DUWS_T_pilotwp";
	_message = localize "STR_DUWS_T_pilotwhere";
	_speaker = localize "STR_DUWS_T_pilot";
	[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
    [] remoteExec ["fnc_broadcastRadioChatter", 0];
	// wait until the player has given a validpos or pilot not in choppa
	waitUntil {sleep 0.5;taxiCanTakeOff or (call _check_damage)};
	sleep 1;
	// get out of the loop if choppa is down
	if (call _check_damage) exitWith {}; 
	// check if player is inside choppa
	if (vehicle player != _helo) then {
		taxiCanTakeOff = false; 
		player globalChat format["This is %1 %2-%3, get back in, I can't transport if you're not inside the chopper !",_taxiName,_random1,_random2];
		_helo addAction ["<t color='#00ff00'>Give an LZ to the pilot</t>", fnc_mapclickhelo, "", 0, true, true, "", "vehicle _this == _target"];
		[] remoteExec ["fnc_broadcastRadioChatter", 0];
	} else {
		_inVehCheck = false;
	};
};

// IF THE CHOPPA IS DOWN/DAMAGED  **************
if (call _check_damage) exitWith {
	[_helo,_helogroup,_helipad1,_markerpickup,_taxiName,_random1,_random2] spawn _abort;
}; 

// *****************************
//   PLAYER IS IN DA CHOPPA
// *****************************
playMusic [_music, 0];
_helo setEffectiveCommander player;  // turn helo "blue" while player is on board.

//_helo lock true;
	_message = localize "STR_DUWS_T_helotaxioscmk";
	_speaker = localize "STR_DUWS_T_pilot";
	[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
str(_markerpickup) setMarkerPos ClickedTaxiPos; 
sleep 2;   // spacer: 118 + 2 = the 120s success cooldown
openMap false;
hint "";

// create the helipad to land and the waypoints

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

// spawn the door closing script
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

// IF THE CHOPPA IS DOWN/DAMAGED  **************
if (call _check_damage) exitWith {
	[_helo,_helogroup,_helipad1,_markerpickup,_taxiName,_random1,_random2] spawn _abort;
	deleteVehicle _helipad;
	_helo lock false;
	deleteMarker str(Taximarker1);
	deleteMarker str(Taximarker2);
}; 

// *****************************

// wait until the helo is near the lz
waitUntil {sleep 0.5;ClickedTaxiPos distance _helo < 350  or (call _check_damage)}; 
sleep 1;

// IF THE CHOPPA IS DOWN/DAMAGED  **************
if (call _check_damage) exitWith {
	[_helo,_helogroup,_helipad1,_markerpickup,_taxiName,_random1,_random2] spawn _abort;
	deleteVehicle _helipad;
	_helo lock false;
	deleteMarker str(Taximarker1);
	deleteMarker str(Taximarker2);
}; 

_helo land "GET OUT";

// spawn the door opening script
_LzSpawnopen = [_helo] spawn {
	_helo = _this select 0;
	waitUntil {sleep 0.5;getpos _helo distance ClickedTaxiPos < 20};
	sleep 1;
	_helo animateDoor ['door_R', 1];
	sleep 3;
	_helo animateDoor ['door_L', 1];
};


// time to move ppl out of the helo;
waitUntil {sleep 0.5;(getposATL _helo select 2 < 4) or (call _check_damage)}; // wait until the helo is near the ground
sleep 1;

_helo setEffectiveCommander _pilot;

// IF THE CHOPPA IS DOWN/DAMAGED  **************
if (call _check_damage) exitWith {
	[_helo,_helogroup,_helipad1,_markerpickup,_taxiName,_random1,_random2] spawn _abort;
	deleteVehicle _helipad;
	_helo lock false;
	deleteMarker str(Taximarker1);
	deleteMarker str(Taximarker2);
}; 

	_message = format[localize "STR_DUWS_T_helotaxiarrival",_taxiName,_random1,_random2];
	_speaker = localize "STR_DUWS_T_pilot";
	[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
_helo lock false;
{
	if (vehicle _x == _helo) then {
		doGetOut _x; 
		sleep 1;
	};
} forEach units group player;

sleep 12;  // wait 10 sec before takeoff

_wp = _helogroup addWaypoint [[0,0,0],0];   // tell the helo to leave
_wp setWaypointType "MOVE";
deleteMarker str(_markerpickup);
deleteVehicle _helipad;
playMusic "";

// spawn the door closing script
_LzSpawnclose = [_helo] spawn {
	_helo = _this select 0;
	sleep 2;
	_helo animateDoor ['door_R', 0];
	sleep 3;
	_helo animateDoor ['door_L', 0];
};

waitUntil {sleep 0.5;_helo distance player > 100 or (call _check_damage)}; // wait until the helo is away
sleep 1;

// IF THE CHOPPA IS DOWN/DAMAGED  **************
if (call _check_damage) exitWith {
	_message = format[([localize "STR_DUWS_T_helotaxirtbdown"] call fnc_cs),_taxiName,_random1,_random2];
	_speaker = localize "STR_DUWS_T_OVERLORD";
	[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
	[] remoteExec ["fnc_broadcastRadioChatter", 0];
	sleep 300;
	_art = [player,"helo_taxi"] call BIS_fnc_addCommMenuItem;
	{deleteVehicle _x;} foreach units _helogroup;
	deleteVehicle _helo;
}; 

// *****************************
	_message = format[localize "STR_DUWS_T_helotaxirtb",_taxiName,_random1,_random2];
	_speaker = localize "STR_DUWS_T_pilot";
	[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];

sleep 118;

terminate _pickupSpawnopen;
terminate _pickupSpawnclose;
terminate _LzSpawnopen;
terminate _LzSpawnclose;

{deleteVehicle _x;} foreach units _helogroup;
deleteVehicle _helo;

sleep 2;
_art = [player,"helo_taxi"] call BIS_fnc_addCommMenuItem;
