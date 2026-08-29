// Locality: server -- spawns nothing; called from the garrison placers and the town selector.

// Enterable buildings only -- a building with fewer than 3 positions reads as unenterable (clamped below).

params ["_location","_positions_needed", "_radius"];

if (_positions_needed < 3) then {_positions_needed = 3};
_nearBuildings = [];
_nearBuildings = nearestTerrainObjects [_location, ["House"], _radius, true];

_usableBuildings = [];
{
	_bPos = _x buildingPos _positions_needed;
	if not ((_bPos select 0) == 0) then	{
		_usableBuildings pushBack _x;
	};
} foreach _nearBuildings;

_usableBuildings