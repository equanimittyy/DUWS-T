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
if (_out isEqualTo []) then {
    // Vanilla rather than opfor_SOLDIER_X: this branch is reached exactly when the faction table
    // resolved none of the roles asked for, so the rifleman cannot be assumed to exist either --
    // falling back to it would hand nil straight back. A vanilla class resolves with no mod loaded.
    _out = if (isNil "opfor_SOLDIER_X") then { ["O_Soldier_F"] } else { [opfor_SOLDIER_X] };
    ["WARN", "FACTION", format ["opforRoles: none of the %1 roles asked for resolved, using %2",
        count _roles, _out select 0]] call fnc_log;
};

_out
