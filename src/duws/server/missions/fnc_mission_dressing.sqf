// Locality: server. Cosmetic clutter beside a mission vehicle: three barrel-nets and a camo net,
// staggered along -x from the given centre so the vehicle looks like a parked, in-use asset rather
// than a lone spawn. The caller bakes any offset into the centre it passes, so this needs no offset
// argument -- steal-supply clusters the clutter south of the truck, steal-builder on it.
//
// MODERN only: the classes are the modern faction's props. Other version sets get bare ground, as
// the inline blocks this replaces did (they left the class strings empty and spawned nothing usable).
// Each piece is kept under the caller's composition key so fnc_mission_end bins it with the rest.
params ["_centre", "_compKey"];
if (VERSION_X != "MODERN") exitWith {};

private _cx = _centre select 0;
private _cy = _centre select 1;
{
    _x params ["_cls", "_dx"];
    private _obj = createVehicle [_cls, [_cx + _dx, _cy], [], 0, "CAN_COLLIDE"];
    [_obj, _compKey] call fnc_duws_keep;
    sleep 1;
} forEach [
    ["CargoNet_01_barrels_F", -12],
    ["CargoNet_01_barrels_F", -10],
    ["CargoNet_01_barrels_F", -8],
    ["CamoNet_INDP_open_F", -10]
];
