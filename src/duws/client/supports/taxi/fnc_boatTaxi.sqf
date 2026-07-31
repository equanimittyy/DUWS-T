// Locality: client; the addAction bodies below run on the machine that triggers them, not
// here (invoked from the comm menu, shared/includes/supports_radio_modern.hpp:177).
#include "..\..\..\shared\includes\action_style.hpp"

_posplayer = _this select 0;
_radius = _this select 1;

_foundPickupPos = [];
taxiCanTakeOff = false;

_music = [] call fnc_taxi_music;

_foundPickupPos = [_posplayer, 0,_radius,10,2,5,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos; // find a valid pos

// try to find a pos, if no pos is found exit the script
if (0 == _foundPickupPos select 0 && 0 == _foundPickupPos select 1) exitWith {hint localize "STR_DUWS_T_boattaxi_noshore"; sleep 10; ["boat_taxi"] call fnc_support_comm_add;};

// A POS NEAR THE PLAYER HAS BEEN FOUND, GUNBOAT EN ROUTE

// create marker on LZ
_markerpickup = format["lz%1%2",_foundPickupPos]; // Define marker name
_markerstr = createMarker [str(_markerpickup), _foundPickupPos];
_markerstr setMarkerShape "ICON";
str(_markerpickup) setMarkerType "hd_end";
str(_markerpickup) setMarkerColor "ColorGreen";
str(_markerpickup) setMarkerText "PICKUP";
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = ([localize "STR_DUWS_T_boattaxicall"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

// find a pos where to create the boat
_spawnPos = [_posplayer, 400,500,10,2,5,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;

// create the boat
_boat = createVehicle ["B_Boat_Transport_01_F", _spawnPos,[], 0, "FLY"];
_boatgroup = createGroup west; 
_pilot = _boatgroup createUnit [blufor_MARKSMAN_X, [5,5,5], [], 0, "NONE"];
_boatgroup deleteGroupWhenEmpty true;
_boat addAction [ACT_MOVE("STR_DUWS_T_boattaxi_action_dest"), fnc_mapclickboat, [], 70, true, true, "", "vehicle _this == _target"];
_pilot setcaptive true; 
_pilot moveindriver _boat;


// Single teardown for every failure below. The six copies this replaces had drifted: two
// forgot to clear the pickup marker, so a boat lost on the run-in left it on the map for
// the rest of the campaign. Unlock and deleteMarker are no-ops when already done, so one
// handler is safe on every path.
_abort = {
    // Message is a parameter so the return leg can report a completed extraction rather
    // than apologise for one; everything else about the teardown is identical.
    params [["_msg", "STR_DUWS_T_boattaxi_damaged"]];
    _boat lock false;
    deleteMarker str(_markerpickup);
    [localize "STR_DUWS_T_OVERLORD", ([localize _msg] call fnc_cs)] remoteExec ["fnc_duws_dialogue", 0];
    sleep 300;
    ["boat_taxi"] call fnc_support_comm_add;
};

_wp = _boatgroup addWaypoint [[_foundPickupPos select 0, (_foundPickupPos select 1)-75], 0];
_wp setWaypointType "MOVE";
[_boatgroup, 1] setWaypointCombatMode "BLUE";


waitUntil {_foundpickuppos distance _boat < 350 or (getdammage _boat > 0.7 or !alive _pilot)}; // wait until the helo is near the lz
// IF THE PILOT IS DEAD OR BOAT SUNK ******************
if (getdammage _boat > 0.7 or !alive _pilot) exitWith { call _abort };
// ****************************************************

_inVehCheck = true;
while {_inVehCheck} do {
waitUntil {sleep 0.5;taxiCanTakeOff or (getdammage _boat > 0.7 or !alive _pilot)}; // wait until the player has given a validpos
if (getdammage _boat > 0.7 or !alive _pilot) exitWith {}; // get out of the loop if choopa is down
// check if player is inside choppa
if (vehicle player != _boat) then {
	taxiCanTakeOff = false; 
	[localize "STR_DUWS_T_swordfish", localize "STR_DUWS_T_boattaxi_notaboard"] remoteExec ["fnc_duws_dialogue", 0];
	_boat addAction [ACT_MOVE("STR_DUWS_T_boattaxi_action_loc"), fnc_mapclickboat, [], 70, true, true, "", "vehicle _this == _target"];
} else {
	_inVehCheck = false;};
};

// IF THE PILOT IS DEAD OR GUNBOAT DOWN  **************
if (getdammage _boat > 0.7 or !alive _pilot) exitWith { call _abort };
// *****************************


// everything is ok, player is in boat
playMusic [_music, 0];
_boat lock true;
titleText [localize "STR_DUWS_T_boattaxi_oscarmike", "PLAIN DOWN"];
str(_markerpickup) setMarkerPos ClickedTaxiPos; 
str(_markerpickup) setMarkerText "DROP POINT";




// IF THE PILOT IS DEAD OR BOAT SUNK  **************
if (getdammage _boat > 0.7 or !alive _pilot) exitWith { call _abort };
// *****************************

// TELEPORT BOAT NEAR DROP POINT
titleText [localize "STR_DUWS_T_boattaxi_enroute", "BLACK OUT", 3];
_teleportPoint = [ClickedTaxiPos, 400,500,10,2,5,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;
sleep 3.5;
_boat setpos _teleportPoint;
// tell the boat to go at wp
_wp = _boatgroup addWaypoint [ClickedTaxiPos,0];
_wp setWaypointType "MOVE";
[_boatgroup, 1] setWaypointCombatMode "BLUE";
sleep 3;
titleText [localize "STR_DUWS_T_boattaxi_enroute", "BLACK IN", 4];
_boat lock false;


waitUntil {sleep 0.5;ClickedTaxiPos distance _boat < 200  or (getdammage _boat > 0.7 or !alive _pilot)}; // wait until the boat is near the shore
// IF THE PILOT IS DEAD OR GUNBOAT DOWN  **************
if (getdammage _boat > 0.7 or !alive _pilot) exitWith { call _abort };
// *****************************


// time to move ppl out of the boat;
waitUntil {sleep 0.5;(getpos _boat select 2 < 4 && _boat distance ClickedTaxiPos<20)  or (getdammage _boat > 0.7 or !alive _pilot)}; // wait until the boat is near shore
// IF THE PILOT IS DEAD OR GUNBOAT DOWN  **************
if (getdammage _boat > 0.7 or !alive _pilot) exitWith { call _abort };
// *****************************
titleText [localize "STR_DUWS_T_boattaxi_arrived", "PLAIN DOWN"];

// Same turn-out as the helo taxi, and for the same reasons: doGetOut is an order only AI take, so
// the caller was never moved, and passengers outside the caller's group were never considered.
// moveOut needs its unit local, hence the hop to each passenger's owner. The pilot is excluded.
{
	if (_x != _pilot) then {
		_x remoteExec ["moveOut", _x];
		sleep 1;
	};
} forEach crew _boat;

sleep 40;
[localize "STR_DUWS_T_swordfish", localize "STR_DUWS_T_boattaxi_rtb"] remoteExec ["fnc_duws_dialogue", 0];
_wp = _boatgroup addWaypoint [_teleportPoint,0];   // tell the helo to leave
_wp setWaypointType "MOVE";
deleteMarker str(_markerpickup);


waitUntil {_boat distance player>100 or (getdammage _boat > 0.7 or !alive _pilot)}; // wait until the helo is near the ground
// IF THE PILOT IS DEAD OR GUNBOAT DOWN  **************
if (getdammage _boat > 0.7 or !alive _pilot) exitWith { ["STR_DUWS_T_boattaxi_rtbdown"] call _abort };
// *****************************


sleep 118;

deleteVehicle _pilot;
deleteVehicle _boat;


sleep 2;   // spacer: 118 + 2 = the 120s success cooldown
["boat_taxi"] call fnc_support_comm_add;
