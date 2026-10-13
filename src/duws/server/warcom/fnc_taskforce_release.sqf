// Locality: server only (remoteExec target 2). Caller: the Take back button in client/dialog/fnc_taskforce_list.sqf.
if (!isServer) exitWith {};
params ["_group", "_caller"];
if (isNull _group || {isNull _caller}) exitWith {};

// Server-side as well as hidden on the client: Overlord's own task forces are not the team's to take.
private _taskforces = missionNamespace getVariable ["DUWS_taskforces", []];
private _i = _taskforces findIf {(_x select 0) isEqualTo _group && {!(_x select 3)}};
if (_i < 0) exitWith {};
(_taskforces deleteAt _i) params ["", "_marker", "_tfName"];
missionNamespace setVariable ["DUWS_taskforces", _taskforces, true];
deleteMarker _marker;

// A stale order would read as already given if the squad is handed over again, and it would never move.
_group setVariable ["DUWS_taskforce_order", nil];
[_group, "", getPosASL leader _group] call DUWS_fnc_opcom_applyOrder;
_group setVariable ["DUWS_hcCommander", getPlayerUID _caller];
[[_group], {
	params ["_group"];
	if (isNull _group) exitWith {};
	player hcSetGroup [_group, ""];
}] remoteExec ["call", _caller];

[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_TASKFORCE_RELEASED", _tfName]] remoteExec ["fnc_duws_dialogue", 0];
