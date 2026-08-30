// Locality: server -- createVehicle is server-authoritative. Places one civilian car of class _class at
// _pos facing _dir, with its cargo stripped, and returns it. Shared by fnc_civ_traffic and the town-event
// cars.
//
// "NONE" placement so the car sits where it is put rather than being bounced to the nearest clear spot,
// which on a road is another lane or the verge. Vanilla civilian cars carry a default FirstAidKit in cargo
// -- a free medkit off every roadside spawn -- so the inventory is stripped: a stolen car yields nothing.
params ["_class", "_pos", "_dir"];
private _veh = createVehicle [_class, _pos, [], 0, "NONE"];
clearItemCargoGlobal _veh;
clearMagazineCargoGlobal _veh;
clearWeaponCargoGlobal _veh;
clearBackpackCargoGlobal _veh;
_veh setDir _dir;
_veh setPosATL _pos;
_veh
