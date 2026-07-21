if (!isServer) exitWith {};
_group =_this select 0;
_leader = units _group select 0;
_group setCombatMode "YELLOW";
_avail_zones = 0;
_combined = WARCOM_zones_controled_by_OPFOR + WARCOM_zones_controled_by_BLUFOR;
_zones_to_patrol = _combined call BIS_fnc_arrayShuffle;
if (count _combined < 4) then {
	_avail_zones = count _combined;
} else {
	_avail_zones = (ceil ((count _combined)/2)) + 1;  // only use 1/2 the zones
};

_curr_zone = 1;
{
	if (_curr_zone <= _avail_zones) then {
		_wp = _group addWaypoint [_x, 50];
		_wp setWaypointType "MOVE";     // MUST BE MOVE FOR FOR VEH SQUADS
		_wp setWaypointBehaviour "AWARE";
		_wp setWaypointFormation  "STAG COLUMN";
		_wp setWaypointCompletionRadius 200;
		_wp setWaypointTimeout [60, 120, 240]; 
		_curr_zone = _curr_zone + 1;
	};
} forEach _zones_to_patrol;

_wp1 = _group addWaypoint [getpos leader _group, 30];
_wp1 setWaypointType "CYCLE";
