// Locality: server -- hideObjectGlobal is a server command whose effect is global and carried to
// join-in-progress clients. Run from a client, the foliage vanishes on that machine alone.

params ["_pos", ["_radius", 50]];

// Foliage only, and permanently hidden: structures go through fnc_clear_buildings, which carries the
// BuildingChanged register that a hidden building needs and a hidden bush does not.
private _foliage = nearestTerrainObjects [_pos, ["TREE", "SMALL TREE", "BUSH"], _radius, false];
{ _x hideObjectGlobal true } forEach _foliage;

["INFO", "TERRAIN", format ["Cleared %1 foliage objects within %2 m of %3", count _foliage, _radius, _pos]] call fnc_log;
