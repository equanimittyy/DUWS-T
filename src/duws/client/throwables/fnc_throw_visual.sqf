// Locality: any interface -- createSimpleObject is local, so fnc_throw broadcasts this to every machine and
// each draws its own stone. Cosmetic only: the landing camera knock is the server's (fnc_throw).
if (!hasInterface) exitWith {};
params [["_from", [0, 0, 0]], ["_to", [0, 0, 0]], ["_dur", 1]];

private _obj = createSimpleObject ["\A3\weapons_f\ammo\stone_3.p3d", ASLToAGL _from];
if (isNull _obj) exitWith {};

// Frame-synced flight: an EachFrame handler steps the arc by real elapsed time, so it stays smooth whatever
// the scheduler does. A spawn + sleep loop advances in scheduler ticks, not frames, and visibly stutters.
private _peak = 2 + _dur * 3;
addMissionEventHandler ["EachFrame", {
	_thisArgs params ["_obj", "_from", "_to", "_dur", "_peak", "_t0"];
	if (isNull _obj) exitWith { removeMissionEventHandler ["EachFrame", _thisEventHandler] };
	private _k = (diag_tickTime - _t0) / _dur;
	if (_k >= 1) exitWith {
		_obj setPosASL _to;
		removeMissionEventHandler ["EachFrame", _thisEventHandler];
		deleteVehicle _obj;
	};
	private _p = _from vectorAdd ((_to vectorDiff _from) vectorMultiply _k);
	// Parabola: 0 at both ends, _peak at the midpoint.
	_p set [2, (_p select 2) + 4 * _peak * _k * (1 - _k)];
	_obj setPosASL _p;
	_obj setDir (getDir _obj + 4);   // slow tumble so it reads as thrown, not sliding
}, [_obj, _from, _to, _dur, _peak, diag_tickTime]];
