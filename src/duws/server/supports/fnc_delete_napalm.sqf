
if (!isServer) exitWith {};
_position = _this select 0;
_radius = _this select 1;
_fireObjects = [];

{
	if (typeof _x == "#particlesource" or typeof _x == "Fire") then { 
		_fireObjects pushBack _x;
	};
} foreach (_position nearObjects (_radius + 50));

sleep 30;

{ 
	deletevehicle _x;
	sleep 1;
} foreach _fireObjects;
