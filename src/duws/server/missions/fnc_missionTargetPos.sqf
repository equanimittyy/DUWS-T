// Locality: server -- inherited from server/missions/mission_threads/clearthearea_cqb/fnc_clearthearea_cqb_mission.sqf.

params ["_missionpos", "_radius", "_Posfound", "_targetpos", "_failSafe"];

while {!_Posfound} do {

	_failSafe = _failSafe + 1;
	// define random pos near MissionPos. Spawn marker at randomPos.
	_randomPos = [(_missionpos select 0)+(random _radius)-(random _radius), (_missionpos select 1)+(random _radius)-(random _radius)];
	_Building = "";
	_nearBuildings = [];
	_nearBuildings = nearestTerrainObjects [_randomPos, ["House","BUILDING"], 200, true];
	if (count(_nearBuildings) == 0) then {
		//_Building = nearestBuilding _randomPos;
		_Building = _randomPos;
		[{hint localize "STR_DUWS_T_pj31ugj0"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];
		sleep 5;
	} else {
		_bindex = (count _nearBuildings) - 1;
		_Building = _nearBuildings select (floor (random _bindex));
	};

	_targetpos = [_Building, 10, 50,15,0,0.15,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;

	// DON'T SPAWN ON ROADS
	_nearRoad = [_targetpos,15] call BIS_fnc_nearestRoad;
	// And not inside a zone. This is the position the mission is actually built on and garrisons
	// around, and it drifts from the anchor the strategic map cleared -- up to _radius on each axis
	// to _randomPos, then another 10-50 m off a building -- so an anchor outside every zone is no
	// guarantee the objective is. Tested here because this is the loop that can re-roll it.
	if (_targetpos select 0 != 0 &&
		_targetpos select 1 != 0 &&
		isNull _nearRoad &&
		!([_targetpos] call fnc_pos_in_zone)) then {_Posfound=true;};

	if (_failSafe > 50) exitWith {};
};

_returnArray = [_randomPos, _Building, _Posfound, _targetpos, _failSafe];
_returnArray;


