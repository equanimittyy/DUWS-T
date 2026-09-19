// Locality: server -- a stage of the OPCOM tick (warcom/opcom/belief/fnc_opcom_perception_run.sqf).
private _taskforces = missionNamespace getVariable ["DUWS_taskforces", []];
if (_taskforces isEqualTo []) exitWith {};

// Revealed zones only: in hardcore, a task force marching on an undiscovered zone would draw it on the map.
private _objective = [];
private _bestD = 1e10;
{
	_x params ["_name", "_zp", "_revealed"];
	if (_revealed && {(WARCOM_zones_controled_by_OPFOR findIf {(_x distance2D _zp) < 1}) >= 0}) then {
		private _d = _zp distance2D WARCOM_blu_hq_pos;
		if (_d < _bestD) then { _bestD = _d; _objective = [_name, _zp]; };
	};
} forEach zone_namePOS_pairs;
private _objectiveName = if (_objective isEqualTo []) then { "" } else { _objective select 0 };

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

		// A waypoint takes only where its group is local, and setGroupOwner may not have moved a given squad here yet.
		if (local _group && {(_group getVariable ["DUWS_taskforce_target", -1]) isNotEqualTo _objectiveName}) then {
			if (_objective isEqualTo []) then {
				private _here = getPosASL leader _group;
				[_group, "", _here] call DUWS_fnc_opcom_applyOrder;
				(_group addWaypoint [_here, 0]) setWaypointType "HOLD";
			} else {
				[_group, "capture", _objective select 1] call DUWS_fnc_opcom_applyOrder;
			};
			_group setVariable ["DUWS_taskforce_target", _objectiveName];
		};

		private _vehicles = [];
		{
			{
				if (!isNull _x && {alive _x} && {!(_x isKindOf "CAManBase")}) then { _vehicles pushBackUnique _x; };
			} forEach [assignedVehicle _x, vehicle _x];
		} forEach _alive;
		private _status = [count _alive, _vehicles apply {typeOf _x}, _group getVariable ["DUWS_taskforce_target", ""]];
		if (_status isNotEqualTo (_group getVariable ["DUWS_taskforce_status", []])) then {
			_group setVariable ["DUWS_taskforce_status", _status, true];
		};
	};
} forEach _taskforces;

if (count _live != count _taskforces) then {
	missionNamespace setVariable ["DUWS_taskforces", _live, true];
};
