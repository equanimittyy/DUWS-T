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

// One-time use: a shore was found and the taxi is committed, so spend it. Deferred to here so the
// no-shore exit above leaves the item for the player to keep.
["boat_taxi"] call fnc_support_consume;

// A POS NEAR THE PLAYER HAS BEEN FOUND, GUNBOAT EN ROUTE

// create marker on LZ
_markerpickup = format["lz%1%2",_foundPickupPos]; // Define marker name
_markerstr = createMarker [str(_markerpickup), _foundPickupPos];
_markerstr setMarkerShape "ICON";
str(_markerpickup) setMarkerType "hd_end";
str(_markerpickup) setMarkerColor "ColorGreen";
str(_markerpickup) setMarkerText "PICKUP";
_speakeracteam = localize "STR_DUWS_T_actionteam";
_message = localize "STR_DUWS_T_boattaxicall0";
[_speakeracteam, _message, "", name player] remoteExec ["fnc_duws_dialogue", 0];
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = format[localize "STR_DUWS_T_boattaxicall1", localize "STR_DUWS_T_swordfish"];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
_speaker = localize "STR_DUWS_T_swordfish";
_message = localize "STR_DUWS_T_boattaxicall";
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

// find a pos where to create the boat
_spawnPos = [_posplayer, 400,500,10,2,5,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;

// create the boat
_boat = createVehicle [blufor_BOAT_TRANS_X, _spawnPos,[], 0, "FLY"];
_boatgroup = createGroup west; 
_pilot = _boatgroup createUnit [blufor_MARK_SOLDIER_X, [5,5,5], [], 0, "NONE"];
_boatgroup deleteGroupWhenEmpty true;
_boat addAction [ACT_MOVE("STR_DUWS_T_boattaxi_action_dest"), fnc_mapclickboat, [], 70, true, true, "", "vehicle _this == _target"];
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
    [localize "STR_DUWS_T_OVERLORD", localize _msg] remoteExec ["fnc_duws_dialogue", 0];
    [_boat, _boatgroup, 45, false] call fnc_support_despawn;
};

_wp = _boatgroup addWaypoint [[_foundPickupPos select 0, (_foundPickupPos select 1)-75], 0];
_wp setWaypointType "MOVE";
[_boatgroup, 1] setWaypointCombatMode "BLUE";


waitUntil {_foundpickuppos distance _boat < 350 or (getdammage _boat > 0.7 or !alive _pilot)}; // wait until the helo is near the lz
if (getdammage _boat > 0.7 or !alive _pilot) exitWith { call _abort };

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

if (getdammage _boat > 0.7 or !alive _pilot) exitWith { call _abort };


// everything is ok, player is in boat
playMusic [_music, 0];
_boat lock true;
[localize "STR_DUWS_T_swordfish", localize "STR_DUWS_T_boattaxi_oscarmike"] remoteExec ["fnc_duws_dialogue", 0];
str(_markerpickup) setMarkerPos ClickedTaxiPos; 
str(_markerpickup) setMarkerText "DROP POINT";




if (getdammage _boat > 0.7 or !alive _pilot) exitWith { call _abort };

// TELEPORT BOAT NEAR DROP POINT. The fade masks the hop; the pilot's call goes through the
// dialogue system rather than riding the fade's text slot.
titleCut ["", "BLACK OUT", 3];
[localize "STR_DUWS_T_swordfish", localize "STR_DUWS_T_boattaxi_enroute"] remoteExec ["fnc_duws_dialogue", 0];
_teleportPoint = [ClickedTaxiPos, 400,500,10,2,5,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;
sleep 3.5;
_boat setpos _teleportPoint;
// tell the boat to go at wp
_wp = _boatgroup addWaypoint [ClickedTaxiPos,0];
_wp setWaypointType "MOVE";
[_boatgroup, 1] setWaypointCombatMode "BLUE";
sleep 3;
titleCut ["", "BLACK IN", 4];
_boat lock false;


waitUntil {sleep 0.5;ClickedTaxiPos distance _boat < 200  or (getdammage _boat > 0.7 or !alive _pilot)}; // wait until the boat is near the shore
if (getdammage _boat > 0.7 or !alive _pilot) exitWith { call _abort };


// time to move ppl out of the boat;
waitUntil {sleep 0.5;(getpos _boat select 2 < 4 && _boat distance ClickedTaxiPos<20)  or (getdammage _boat > 0.7 or !alive _pilot)}; // wait until the boat is near shore
if (getdammage _boat > 0.7 or !alive _pilot) exitWith { call _abort };
[localize "STR_DUWS_T_swordfish", localize "STR_DUWS_T_boattaxi_arrived"] remoteExec ["fnc_duws_dialogue", 0];

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
if (getdammage _boat > 0.7 or !alive _pilot) exitWith { ["STR_DUWS_T_boattaxi_rtbdown"] call _abort };


[_boat, _boatgroup, 118, false] call fnc_support_despawn;
