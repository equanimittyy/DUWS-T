// Locality: server -- hideObjectGlobal is a server command whose effect is global and carried to
// join-in-progress clients. Run from a client, the foliage vanishes on that machine alone.

params ["_pos", ["_radius", 50]];

// Foliage only, never buildings: a terrain object cannot be deleted, so anything caught here stays
// hidden for the rest of the campaign, and an invisible house is a worse trade at a base site than
// a tree standing through a tent. No BuildingChanged register for the same reason -- that event
// swaps a damaged *building* for a fresh visible one, and nothing here is a building.
private _foliage = nearestTerrainObjects [_pos, ["TREE", "SMALL TREE", "BUSH"], _radius, false];
{ _x hideObjectGlobal true } forEach _foliage;

["INFO", "TERRAIN", format ["Cleared %1 foliage objects within %2 m of %3", count _foliage, _radius, _pos]] call fnc_log;
