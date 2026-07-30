// Locality: server -- createVehicle is global, so exactly one machine may run the drop.
//
// Scatters items within a metre of a position. Created at [0,0,0] and moved, rather than created
// in place: createVehicle's own placement nudges an object to somewhere it fits, which for a
// handful of items dropped together spreads them further than the metre intended.
params ["_items", "_basePosATL"];

{
    private _obj = createVehicle [_x, [0,0,0], [], 0, "CAN_COLLIDE"];
    private _spawnPos = _basePosATL getPos [random 1, random 360];
    // Lifted clear of the surface: an item written exactly at ground level can settle inside it.
    _spawnPos set [2, (_basePosATL select 2) + 0.05];
    _obj setPosATL _spawnPos;
} forEach _items;
