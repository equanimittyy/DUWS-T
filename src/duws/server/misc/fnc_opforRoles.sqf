// Locality: any -- reads the opfor_* faction globals and returns class names; spawns nothing.
//
// Walked rather than filtered, because a faction table that omits a role leaves its global
// undefined, and an undefined name inside an array literal is not something `select` can test for
// after the fact.
//
// The fallback is not decoration: selectRandom [] returns nil, BIS_fnc_spawnGroup accepts nil in a
// class list, and the result is a group that silently spawns short with nothing logged anywhere.
params [["_roles", []]];

private _out = [];
{ if (!isNil "_x" && {_x != ""}) then { _out pushBack _x } } forEach _roles;
if (_out isEqualTo []) then { _out = [opfor_SOLDIER_X] };

_out
