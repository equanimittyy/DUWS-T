// Locality: server -- a stage of the OPCOM tick (warcom/opcom/belief/fnc_opcom_perception_run.sqf).
private _taskforces = missionNamespace getVariable ["DUWS_taskforces", []];
private _live = [];
{
	_x params ["_group", "_marker", "_tfName"];
	private _alive = if (isNull _group) then { [] } else { (units _group) select {alive _x} };
	if (_alive isEqualTo []) then {
		deleteMarker _marker;
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
		private _wp = currentWaypoint _group;
		private _orders = [];
		if (_wp < count waypoints _group) then {
			_orders = [waypointType [_group, _wp], [waypointPosition [_group, _wp]] call fnc_place_name];
		};
		private _status = [count _alive, _vehicles apply {typeOf _x}, _orders];
		if (_status isNotEqualTo (_group getVariable ["DUWS_taskforce_status", []])) then {
			_group setVariable ["DUWS_taskforce_status", _status, true];
		};
	};
} forEach _taskforces;

if (count _live != count _taskforces) then {
	missionNamespace setVariable ["DUWS_taskforces", _live, true];
};
