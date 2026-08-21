// Locality: server -- inherited from server/missions/mission_threads/clearthearea_cqb/fnc_clearthearea_cqb_mission.sqf.

params ["_missionpos", "_radius", "_Posfound", "_targetpos", "_failSafe"];

// Declared here rather than left to the loop, and that is the whole of a long-standing bug. A
// while/do block is its own scope: a variable first assigned inside it dies with the iteration, so
// only the four params above survived to the return array and these two came back undefined. Every
// side mission routed through here was then handed an undefined position for its ellipse, its icon
// and its task destination alike -- and a marker created at one never draws, silently. Intel
// Gathering was the only mission that looked right on the map, and the only one that finds its own
// position instead of asking for this one.
private _randomPos = [];
private _Building = objNull;

while {!_Posfound} do {

	_failSafe = _failSafe + 1;
	// define random pos near MissionPos. Spawn marker at randomPos.
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
	// And on ground nothing else owns: not inside a zone, not inside a civilian town, and not
	// inside BLUFOR's own area of influence. This is the position the mission is actually built on
	// and garrisons around, and it drifts from the anchor the strategic map cleared -- up to _radius
	// on each axis to _randomPos, then another 10-50 m off a building -- so an anchor outside
	// everything is no guarantee the objective is. Tested here as well because this is the loop that
	// can re-roll it. The friendly-AoI gate keeps a drifted objective out of the player's controlled
	// bubble; the far-side bias itself lives in the client anchor search (fnc_stratmap).
	if (_targetpos select 0 != 0 &&
		_targetpos select 1 != 0 &&
		isNull _nearRoad &&
		!([_targetpos] call fnc_pos_claimed) &&
		!([_targetpos] call fnc_aoi_blufor_covers)) then {_Posfound=true;};

	// Logged rather than left to the caller's generic abort: with zones and towns both excluded this
	// is the loop that starves first on a crowded map, and the abort alone does not say which
	// constraint could not be met.
	if (_failSafe > 50) exitWith {
		["WARN", "MISSION", format ["no clear ground within %1 m of %2 in 50 tries", _radius, _missionpos]] call fnc_log;
	};
};

_returnArray = [_randomPos, _Building, _Posfound, _targetpos, _failSafe];
_returnArray;


