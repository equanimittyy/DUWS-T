// Locality: server. [_class] -> [hx, hy], the footprint half-extents along model X and Y.
// boundingBoxReal is model-space, so a throwaway probe's box equals the placed object's: measured once per
// class (cached mission-wide), a footprint is known before spawning instead of spawning and then rejecting
// on overlap. Each axis takes the larger of min and max, since a model's origin need not sit mid-box.
params ["_class"];
private _cache = missionNamespace getVariable ["DUWS_classHalfExtents", createHashMap];
private _d = _cache getOrDefault [_class, []];
if (_d isNotEqualTo []) exitWith { _d };
private _p = createVehicleLocal [_class, [0, 0, 0], [], 0, "CAN_COLLIDE"];
private _bb = boundingBoxReal _p;
deleteVehicle _p;
_d = [(abs ((_bb select 0) select 0)) max (abs ((_bb select 1) select 0)),
      (abs ((_bb select 0) select 1)) max (abs ((_bb select 1) select 1))];
_cache set [_class, _d];
missionNamespace setVariable ["DUWS_classHalfExtents", _cache];
_d
