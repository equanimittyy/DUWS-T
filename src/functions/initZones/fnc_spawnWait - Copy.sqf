// LOOP TO WAIT UNTIL BLUFOR CLOSE

_spawnPos = _this select 0;
_size = _this select 1;
_blufor_close = false;

while {!_blufor_close} do {

	_westUnits = [];
	_count_blu = 0;

	{
		if ((side _x) == WEST) then {
			_westUnits pushBack _x;
		};
	} forEach allUnits;

	{
		_buffer = 500;
		if (zones_max_radius < 500) then {_buffer = 300};
		if ((_spawnPos distance _x) < (_size + _buffer)) then {  // wait until BLUFOR are within 500m of perimeter
			//hint format ["Count blufor close: %1", str _count_blu];
			if ((getpos vehicle _x) select 2 < 2) then {  //not in air
				_count_blu = _count_blu + 1;
			};
			// wait until more than 2 BLUFOR to prevent trigger from
			// glitchy spawns and wandering AI or bailout pilots
			// hint format ["Count blufor close: %1", str _count_blu];
			if (_count_blu > 2) then {_blufor_close = true;};  
		};
		if (_blufor_close == true) exitWith {};
	} forEach _westUnits;
		
	// CHECK FOR PLAYERS
	{
		if ((_spawnPos distance _x) < (_size + 500)) then {
			if ((getpos vehicle _x) select 2 < 2) then {_blufor_close = true;};  //not in air
		};
	} foreach call BIS_fnc_ListPlayers;

	sleep 10;
};
