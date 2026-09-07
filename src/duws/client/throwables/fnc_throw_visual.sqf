// Locality: any interface -- createSimpleObject is local, so fnc_throw broadcasts this to every machine and
// each simulates its own projectile. Cosmetic only: the landing damage/fire is the server's (fnc_throw).
if (!hasInterface) exitWith {};
params [["_kind", "stone"], ["_from", [0, 0, 0]], ["_to", [0, 0, 0]], ["_dur", 1]];

private _p3d = ["\A3\weapons_f\ammo\stone_3.p3d", "\A3\structures_f\items\food\bottleplastic_v1_f.p3d"] select (_kind == "molotov");
// 2-arg createSimpleObject is a simulated body, so PhysX flies it and bounces it off walls/vehicles. A scripted
// per-frame setPos arc cannot -- it teleports through geometry. So: launch with setVelocity, never setPos it.
private _obj = createSimpleObject [_p3d, ASLToAGL _from];
if (isNull _obj) exitWith {};
_obj enableSimulation true;
if (_kind == "molotov") then { [_obj] call fnc_molotov_trail; };

// Ballistic launch: the velocity that reaches _to in _dur under gravity. Vertical term counters the drop over
// the flight; PhysX takes it from there, including any bounce off geometry in the way.
private _g = 9.81;
private _d = _to vectorDiff _from;
_obj setVelocity [(_d select 0) / _dur, (_d select 1) / _dur, ((_d select 2) + 0.5 * _g * _dur * _dur) / _dur];

// Bin it after it has landed and settled; molotov gets the same window so its trail/fire reads over it.
[_obj, _dur] spawn {
	params ["_obj", "_dur"];
	sleep (_dur + 3);
	if (!isNull _obj) then { deleteVehicle _obj };
};
