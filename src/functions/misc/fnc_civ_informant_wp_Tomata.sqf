if (!isServer) exitWith {};
_informant =_this select 0;
_usableBuildings = _this select 1;

_building = selectRandom _usableBuildings;
_positions = [_building] call BIS_fnc_buildingPositions;
_randPos = [1,(count _positions)-1] call BIS_fnc_randomInt;
_wp1 = _informant addWaypoint [(_building buildingPos _randPos),2];
_wp1 setWaypointType "MOVE";
_wp1 setWaypointSpeed "LIMITED";
_wp1 setWaypointBehaviour "SAFE";
_wp1 setWaypointCombatMode "GREEN";
_wp1 setWaypointTimeout [300, 305, 310]; 
_wp1 setWaypointCompletionRadius 5;

_building = selectRandom _usableBuildings;
_positions = [_building] call BIS_fnc_buildingPositions;
_randPos = [1,(count _positions)-1] call BIS_fnc_randomInt;
_wp2 = _informant addWaypoint [(_building buildingPos _randPos),2];
_wp2 setWaypointType "MOVE"; 
_wp2 setWaypointSpeed "LIMITED";
_wp2 setWaypointBehaviour "SAFE";
_wp2 setWaypointCombatMode "GREEN";
_wp1 setWaypointTimeout [300, 305, 310]; 
_wp2 setWaypointCompletionRadius 5;
	
_wp3 = _informant addWaypoint [getpos leader _informant, 2];
_wp3 setWaypointType "CYCLE";
_wp3 setWaypointSpeed "LIMITED";
_wp3 setWaypointBehaviour "SAFE";
_wp3 setWaypointCombatMode "GREEN";
_wp1 setWaypointTimeout [300, 305, 310]; 
_wp3 setWaypointCompletionRadius 5;


