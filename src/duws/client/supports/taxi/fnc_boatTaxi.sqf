// Locality: client; the addAction bodies below run on the machine that triggers them, not
// here (invoked from the comm menu, shared/includes/supports_radio_modern.hpp:177).
_posplayer = _this select 0;
_radius = _this select 1;

_foundPickupPos = [];
taxiCanTakeOff = false;

_music = [] call fnc_taxi_music;

_foundPickupPos = [_posplayer, 0,_radius,10,2,5,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos; // find a valid pos

// try to find a pos, if no pos is found exit the script
if (0 == _foundPickupPos select 0 && 0 == _foundPickupPos select 1) exitWith {hint "You must be near a clear shoreline or out at sea"; sleep 5; _art = [player,"boat_taxi"] call BIS_fnc_addCommMenuItem;};

// A POS NEAR THE PLAYER HAS BEEN FOUND, GUNBOAT EN ROUTE

// create marker on LZ
_markerpickup = format["lz%1%2",_foundPickupPos]; // Define marker name
_markerstr = createMarker [str(_markerpickup), _foundPickupPos];
_markerstr setMarkerShape "ICON";
str(_markerpickup) setMarkerType "hd_end";
str(_markerpickup) setMarkerColor "ColorGreen";
str(_markerpickup) setMarkerText "Pickup";
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = ([localize "STR_DUWS_T_boattaxicall"] call fnc_cs);
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];

