// Locality: server -- a stage of the OPCOM tick (warcom/opcom/belief/fnc_opcom_perception_run.sqf).
#define STAGE_MARGIN 100
#define STAGE_WAIT   30
// A town centre often sits deep in streets a vehicle never threads.
#define PATROL_ARRIVE 100
#define FIRST_SPAWN   300
#define RESPAWN       1800

// Free task forces alive at each BLUFOR tier: capped, so ignored ones cannot pile up as permanently simulated AI.
private _freeCap = [1, 1, 2, 2, 3] select (([WARCOM_blufor_ap_earned] call DUWS_fnc_ap_tier) - 1);
if (isNil "DUWS_taskforce_spawnAt") then { DUWS_taskforce_spawnAt = time + FIRST_SPAWN };
if (time >= DUWS_taskforce_spawnAt && {({_x select 3} count (missionNamespace getVariable ["DUWS_taskforces", []])) < _freeCap}) then {
	call fnc_taskforce_spawn;
	DUWS_taskforce_spawnAt = time + RESPAWN;
};

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

// A standing defender keeps its zone, so a new capture does not reshuffle every post.
private _posts = [];
if (_objectiveName == "") then {
	private _open = zone_namePOS_pairs select { _x params ["", "_zp"]; (WARCOM_zones_controled_by_BLUFOR findIf {(_x distance2D _zp) < 1}) >= 0 };
	private _free = [];
	{
		_x params ["_group"];
		if (!isNull _group && {local _group} && {(units _group) findIf {alive _x} >= 0}) then {
			private _order = _group getVariable ["DUWS_taskforce_order", []];
			private _kept = _open findIf {(_order param [0, ""]) == "defend" && {(_x select 1) isEqualTo (_order select 2)}};
			if (_kept >= 0) then {
				(_open deleteAt _kept) params ["_zoneName", "_zonePos"];
				_posts pushBack [_group, _zoneName, _zonePos];
			} else {
				_free pushBack _group;
			};
		};
	} forEach _taskforces;
	{
		if (_free isEqualTo []) exitWith {};
		_x params ["_zoneName", "_zonePos"];
		private _near = 0;
		{ if ((leader _x distance2D _zonePos) < (leader (_free select _near) distance2D _zonePos)) then { _near = _forEachIndex } } forEach _free;
		_posts pushBack [_free deleteAt _near, _zoneName, _zonePos];
	} forEach _open;
};

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

private _fnc_hold = {
	params ["_group", "_post"];
	[_group, "", _post] call DUWS_fnc_opcom_applyOrder;
	private _hold = _group addWaypoint [_post, 0];
	_hold setWaypointType "HOLD";
	_group setCurrentWaypoint _hold;
};

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

		// A waypoint takes only where its group is local, and setGroupOwner may not have moved a given squad here yet.
		if (local _group) then {
			private _order = _group getVariable ["DUWS_taskforce_order", []];
			private _arrived = currentWaypoint _group >= count waypoints _group;
			private _postIdx = _posts findIf {(_x select 0) isEqualTo _group};
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
				case (_postIdx >= 0): {
					(_posts select _postIdx) params ["", "_zoneName", "_zonePos"];
					if (_order isNotEqualTo ["defend", _zoneName, _zonePos]) then {
						[_group, _zonePos] call _fnc_hold;
						_group setVariable ["DUWS_taskforce_order", ["defend", _zoneName, _zonePos]];
					};
				};
				case (_towns isNotEqualTo []): {
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
				default {
					if (_order isNotEqualTo ["hq"]) then {
						[_group, WARCOM_blu_hq_pos] call _fnc_hold;
						_group setVariable ["DUWS_taskforce_order", ["hq"]];
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
