// Locality: any -- reads the faction role globals and returns class names; spawns nothing.
//
// Walked rather than filtered, because a faction table that omits a role leaves its global
// undefined, and an undefined name inside an array literal is not something `select` can test for
// after the fact.
//
// The fallback is not decoration: selectRandom [] returns nil, BIS_fnc_spawnGroup accepts nil in a
// class list, and the result is a group that silently spawns short with nothing logged anywhere.
//
// _side decides which army the fallback comes from, and is required rather than defaulted. A shared
// team roster is raised by either army now, so a default is a caller that forgot to say getting one
// enemy rifleman inside a friendly squad, on the player's side of the line.
params [["_roles", []], "_side"];

private _out = [];
{ if (!isNil "_x" && {_x != ""}) then { _out pushBack _x } } forEach _roles;
if (_out isEqualTo []) then {
    // This branch is reached exactly when the faction table resolved none of the roles asked for,
    // so the side's own rifleman cannot be assumed to exist either -- naming it outright would hand
    // nil straight back. Asked for by name instead, and a vanilla class resolves with no mod loaded.
    // isNil leads because the picker is only meaningful for a key that exists; a global the faction
    // never assigned is undefined rather than empty, and only isNil answers that directly.
    private _key = format ["%1_SOLDIER_X", _side];
    private _rifleman = if (isNil _key) then { "" } else { [_key] call fnc_faction_pick };
    if (_rifleman isEqualTo "") then {
        _rifleman = if (_side isEqualTo "blufor") then { "B_Soldier_F" } else { "O_Soldier_F" };
    };
    _out = [_rifleman];
    ["WARN", "FACTION", format ["factionRoles: none of the %1 %2 roles asked for resolved, using %3",
        count _roles, _side, _rifleman]] call fnc_log;
};

_out
