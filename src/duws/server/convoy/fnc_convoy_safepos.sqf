// Locality: any (a pure placement query); the convoy callers are server-side.
//
// Return a valid on-land point near _pos for a convoy ROUTE ANCHOR -- a start road or a patrol point, not a
// specific hull (seating a hull against its own footprint is fnc_convoy_fit). findSafePos looks for clear
// land within _radius; on failure it returns [0,0,0], the map origin out at sea, so a bare result would
// fling the anchor kilometres from the AO. Any failure -- empty, origin, or water -- falls back to the
// requested point, keeping the anchor where the caller meant it.
//
// [_pos, _radius, _objDist] -> _validPos
params ["_pos", ["_radius", 200], ["_objDist", 5]];
private _p = [_pos, 0, _radius, _objDist, 0, 0.5, 0] call BIS_fnc_findSafePos;
if (_p isEqualTo [] || {_p isEqualTo [0, 0, 0]} || {surfaceIsWater _p}) exitWith { _pos };
_p