// find a pos where to create the boat
_spawnPos = [_posplayer, 400,500,10,2,5,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;

// create the boat
_boat = createVehicle ["B_Boat_Transport_01_F", _spawnPos,[], 0, "FLY"];
_boatgroup = createGroup west; 
_pilot = _boatgroup createUnit [blufor_MARKSMAN_X, [5,5,5], [], 0, "NONE"];
_boatgroup deleteGroupWhenEmpty true;
_boat addAction ["<t color='#00b7ff'>Tell the driver where to go</t>", fnc_mapclickboat, "", 0, true, true, "", "vehicle _this == _target"];
_pilot setcaptive true; 
_pilot moveindriver _boat;


_wp = _boatgroup addWaypoint [[_foundPickupPos select 0, (_foundPickupPos select 1)-75], 0];
_wp setWaypointType "MOVE";
[_boatgroup, 1] setWaypointCombatMode "BLUE";


waitUntil {_foundpickuppos distance _boat < 350 or (getdammage _boat > 0.7 or !alive _pilot)}; // wait until the helo is near the lz
// IF THE PILOT IS DEAD OR BOAT SUNK ******************
if (getdammage _boat > 0.7 or !alive _pilot) exitWith {
deleteMarker str(_markerpickup);
hint format["Swordfish 1-1 is too damaged to continue the mission",_fobname];
// --- AJOUTER DE NOUVEAU LE SUPPORT
sleep 15;
_art = [player,"boat_taxi"] call BIS_fnc_addCommMenuItem;
}; 
// ****************************************************

_inVehCheck = true;
while {_inVehCheck} do {
waitUntil {sleep 0.5;taxiCanTakeOff or (getdammage _boat > 0.7 or !alive _pilot)}; // wait until the player has given a validpos
if (getdammage _boat > 0.7 or !alive _pilot) exitWith {}; // get out of the loop if choopa is down
// check if player is inside choppa
if (vehicle player != _boat) then {
	taxiCanTakeOff = false; 
	[format["This is Swordfish 1-1, get back in, I can't transport you're not inside the boat !",_fobname]] spawn fnc_sideChat_filter; 
	_boat addAction ["<t color='#00b7ff'>Give a location to the pilot</t>", fnc_mapclickboat, "", 0, true, true, "", "vehicle _this == _target"];
} else {
	_inVehCheck = false;};
};

// IF THE PILOT IS DEAD OR GUNBOAT DOWN  **************
if (getdammage _boat > 0.7 or !alive _pilot) exitWith {
deleteVehicle _helipad1;
deleteMarker str(_markerpickup);
hint format["Swordfish 1-1 is too damaged to continue the mission",_fobname,_random1,_random2];
sleep 15;
_art = [player,"boat_taxi"] call BIS_fnc_addCommMenuItem;
// --- AJOUTER DE NOUVEAU LE SUPPORT
}; 
// *****************************


// everything is ok, player is in boat
playMusic [_music, 0];
_boat lock true;
titleText ["Driver: Roger that, we're oscar mike...", "PLAIN DOWN"];
str(_markerpickup) setMarkerPos ClickedTaxiPos; 
str(_markerpickup) setMarkerText "Drop point";



_actualboatpos = getpos player;

// IF THE PILOT IS DEAD OR BOAT SUNK  **************
if (getdammage _boat > 0.7 or !alive _pilot) exitWith {
	_boat lock false;
	deleteMarker str(_markerpickup);
	hint format["Swordfish 1-1 is too damaged to continue the mission",_fobname,_random1,_random2];
	// --- AJOUTER DE NOUVEAU LE SUPPORT
	sleep 15;
	_art = [player,"boat_taxi"] call BIS_fnc_addCommMenuItem;
}; 
// *****************************

// TELEPORT BOAT NEAR DROP POINT
titleText ["En route to drop point...", "BLACK OUT", 3];
_teleportPoint = [ClickedTaxiPos, 400,500,10,2,5,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;
sleep 3.5;
_boat setpos _teleportPoint;
// tell the boat to go at wp
_wp = _boatgroup addWaypoint [ClickedTaxiPos,0];
_wp setWaypointType "MOVE";
[_boatgroup, 1] setWaypointCombatMode "BLUE";
sleep 3;
titleText ["En route to drop point...", "BLACK IN", 4];
_boat lock false;


waitUntil {sleep 0.5;ClickedTaxiPos distance _boat < 200  or (getdammage _boat > 0.7 or !alive _pilot)}; // wait until the boat is near the shore
// IF THE PILOT IS DEAD OR GUNBOAT DOWN  **************
if (getdammage _boat > 0.7 or !alive _pilot) exitWith {
deleteVehicle _helipad;
_boat lock false;
deleteMarker str(_markerpickup);
hint format["Swordfish 1-1 is too damaged to continue the mission",_fobname,_random1,_random2];
// --- AJOUTER DE NOUVEAU LE SUPPORT
sleep 15;
_art = [player,"boat_taxi"] call BIS_fnc_addCommMenuItem;
}; 
// *****************************


// time to move ppl out of the boat;
waitUntil {sleep 0.5;(getpos _boat select 2 < 4 && _boat distance ClickedTaxiPos<20)  or (getdammage _boat > 0.7 or !alive _pilot)}; // wait until the boat is near shore
// IF THE PILOT IS DEAD OR GUNBOAT DOWN  **************
if (getdammage _boat > 0.7 or !alive _pilot) exitWith {
deleteVehicle _helipad;
_boat lock false;
hint format["Swordfish 1-1 is too damaged to continue the mission",_fobname,_random1,_random2];
// --- AJOUTER DE NOUVEAU LE SUPPORT
sleep 15;
_art = [player,"boat_taxi"] call BIS_fnc_addCommMenuItem;
}; 
// *****************************
titleText ["Driver: We've arrived at the drop point", "PLAIN DOWN"];

{doGetOut _x; sleep 1;} forEach units group player;

sleep 40;
[format["This is Swordfish 1-1, I'm RTB",_fobname]] spawn fnc_sideChat_filter;
_wp = _boatgroup addWaypoint [_teleportPoint,0];   // tell the helo to leave
_wp setWaypointType "MOVE";
deleteMarker str(_markerpickup);


waitUntil {_boat distance player>100 or (getdammage _boat > 0.7 or !alive _pilot)}; // wait until the helo is near the ground
// IF THE PILOT IS DEAD OR GUNBOAT DOWN  **************
if (getdammage _boat > 0.7 or !alive _pilot) exitWith {
hint format["Swordfish 1-1 is too damaged to continue the mission",_fobname,_random1,_random2];
// --- AJOUTER DE NOUVEAU LE SUPPORT
sleep 15;
_art = [player,"boat_taxi"] call BIS_fnc_addCommMenuItem;
}; 
// *****************************


sleep 200;

deleteVehicle _pilot;
deleteVehicle _boat;


sleep 2;
_art = [player,"boat_taxi"] call BIS_fnc_addCommMenuItem;
