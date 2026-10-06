// Locality: client; the addAction bodies below run on the machine that triggers them, not
// here (invoked from the comm menu, shared/includes/supports_radio_modern.hpp:177).
#include "..\..\..\shared\includes\action_style.hpp"

taxiCanTakeOff = false;

_music = [] call fnc_taxi_music;

// The drop point's test (fnc_mapclickboat.sqf). The snapped spot leaves through a global because
// findSafePos samples at random, so a second call can land elsewhere or find nothing.
_pick = [localize "STR_DUWS_T_boattaxi_pickup", {
	DUWS_taxiPickup = [_this, 0,50,10,2,5,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;
	DUWS_taxiPickup isNotEqualTo [0,0]
}, localize "STR_DUWS_T_boattaxiwp_bad"] call fnc_map_pick_pos;
if (_pick isEqualTo []) exitWith {};
_foundPickupPos = DUWS_taxiPickup;

// One-time use: deferred to here so closing the map above leaves the item for the player to keep.
["boat_taxi"] call fnc_support_consume;

_markerpickup = format["lz%1%2",_foundPickupPos];
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

_spawnPos = [_foundPickupPos, 400,500,10,2,5,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;
if (0 == _spawnPos select 0 && 0 == _spawnPos select 1) then { _spawnPos = _foundPickupPos };

_boat = createVehicle [blufor_BOAT_TRANS_X, _spawnPos,[], 0, "NONE"];
_boatgroup = createGroup west; 
_pilot = _boatgroup createUnit [blufor_MARK_SOLDIER_X, [5,5,5], [], 0, "NONE"];
_boatgroup deleteGroupWhenEmpty true;
_boat addAction [ACT_MOVE("STR_DUWS_T_boattaxi_action_dest"), fnc_mapclickboat, [], 70, true, true, "", "vehicle _this == _target"];
_pilot moveindriver _boat;


// Single teardown for every failure below, so no path forgets the pickup marker -- a boat lost on
// the run-in must not leave it on the map for the rest of the campaign. Unlock and deleteMarker are
// no-ops when already done, so one handler is safe on every path.
_abort = {
    // Message is a parameter so the return leg can report a completed extraction rather
    // than apologise for one; everything else about the teardown is identical.
    params [["_msg", "STR_DUWS_T_boattaxi_damaged"]];
    _boat lock false;
    deleteMarker str(_markerpickup);
    [localize "STR_DUWS_T_OVERLORD", localize _msg] remoteExec ["fnc_duws_dialogue", 0];
    [_boat, _boatgroup, 45, false] call fnc_support_despawn;
};

_wp = _boatgroup addWaypoint [_foundPickupPos, 0];
_wp setWaypointType "MOVE";
[_boatgroup, 1] setWaypointCombatMode "BLUE";


waitUntil {_foundpickuppos distance _boat < 350 or (getdammage _boat > 0.7 or !alive _pilot)};
if (getdammage _boat > 0.7 or !alive _pilot) exitWith { call _abort };

_inVehCheck = true;
while {_inVehCheck} do {
waitUntil {sleep 0.5;taxiCanTakeOff or (getdammage _boat > 0.7 or !alive _pilot)};
if (getdammage _boat > 0.7 or !alive _pilot) exitWith {};
if (vehicle player != _boat) then {
	taxiCanTakeOff = false; 
	[localize "STR_DUWS_T_swordfish", localize "STR_DUWS_T_boattaxi_notaboard"] remoteExec ["fnc_duws_dialogue", 0];
	_boat addAction [ACT_MOVE("STR_DUWS_T_boattaxi_action_loc"), fnc_mapclickboat, [], 70, true, true, "", "vehicle _this == _target"];
} else {
	_inVehCheck = false;};
};

if (getdammage _boat > 0.7 or !alive _pilot) exitWith { call _abort };


// Honours the per-client music mute set at the rest tent (fnc_user_options_menu).
if (!(profileNamespace getVariable ["DUWS_T_muteMissionMusic", false])) then { playMusic [_music, 0]; };
_boat lock true;
[localize "STR_DUWS_T_swordfish", localize "STR_DUWS_T_boattaxi_oscarmike"] remoteExec ["fnc_duws_dialogue", 0];
str(_markerpickup) setMarkerPos ClickedTaxiPos; 
str(_markerpickup) setMarkerText "DROP POINT";




if (getdammage _boat > 0.7 or !alive _pilot) exitWith { call _abort };

// The fade masks the teleport to the drop point; the pilot's call goes through the dialogue system rather
// than riding the fade's text slot.
titleCut ["", "BLACK OUT", 3];
[localize "STR_DUWS_T_swordfish", localize "STR_DUWS_T_boattaxi_enroute"] remoteExec ["fnc_duws_dialogue", 0];
_teleportPoint = [ClickedTaxiPos, 400,500,10,2,5,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;
if (0 == _teleportPoint select 0 && 0 == _teleportPoint select 1) then { _teleportPoint = ClickedTaxiPos };
sleep 3.5;
_boat setpos _teleportPoint;
_wp = _boatgroup addWaypoint [ClickedTaxiPos,0];
_wp setWaypointType "MOVE";
[_boatgroup, 1] setWaypointCombatMode "BLUE";
sleep 3;
titleCut ["", "BLACK IN", 4];
_boat lock false;


waitUntil {sleep 0.5;ClickedTaxiPos distance _boat < 200  or (getdammage _boat > 0.7 or !alive _pilot)};
if (getdammage _boat > 0.7 or !alive _pilot) exitWith { call _abort };


waitUntil {sleep 0.5;(getpos _boat select 2 < 4 && _boat distance ClickedTaxiPos<20)  or (getdammage _boat > 0.7 or !alive _pilot)};
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
_wp = _boatgroup addWaypoint [_teleportPoint,0];
_wp setWaypointType "MOVE";
deleteMarker str(_markerpickup);


waitUntil {_boat distance player>100 or (getdammage _boat > 0.7 or !alive _pilot)};
if (getdammage _boat > 0.7 or !alive _pilot) exitWith { ["STR_DUWS_T_boattaxi_rtbdown"] call _abort };


[_boat, _boatgroup, 118, false] call fnc_support_despawn;
