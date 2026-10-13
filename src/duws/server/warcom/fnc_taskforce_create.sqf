// Locality: server only. Callers: client/dialog/fnc_giveHC.sqf (remoteExec target 2), the PlayerDisconnected handler in
// server/server_init.sqf, fnc_taskforce_spawn, and DUWS_fnc_restoreTaskforces with the saved name.
if (!isServer) exitWith {};
params ["_group", ["_tfName", ""], ["_spawned", false]];
if (isNull _group) exitWith {};
_group setVariable ["DUWS_hcCommander", nil];

// A yellow-team squad is local to the giver; the campaign owns it now, so it must outlive their session.
if (!local _group) then { _group setGroupOwner 2; };

private _oldName = groupId _group;
if (_tfName isEqualTo "") then { _tfName = [1] call fnc_random_name };
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

// Marker, name and spawned flag ride in the entry, not on the group: an emptied group is deleted with its variables.
private _taskforces = missionNamespace getVariable ["DUWS_taskforces", []];
_taskforces pushBack [_group, _marker, _tfName, _spawned];
missionNamespace setVariable ["DUWS_taskforces", _taskforces, true];

if (!_spawned) then {
	[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_TASKFORCE_TAKEN", _oldName, _tfName]] remoteExec ["fnc_duws_dialogue", 0];
};
