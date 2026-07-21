if (!isServer) exitWith {};
_group =_this select 0;
_leader = units _group select 0;
_group setCombatMode "YELLOW";

// check if at least 1 zone is under BLU control, if not, attack HQ.

if (count WARCOM_zones_controled_by_BLUFOR == 0) exitWith {
    _wp = _group addWaypoint [WARCOM_blu_hq_pos, 50];
    _wp setWaypointType "MOVE";     // MUST BE MOVE FOR FOR VEH SQUADS
	_wp setWaypointBehaviour "AWARE";
	_wp setWaypointFormation  "STAG COLUMN";
	//if (vehicle _leader != _leader) then {_wp setWaypointSpeed "LIMITED"};  // prevent vehiceles from running ahead
}; 

_groupLeader = leader _group;
_group_pos = getPos _groupLeader;
_sorted_zones = [WARCOM_zones_controled_by_BLUFOR,[_group_pos],{_input0 distance _x},"ASCEND"] call BIS_fnc_sortBy;

{
    _wp1 = _group addWaypoint [_x, 50];
    _wp1 setWaypointType "MOVE";
	_wp1 setWaypointBehaviour "AWARE";
	_wp1 setWaypointFormation  "STAG COLUMN";
	//if (vehicle _leader != _leader) then {_wp setWaypointSpeed "LIMITED"};  // prevent vehiceles from running ahead
	_wp1 setWaypointCompletionRadius 100;
	_wp1 setWaypointTimeout [60, 120, 240]; 
}
forEach _sorted_zones;


