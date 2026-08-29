// Locality: server -- the mission-site target-position search, called by fnc_mission_site.

params ["_missionpos", "_radius", "_Posfound", "_targetpos", "_failSafe"];

// Declared here, not inside the loop: a while/do block is its own scope, so a variable first assigned
// inside it does not survive past the iteration -- leaving _Building/_randomPos undefined in the return
// value otherwise.
private _randomPos = [];
private _Building = objNull;

while {!_Posfound} do {

	_failSafe = _failSafe + 1;
	_randomPos = [(_missionpos select 0)+(random _radius)-(random _radius), (_missionpos select 1)+(random _radius)-(random _radius)];
	_Building = "";
	_nearBuildings = [];
	_nearBuildings = nearestTerrainObjects [_randomPos, ["House","BUILDING"], 200, true];
	if (count(_nearBuildings) == 0) then {
		_Building = _randomPos;
		[{hint localize "STR_DUWS_T_pj31ugj0"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];
		sleep 5;
	} else {
		_bindex = (count _nearBuildings) - 1;
		_Building = _nearBuildings select (floor (random _bindex));
	};

	_targetpos = [_Building, 10, 50,15,0,0.15,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;

	_nearRoad = [_targetpos,15] call BIS_fnc_nearestRoad;
	// And on ground nothing else owns: not in a zone, a civilian town, or BLUFOR's area of influence.
	// This is the position the mission builds and garrisons on, and it drifts from the cleared anchor
	// (up to _radius each axis, then 10-50 m off a building), so an anchor outside everything does not
	// guarantee the objective is -- hence the re-test here, in the loop that can re-roll it.
	if (_targetpos select 0 != 0 &&
		_targetpos select 1 != 0 &&
		isNull _nearRoad &&
		!([_targetpos] call fnc_pos_claimed) &&
		!([_targetpos] call fnc_aoi_blufor_covers)) then {_Posfound=true;};

	// Logged, not left to the caller's generic abort: this loop starves first on a crowded map, and
	// the abort alone would not say which constraint could not be met.
	if (_failSafe > 50) exitWith {
		["WARN", "MISSION", format ["no clear ground within %1 m of %2 in 50 tries", _radius, _missionpos]] call fnc_log;
	};
};

_returnArray = [_randomPos, _Building, _Posfound, _targetpos, _failSafe];
_returnArray;


