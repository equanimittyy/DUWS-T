// Locality: server -- a stage of the OPCOM tick (warcom/opcom/belief/fnc_opcom_perception_run.sqf).
#define FIRST_SPAWN   300
#define RESPAWN       1800
#define FREE_MAX      6

// Free task forces alive: capped, so ignored ones cannot pile up as permanently simulated AI.
private _freeCap = FREE_MAX min (([1, 1, 2, 2, 3] select (([WARCOM_blufor_ap_earned] call DUWS_fnc_ap_tier) - 1)) + count WARCOM_zones_controled_by_BLUFOR);
if (isNil "DUWS_taskforce_spawnAt") then { DUWS_taskforce_spawnAt = time + FIRST_SPAWN };
if (time >= DUWS_taskforce_spawnAt && {({_x select 3} count (missionNamespace getVariable ["DUWS_taskforces", []])) < _freeCap}) then {
	call fnc_taskforce_spawn;
	DUWS_taskforce_spawnAt = time + RESPAWN;
};

private _taskforces = missionNamespace getVariable ["DUWS_taskforces", []];
if (_taskforces isEqualTo []) exitWith {};
// Advanced leaves the orders to BLUFOR's commander; the timer, the markers and the list status stay here.
if ("BLU" in DUWS_opcom_cmds) then { [_taskforces] call fnc_taskforce_commander } else { [_taskforces] call fnc_taskforce_orders };

private _live = [];
{
	_x params ["_group", "_marker", "_tfName", "_spawned"];
	private _alive = if (isNull _group) then { [] } else { (units _group) select {alive _x} };
	if (_alive isEqualTo []) then {
		deleteMarker _marker;
		if (_spawned) then { DUWS_taskforce_spawnAt = time + RESPAWN };
		[localize "STR_DUWS_T_OVERLORD", format [localize "STR_DUWS_T_TASKFORCE_LOST", _tfName]] remoteExec ["fnc_duws_dialogue", 0];
	} else {
		_live pushBack _x;
		_marker setMarkerPos getPosWorld leader _group;

		private _vehicles = [];
		{
			{
				if (!isNull _x && {alive _x} && {!(_x isKindOf "CAManBase")}) then { _vehicles pushBackUnique _x; };
			} forEach [assignedVehicle _x, vehicle _x];
		} forEach _alive;
		private _status = [count _alive, _vehicles apply {typeOf _x}, _group getVariable ["DUWS_taskforce_order", []]];
		if (_status isNotEqualTo (_group getVariable ["DUWS_taskforce_status", []])) then {
			_group setVariable ["DUWS_taskforce_status", _status, true];
		};
	};
} forEach _taskforces;

if (count _live != count _taskforces) then {
	missionNamespace setVariable ["DUWS_taskforces", _live, true];
};
