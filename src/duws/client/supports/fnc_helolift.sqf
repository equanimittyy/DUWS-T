// Locality: client -- invoked from the comm menu (shared/includes/supports_radio_modern.hpp:167).
// The addAction body below runs on whoever triggers it.
// This file drives the lift but owns none of the aircraft. The helo is created and kept
// server-side by server/supports/fnc_helolift_spawnHeli.sqf, because waypoint and
// flight-height commands are only honoured where the group is local; issuing them here
// worked for a hosting player and silently did nothing for everyone else. So every helo or
// group command goes out via fnc_helolift_waypoints / fnc_helolift_ropes on target 2, and
// what stays local is exactly what is local by nature: cursorObject, hints, map markers,
// the player's own addAction, and the geometry maths that only reads positions.


#include "..\..\shared\includes\action_style.hpp"

_target = cursorObject;
if (isNull _target) exitWith {
    hint localize "STR_DUWS_T_helolift_notarget";
    sleep 10;
    ["helo_lift"] call fnc_support_comm_add;
};
if !(_target isKindOf "Car" || _target isKindOf "Tank" || _target isKindOf "Helicopter" || _target isKindOf "Plane") exitWith {
    hint localize "STR_DUWS_T_helolift_badtarget";
    sleep 10;
    ["helo_lift"] call fnc_support_comm_add;
};

_playerUID = getPlayerUID player;
_varPrefix = format ["LiftTask_%1", _playerUID];

// init player variables the map-click script reads
player setVariable ["LiftTakeOff", false];
player setVariable ["LiftWaypoints", []];
player setVariable ["LiftWaypointMarkers", []];

// spawn the helicopter -- must run on the server
missionNamespace setVariable [_varPrefix + "_heloReady", false];
[player, _target] remoteExec ["fnc_helolift_spawnHeli", 2];

// Bail rather than hang: a lost request would otherwise wedge this thread forever and the
// comm-menu entry never comes back.
_spawnDeadline = diag_tickTime + 30;
waitUntil {
    sleep 0.5;
    (missionNamespace getVariable [_varPrefix + "_heloReady", false]) or (diag_tickTime > _spawnDeadline)
};
_helo = missionNamespace getVariable [_varPrefix + "_helo", objNull];
_heloGroup = missionNamespace getVariable [_varPrefix + "_heloGroup", grpNull];
if (isNull _helo) exitWith {
    hint localize "STR_DUWS_T_helolift_noheli";
    sleep 10;
    ["helo_lift"] call fnc_support_comm_add;
};
_pilot = currentPilot _helo;

_targetVehicle = _target;
_originalMass = getMass _targetVehicle;

// Single teardown for every failure below, replacing nine near-identical copies. The
// server owns the aircraft, so the rope/mass/landing cleanup is its call -- this half only
// clears the player's own map markers and hands the support back.
_abort = {
    private _markers = player getVariable ["LiftWaypointMarkers", []];
    { deleteMarker _x } forEach _markers;
    player setVariable ["LiftWaypointMarkers", []];
    [localize "STR_DUWS_T_OVERLORD", ([localize "STR_DUWS_T_heloliftabort"] call fnc_cs)] remoteExec ["fnc_duws_dialogue", 0];
    [player, "abort", [_helo, _targetVehicle, _originalMass, _heloGroup]] remoteExec ["fnc_helolift_ropes", 2];
    sleep 300;
    ["helo_lift"] call fnc_support_comm_add;
};


_helo_maxDamage = 0.7;
_helo_minFuel = 0.4;
_check_damage = compile format ["(isNull _helo) or (damage _helo > %1) or (fuel _helo < %2) or (vehicle _pilot == _pilot)", _helo_maxDamage, _helo_minFuel];

_speaker = localize "STR_DUWS_T_actionteam";
_message = format[([localize "STR_DUWS_T_heloliftcall"] call fnc_cs)];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

_hookMarkerName = format ["hook_%1", floor random 10000];
createMarker [_hookMarkerName, getPos _target];
_hookMarkerName setMarkerType "hd_dot";
_hookMarkerName setMarkerColor "ColorBlue";
_hookMarkerName setMarkerText "HOOK POINT";

[player, "clear", []] remoteExec ["fnc_helolift_waypoints", 2];

_moveCompletedVar = _varPrefix + "_moveCompleted";
missionNamespace setVariable [_moveCompletedVar, false]; // init, client-local
[player, "setInitial", [_targetVehicle]] remoteExec ["fnc_helolift_waypoints", 2];

sleep 8;
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = format[localize "STR_DUWS_T_helolift1"];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
_speaker = localize "STR_DUWS_T_crane";
_message = format[localize "STR_DUWS_T_helolift2"];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
waitUntil {
    sleep 1.5;
    (missionNamespace getVariable [_moveCompletedVar, false]) or (call _check_damage)
};
if (call _check_damage) exitWith { call _abort };

[player, "height", [10]] remoteExec ["fnc_helolift_waypoints", 2];
deleteMarker _hookMarkerName;
_speaker = localize "STR_DUWS_T_crane";
_message = format[localize "STR_DUWS_T_helolift3"];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
if (call _check_damage) exitWith { call _abort };

// helicopter rope attach points
private _heliPoints = [
    [ 1.4,  2.8, -2],   // front-right
    [ 1.4, -2.8, -2],   // front-left
    [-1.4,  2.8, -2],   // rear-right
    [-1.4, -2.8, -2],   // rear-left
    [0, -7, -1]         // rear-centre
];

// vehicle centre of mass and rope attach points
private _com = getCenterOfMass _targetVehicle;
private _frontRadius = 2.5;
private _rearRadius = _frontRadius;
private _heightOffset = 0.3;

