// Locality: server -- spawns the fire and owns the radius burn where the molotov lands. remoteExec'd to the
// server from the thrower's Fired handler (client_init).
if (!isServer) exitWith {};
params [["_pos", [0,0,0]], ["_radius", 5], ["_dur", 15]];

private _fire = createVehicle ["test_EmptyObjectForFireBig", _pos, [], 0, "CAN_COLLIDE"];
_fire setPosATL _pos;

[_fire, _pos, _radius, _dur] spawn {
	params ["_fire", "_pos", "_radius", "_dur"];
	private _end = time + _dur;
	while { time < _end } do {
		{
			if (alive _x) then { _x setDamage (((damage _x) + 0.06) min 1) };
		} forEach (_pos nearEntities [["Man", "Car", "Motorcycle", "Tank", "Air"], _radius]);
		sleep 1;
	};
	if (!isNull _fire) then { deleteVehicle _fire };
};
