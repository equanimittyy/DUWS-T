
//find buildings with a minimum of 2 positions to avoid "unenterable" buildings

params ["_location","_positions_needed", "_radius"];

if (_positions_needed < 3) then {_positions_needed = 3};
_nearBuildings = [];
_nearBuildings = nearestTerrainObjects [_location, ["House"], _radius, true];

// only use buildings with num positions >= num positions needed
_usableBuildings = [];
{
	_bPos = _x buildingPos _positions_needed;
	if not ((_bPos select 0) == 0) then	{
		_usableBuildings pushBack _x;
	};
} foreach _nearBuildings;

_usableBuildings