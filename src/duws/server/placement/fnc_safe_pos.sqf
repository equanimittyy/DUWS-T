// Locality: any (pure placement query); every caller is server-side.
//
// BIS_fnc_findSafePos signals no failure of its own: a miss returns its default position, and with none given that
// is a far point on land that passes any origin or water test (arma_engine_gotchas.md). The [0,0] default makes a
// miss detectable. This returns clear land near _pos, or _fallback on failure: _pos when omitted, or [] when the
// caller passes [] to handle the miss itself.
//
// [_pos, _radius, _minDist, _objDist, _grad, _fallback] -> land pos | _fallback
params ["_pos", ["_radius", 200], ["_minDist", 0], ["_objDist", 5], ["_grad", 0.5], "_fallback"];
if (isNil "_fallback") then { _fallback = _pos };
private _p = [_pos, _minDist, _radius, _objDist, 0, _grad, 0, [], [[0, 0], [0, 0]]] call BIS_fnc_findSafePos;
if (((_p select 0) == 0 && {(_p select 1) == 0}) || {surfaceIsWater _p}) exitWith { _fallback };
_p
