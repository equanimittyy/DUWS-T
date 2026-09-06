// Locality: any interface -- attaches a local flame/smoke emitter to the molotov bottle _p and removes it
// once _p is gone or 15 s pass. Broadcast to every machine from the thrower's Fired handler (client_init).
if (!hasInterface) exitWith {};
params [["_p", objNull]];
if (isNull _p) exitWith {};

private _trail = "test_EmptyObjectForFireSmall" createVehicleLocal (getPosATL _p);
_trail attachTo [_p, [0, 0, 0]];
[_p, _trail] spawn {
	params ["_p", "_trail"];
	private _end = time + 15;
	waitUntil { sleep 0.2; isNull _p || {time > _end} };
	deleteVehicle _trail;
};
