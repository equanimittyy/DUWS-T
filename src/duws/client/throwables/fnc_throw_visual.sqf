// Locality: any interface -- createSimpleObject is local, so fnc_throw broadcasts this to every machine and
// each draws its own projectile. Cosmetic only: the landing damage/fire is the server's (fnc_throw).
if (!hasInterface) exitWith {};
params [["_kind", "stone"], ["_from", [0, 0, 0]], ["_to", [0, 0, 0]], ["_dur", 1]];

private _p3d = ["\A3\weapons_f\ammo\stone_3.p3d", "\A3\structures_f\items\food\bottleplastic_v1_f.p3d"] select (_kind == "molotov");
private _obj = createSimpleObject [_p3d, ASLToAGL _from];
if (isNull _obj) exitWith {};
if (_kind == "molotov") then { [_obj] call fnc_molotov_trail; };

[_obj, _from, _to, _dur, _kind] spawn {
	params ["_obj", "_from", "_to", "_dur", "_kind"];
	private _peak = 2 + _dur * 3;
	private _t0 = time;
	while { !isNull _obj && {(time - _t0) < _dur} } do {
		private _k = (time - _t0) / _dur;
		private _p = _from vectorAdd ((_to vectorDiff _from) vectorMultiply _k);
		// Parabola: 0 at both ends, _peak at the midpoint.
		_p set [2, (_p select 2) + 4 * _peak * _k * (1 - _k)];
		_obj setPosASL _p;
		sleep 0.02;
	};
	if (isNull _obj) exitWith {};
	_obj setPosASL _to;
	// Let the molotov settle a beat so its trail/fire reads over the object before it goes; a stone just drops.
	if (_kind == "molotov") then { sleep 1 };
	deleteVehicle _obj;
};
