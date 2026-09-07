// Locality: server -- spawns the fire and owns the radius burn where a thrown molotov lands. Called by
// fnc_throw when a "molotov" lob impacts; server-side, so the fire objects and the burn network to all.
if (!isServer) exitWith {};
params [["_pos", [0,0,0]], ["_radius", 5], ["_dur", 15]];

// test_EmptyObjectForFireBig burns for only ~2-3s and then self-extinguishes (arma_engine_gotchas.md), so
// one spawn cannot hold a fire for _dur. Napalm hides this by spawning fresh ones every salvo; here a short
// refresh does it -- each cycle lights a new scattered batch, then deletes the previous so the flame never
// gaps. Kept to a small napalm-style carpet: the object is a heavy particle-and-light emitter.
#define FIRE_COUNT 3
#define FIRE_REFRESH 2

[_pos, _radius, _dur] spawn {
	params ["_pos", "_radius", "_dur"];
	private _spread = _radius min 3;
	private _end = time + _dur;
	private _fires = [];
	private _nextFire = 0;
	while { time < _end } do {
		if (time >= _nextFire) then {
			_nextFire = time + FIRE_REFRESH;
			private _new = [];
			for "_i" from 1 to FIRE_COUNT do {
				private _fp = [(_pos select 0) + (random _spread) - (random _spread), (_pos select 1) + (random _spread) - (random _spread), _pos select 2];
				private _f = createVehicle ["test_EmptyObjectForFireBig", _fp, [], 0, "CAN_COLLIDE"];
				_f setPosATL _fp;
				_new pushBack _f;
			};
			// Delete the old batch only after the new is lit, so the two overlap and the fire never blinks out.
			{ if (!isNull _x) then { deleteVehicle _x } } forEach _fires;
			_fires = _new;
		};
		{ if (alive _x) then { _x setDamage (((damage _x) + 0.06) min 1) } } forEach (_pos nearEntities [["Man", "Car", "Motorcycle", "Tank", "Air"], _radius]);
		sleep 1;
	};
	{ if (!isNull _x) then { deleteVehicle _x } } forEach _fires;
};
