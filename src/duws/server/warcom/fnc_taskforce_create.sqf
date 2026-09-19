// Locality: server only (remoteExec target 2). Caller: client/dialog/fnc_giveHC.sqf.
if (!isServer) exitWith {};
params ["_group"];
if (isNull _group) exitWith {};

private _oldName = groupId _group;
private _tfName = [1] call fnc_random_name;
private _label = format ["TF %1", _tfName];
_group setGroupIdGlobal [_label];

private _veh = vehicle leader _group;
private _markerType = switch (true) do {
	case (_veh isKindOf "Tank"): { "b_armor" };
	case (_veh isKindOf "Car"): { "b_motor_inf" };
	default { "b_inf" };
};
private _n = (missionNamespace getVariable ["DUWS_taskforce_count", 0]) + 1;
missionNamespace setVariable ["DUWS_taskforce_count", _n];
private _marker = createMarker [format ["DUWS_taskforce_%1", _n], getPosWorld leader _group];
_marker setMarkerType _markerType;
_marker setMarkerColor "ColorBLUFOR";
_marker setMarkerText _label;

[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_TASKFORCE_TAKEN", _oldName, _tfName]] remoteExec ["fnc_duws_dialogue", 0];

while {!isNull _group && {(units _group) findIf {alive _x} >= 0}} do {
	_marker setMarkerPos getPosWorld leader _group;
	sleep 4;
};

deleteMarker _marker;
[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_TASKFORCE_LOST", _tfName]] remoteExec ["fnc_duws_dialogue", 0];
