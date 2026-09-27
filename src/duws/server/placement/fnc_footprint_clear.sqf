// Locality: any (a pure placement query); every caller is server-side.
//
// Rays through the class's footprint box catch anything solid before the object exists; the lowest runs under a
// car's body, so a half-wall a hand high still rejects the spot.
//
// [_class, _pos, _dir] -> true when nothing solid crosses the class's footprint at _pos facing _dir
params ["_class", "_pos", "_dir"];

([_class] call fnc_class_half_extents) params ["_hx", "_hy"];
private _s = sin _dir; private _c = cos _dir;
private _at = {
    params ["_lx", "_ly", "_h"];
    AGLToASL [(_pos select 0) + _lx * _c + _ly * _s, (_pos select 1) - _lx * _s + _ly * _c, _h]
};
// Object hits only, so a low ray grazing a bumpy verge is not read as a wall.
private _blocked = {
    params ["_a", "_b"];
    ((lineIntersectsSurfaces [_a, _b, objNull, objNull, true, 4, "GEOM"]) findIf { !isNull (_x select 2) }) >= 0
};
private _rim = [[_hx, _hy], [_hx, 0], [_hx, -_hy], [0, -_hy], [-_hx, -_hy], [-_hx, 0], [-_hx, _hy], [0, _hy]];
private _clear = true;
{
    private _h = _x;
    private _mid = [0, 0, _h] call _at;
    {
        private _p = [_x select 0, _x select 1, _h] call _at;
        private _n = _rim select ((_forEachIndex + 1) mod (count _rim));
        private _q = [_n select 0, _n select 1, _h] call _at;
        if ([_mid, _p] call _blocked || {[_p, _q] call _blocked}) exitWith { _clear = false };
    } forEach _rim;
    if (!_clear) exitWith {};
} forEach [0.2, 0.7, 1.2];
_clear
