// Locality: server -- a stage of the OPCOM tick (warcom/opcom/belief/fnc_opcom_perception_run.sqf).
#define STAGE_MARGIN 100
#define STAGE_WAIT   30
// A town centre often sits deep in streets a vehicle never threads.
#define PATROL_ARRIVE 100

private _taskforces = missionNamespace getVariable ["DUWS_taskforces", []];
if (_taskforces isEqualTo []) exitWith {};

// Revealed zones and towns only: in hardcore, a task force marching on an undiscovered one would draw it on the map.
private _objective = [];
private _bestD = 1e10;
{
	_x params ["_name", "_zp", "_revealed"];
	if (_revealed && {(WARCOM_zones_controled_by_OPFOR findIf {(_x distance2D _zp) < 1}) >= 0}) then {
		private _d = _zp distance2D WARCOM_blu_hq_pos;
		if (_d < _bestD) then { _bestD = _d; _objective = [_name, _zp]; };
	};
} forEach zone_namePOS_pairs;
_objective params [["_objectiveName", ""], ["_objectivePos", []]];
private _objectiveKey = if (_objectiveName == "") then { "" } else { [_objectivePos] call fnc_zone_key };

private _towns = [];
private _visible = missionNamespace getVariable ["civ_visible", []];
{
	if (_visible param [_forEachIndex, true]) then { _towns pushBack [text _x, getPos _x] };
} forEach (missionNamespace getVariable ["civ_locations", []]);

// Deleting waypoints leaves currentWaypoint where it was, so a squad handed over mid-orders would skip the new ones.
private _fnc_attack = {
	params ["_group", "_dest", ["_stage", []]];
	[_group, "capture", _dest] call DUWS_fnc_opcom_applyOrder;
	private _first = [_group, count waypoints _group - 1];
	if (_stage isNotEqualTo []) then {
		_first = _group addWaypoint [_stage, 0, _first select 1];
		_first setWaypointType "MOVE";
		_first setWaypointTimeout [STAGE_WAIT, STAGE_WAIT, STAGE_WAIT];
	};
	_group setCurrentWaypoint _first;
};

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
		if (local _group) then {
			private _order = _group getVariable ["DUWS_taskforce_order", []];
			private _arrived = currentWaypoint _group >= count waypoints _group;
			switch (true) do {
				case (_objectiveName != ""): {
					if (_order isNotEqualTo ["capture", _objectiveName]) then {
						// Regroup just outside the ring the garrison wakes on, so the squad meets it formed rather than strung out.
						private _ring = (([_objectiveKey] call fnc_site_at) getOrDefault ["radius", 0])
							+ (([_objectiveKey, "garrison"] call fnc_site_occupant) getOrDefault ["buffer", 400]);
						private _stage = _objectivePos getPos [_ring + STAGE_MARGIN, _objectivePos getDir leader _group];
						if ((leader _group) distance2D _objectivePos < _ring + STAGE_MARGIN || {surfaceIsWater _stage}) then { _stage = [] };
						[_group, _objectivePos, _stage] call _fnc_attack;
						[groupId _group, format [localize "STR_DUWS_T_TASKFORCE_ASSAULT", groupId _group, _objectiveName], "SUB-NET"] remoteExec ["fnc_duws_dialogue", 0];
						_group setVariable ["DUWS_taskforce_order", ["capture", _objectiveName]];
					} else {
						// A capture needs the zone's own garrison beaten wherever it wandered, so a sweep that ends short hunts the nearest survivor.
						if (_arrived) then {
							private _left = ([_objectiveKey] call fnc_zone_roster) select {alive _x};
							private _dest = if (_left isEqualTo []) then { _objectivePos } else { getPosASL ([_left, leader _group] call BIS_fnc_nearestPosition) };
							[_group, _dest] call _fnc_attack;
						};
					};
				};
				case (_towns isEqualTo []): {
					if (_order isNotEqualTo ["hq"]) then {
						[_group, "", WARCOM_blu_hq_pos] call DUWS_fnc_opcom_applyOrder;
						private _hold = _group addWaypoint [WARCOM_blu_hq_pos, 0];
						_hold setWaypointType "HOLD";
						_group setCurrentWaypoint _hold;
						_group setVariable ["DUWS_taskforce_order", ["hq"]];
					};
				};
				default {
					if ((_order param [0, ""]) != "patrol" || {_arrived}) then {
						private _legs = _towns select {(_x select 1) isNotEqualTo (_order param [2, []])};
						if (_legs isNotEqualTo []) then {
							(selectRandom _legs) params ["_townName", "_townPos"];
							[_group, "patrol", _townPos] call DUWS_fnc_opcom_applyOrder;
							[_group, count waypoints _group - 1] setWaypointCompletionRadius PATROL_ARRIVE;
							_group setVariable ["DUWS_taskforce_order", ["patrol", _townName, _townPos]];
						};
					};
				};
			};
		};

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
