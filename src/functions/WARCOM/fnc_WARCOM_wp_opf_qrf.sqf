_group =_this select 0;
_leader = units _group select 0;
_unitPos = _this select 1;
_patrol = _this select 2;

onStation = false;

_group setCombatMode "YELLOW";

    _wp = _group addWaypoint [_unitPos, 50];
    _wp setWaypointType "MOVE";     // MUST BE MOVE FOR FOR VEH SQUADS
	_wp setWaypointBehaviour "AWARE";
	_wp setWaypointFormation  "STAG COLUMN";
	//if (vehicle _leader != _leader) then {_wp setWaypointSpeed "LIMITED"};  // prevent vehiceles from running ahead
	_wp setWaypointCompletionRadius 100;
	_wp setWaypointTimeout [60, 120, 240]; 
	_wp setWaypointStatements ["true", "onStation = true"]; 

_groupName = groupId _group;
waitUntil {sleep 60;onStation || isNull _group};
if (isNull _group) exitWith {};
if (_patrol == 2) then {
	[_group, _unitPos, 300] call bis_fnc_taskPatrol;
} else {	
	[_group, _unitPos] call bis_fnc_taskDefend;
};

