if (!isServer) exitWith {};
_group =_this select 0;
_group setCombatMode "YELLOW";

{
    _wp = _group addWaypoint [_x, 50];
    _wp setWaypointType "MOVE";    // MUST BE MOVE FOR FOR VEH SQUADS
	_wp setWaypointBehaviour "AWARE";
	_wp setWaypointFormation  "STAG COLUMN";
	_wp setWaypointCompletionRadius 200;
	_wp setWaypointTimeout [60, 120, 240]; 
	
}forEach WARCOM_zones_controled_by_BLUFOR;

    _wp1 = _group addWaypoint [[(WARCOM_blu_hq_pos select 0)+50, (WARCOM_blu_hq_pos select 1)], 300];
    _wp1 setWaypointType "MOVE";
	_wp1 setWaypointBehaviour "AWARE";
	_wp1 setWaypointFormation  "STAG COLUMN";
	_wp1 setWaypointCompletionRadius 200;
	_wp1 setWaypointTimeout [60, 120, 180]; 

    _wp2 = _group addWaypoint [getpos leader _group, 30];
    _wp2 setWaypointType "CYCLE";
