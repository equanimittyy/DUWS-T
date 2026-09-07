// Locality: server -- spawns the fire and owns the radius burn where a thrown molotov lands. Called by
// fnc_throw when a "molotov" lob impacts; server-side, so the fire objects and the burn network to all.
if (!isServer) exitWith {};
params [["_pos", [0,0,0]], ["_radius", 5], ["_dur", 15]];

// A small carpet of flame, spawned the way the napalm strike does it (fnc_arty): several of the same fire
// emitter scattered over the splash so it reads as a patch of fire, not one point. Count kept low -- the
// object is a heavy particle-and-light emitter and up to three molotovs can land at once.
private _fires = [];
private _spread = _radius min 3;
for "_i" from 1 to 3 do {
	private _fp = [(_pos select 0) + (random _spread) - (random _spread), (_pos select 1) + (random _spread) - (random _spread), _pos select 2];
	private _f = "test_EmptyObjectForFireBig" createVehicle _fp;
	_f setPosATL _fp;
	_fires pushBack _f;
};

[_fires, _pos, _radius, _dur] spawn {
	params ["_fires", "_pos", "_radius", "_dur"];
	private _end = time + _dur;
	while { time < _end } do {
		{
			if (alive _x) then { _x setDamage (((damage _x) + 0.06) min 1) };
		} forEach (_pos nearEntities [["Man", "Car", "Motorcycle", "Tank", "Air"], _radius]);
		sleep 1;
	};
	{ if (!isNull _x) then { deleteVehicle _x } } forEach _fires;
};
