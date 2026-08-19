// Locality: anywhere (pure config read). Names a position by the settlement it sits by, for
// player-facing "near %1" briefs. The nearest named location within a 5 km ring wins; a grid
// reference stands in when nothing named is in reach. The DUWS zone the position is in is
// deliberately not named -- the settlement alone locates the objective for the player.
// [_pos] -> settlement name, or "grid XXXX".
params ["_pos"];
private _place = format ["grid %1", mapGridPosition _pos];
{
    if (text _x != "") exitWith { _place = text _x };
} forEach nearestLocations [_pos, ["NameCityCapital", "NameCity", "NameVillage", "NameLocal", "NameMarine"], 5000];
_place