private _vehPoints = [];

// front two points
private _frontAngles = [45, 135];
{
    private _angle = _x;
    private _xPos = (_com select 0) + (_frontRadius * cos _angle);
    private _yPos = (_com select 1) + (_frontRadius * sin _angle);
    private _zPos = (_com select 2) + _heightOffset;
    _vehPoints pushBack [_xPos, _yPos, _zPos];
} forEach _frontAngles;

// rear two points
private _rearAngles = [315, 225];
{
    private _angle = _x;
    private _xPos = (_com select 0) + (_rearRadius * cos _angle);
    private _yPos = (_com select 1) + (_rearRadius * sin _angle);
    private _zPos = (_com select 2) + _heightOffset;
    _vehPoints pushBack [_xPos, _yPos, _zPos];
} forEach _rearAngles;

// rear-centre point
private _rearX = (_com select 0) + (_rearRadius * cos 270);
private _rearY = (_com select 1) + (_rearRadius * sin 270);
private _rearZ = (_com select 2) + _heightOffset;
_vehPoints pushBack [_rearX, _rearY, _rearZ];

// rope pairings (heli point -> vehicle point)
private _mainPairs = [
    [0, 0], // front-right -> front-right
    [1, 2], // front-left -> rear-right
    [2, 1], // rear-right -> front-left
    [3, 3]  // rear-left -> rear-left
];
private _crossPairs = [
    [0, 2], // heli front-right -> vehicle rear-right
    [1, 0], // heli front-left -> vehicle front-right
    [2, 3], // heli rear-right -> vehicle rear-left
    [3, 1]  // heli rear-left -> vehicle front-left
];
private _rearPair = [4, 4];
private _allPairs = _mainPairs + _crossPairs + [_rearPair];

// initial rope slack length
private _dists = [];
{
    _x params ["_heliIdx", "_vehIdx"];
    private _heliPos = _helo modelToWorld (_heliPoints select _heliIdx);
    private _vehPos = _targetVehicle modelToWorld (_vehPoints select _vehIdx);
    _dists pushBack (_heliPos distance _vehPos);
} forEach _allPairs;
private _maxDist = selectMax _dists;
private _ropeLength = _maxDist * 1.1; // 10% slack

// server creates and tightens the ropes, setting allowDamage false
[player, "create", [_helo, _targetVehicle, _allPairs, _heliPoints, _vehPoints, _ropeLength, _originalMass]] remoteExec ["fnc_helolift_ropes", 2];

_ropesTightVar = _varPrefix + "_ropesTight";
waitUntil {
    sleep 1.5;
    (missionNamespace getVariable [_ropesTightVar, false]) or (call _check_damage)
};
if (call _check_damage) exitWith { call _abort };
sleep 6;
_speaker = localize "STR_DUWS_T_crane";
_message = format[localize "STR_DUWS_T_helolift5"];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

[player, "height", [60]] remoteExec ["fnc_helolift_waypoints", 2];
if (call _check_damage) exitWith { call _abort };

_liftActionID = player addAction [
    ACT_MOVE("STR_DUWS_T_helolift_action_wp"),
    fnc_mapclicklift,
    [],
    70,
    true,
    true,
    "",
    "true"
];
if (call _check_damage) exitWith { player removeAction _liftActionID; call _abort };

waitUntil {sleep 1.5; (player getVariable ["LiftTakeOff", false]) or (call _check_damage)};
player removeAction _liftActionID;
if (call _check_damage) exitWith { call _abort };

private _waypoints = player getVariable ["LiftWaypoints", []];
if (count _waypoints < 3) exitWith { hint localize "STR_DUWS_T_liftwp_incomplete"; call _abort };

// update the final waypoint marker, client-side visual feedback
private _heloPos = getPos _helo;
private _finalClickPos = _waypoints select 2;
private _offsetFinalPos = _finalClickPos getPos [-70, _finalClickPos getDir _heloPos];
private _markers = player getVariable ["LiftWaypointMarkers", []];
if (count _markers >= 3) then {
    _finalMarker = _markers select 2;
    _finalMarker setMarkerPos _offsetFinalPos;
};

_finalReachedVar = _varPrefix + "_finalReached";
missionNamespace setVariable [_finalReachedVar, false];
[player, "setRoute", [_waypoints]] remoteExec ["fnc_helolift_waypoints", 2];

[player, "height", [60]] remoteExec ["fnc_helolift_waypoints", 2];

waitUntil {
    sleep 0.5;
    (missionNamespace getVariable [_finalReachedVar, false]) or (call _check_damage)
};
if (call _check_damage) exitWith { call _abort };

[player, "height", [60]] remoteExec ["fnc_helolift_waypoints", 2];
_speaker = localize "STR_DUWS_T_crane";
_message = format[localize "STR_DUWS_T_helolift6"];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
if (call _check_damage) exitWith { call _abort };

// release: server loosens and destroys the ropes and restores the vehicle mass
[player, "release", [_helo, _ropeLength, _targetVehicle, _originalMass]] remoteExec ["fnc_helolift_ropes", 2];
sleep 8; // wait for the ropes to loosen

private _markers = player getVariable ["LiftWaypointMarkers", []];
{ deleteMarker _x } forEach _markers;
player setVariable ["LiftWaypointMarkers", []];


[player, "height", [100]] remoteExec ["fnc_helolift_waypoints", 2];
[player, "depart", []] remoteExec ["fnc_helolift_waypoints", 2];
{ deleteMarker _x } forEach _markers;
player setVariable ["LiftWaypointMarkers", []];
[player, "cleanup", [_helo]] remoteExec ["fnc_helolift_ropes", 2];
sleep 120;
["helo_lift"] call fnc_support_comm_add;