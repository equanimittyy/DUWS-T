// Locality: server -- spawns the fire and owns the radius burn where a thrown molotov lands. Called by
// fnc_throw when a "molotov" lob impacts; server-side, so the fire objects and the burn network to all.
if (!isServer) exitWith {};
params [["_pos", [0,0,0]], ["_radius", 5], ["_dur", 15]];

// A small carpet of flame like the napalm strike (fnc_arty): a few test_EmptyObjectForFireBig scattered over
// the splash. The object burns for as long as it lives, so it is spawned once and deleted only at the end --
// deleting a burning one puffs dying smoke, so refreshing it mid-burn reads as smog rather than fire.
private _fires = [];
private _spread = _radius min 3;
for "_i" from 1 to 3 do {
	private _fp = [(_pos select 0) + (random _spread) - (random _spread), (_pos select 1) + (random _spread) - (random _spread), _pos select 2];
	private _f = createVehicle ["test_EmptyObjectForFireBig", _fp, [], 0, "CAN_COLLIDE"];
	_f setPosATL _fp;
	_fires pushBack _f;
};

[_fires, _pos, _radius, _dur] spawn {
	params ["_fires", "_pos", "_radius", "_dur"];
	private _end = time + _dur;
	while { time < _end } do {
		{ if (alive _x) then { _x setDamage (((damage _x) + 0.06) min 1) } } forEach (_pos nearEntities [["Man", "Car", "Motorcycle", "Tank", "Air"], _radius]);
		sleep 1;
	};
	// Staggered like the napalm cleanup so the fires wink out one by one, not in one shared puff of smoke.
	{ if (!isNull _x) then { deleteVehicle _x }; sleep 2; } forEach _fires;
};
