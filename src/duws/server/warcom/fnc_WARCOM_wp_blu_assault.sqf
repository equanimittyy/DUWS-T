if (!isServer) exitWith {};
_group = _this select 0;
_zones_to_use = [];

// clear any previous waypoints
while {(count (waypoints _group)) > 0} do {
	deleteWaypoint ((waypoints _group) select 0);
};

if (hardcore_mode_enable) then {
	// sort _zones_to_use by WARCOM_zones_controled_by_OPFOR
	{
		_curr_zone = _x;
		{
			// only use zones that are controlled by opfor (not blufor)
			if (str (_x select 1) == str (_curr_zone) && (_x select 2 == true)) then {
				_zones_to_use = _zones_to_use + [_x select 1];
			};
		} forEach zone_namePOS_pairs;
	} forEach WARCOM_zones_controled_by_OPFOR;
} else {
	_zones_to_use = WARCOM_zones_controled_by_OPFOR;
};

_group setCombatMode "YELLOW";

{
    _wp = _group addWaypoint [_x, 50];
    _wp setWaypointType "MOVE";   // MUST BE MOVE FOR VEH SQUADS
	_wp setWaypointBehaviour "AWARE";
	_wp setWaypointFormation "STAG COLUMN";
	_wp setWaypointCompletionRadius 150;
	_wp setWaypointTimeout [240, 300, 360]; 
}
forEach _zones_to_use;

