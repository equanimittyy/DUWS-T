// Locality: server -- inherited from server/init_zones/fnc_createzone.sqf.
_centerSpawn = _this select 0;
// Zone construction is campaign property, filed under the zone it stands in so the whole
// composition -- turret, sandbag and camo net alike -- can be released together. A wrecked
// turret leaves its undamaged surroundings behind, and nothing about those props marks them
// as garbage; only the key knows they belonged to something.
private _zoneKey = format ["zone_%1_%2", round (_centerSpawn select 0), round (_centerSpawn select 1)];
_centerSpawnX = _centerSpawn select 0;
_centerSpawnY = _centerSpawn select 1;

private _newCenterZ = getTerrainHeightASL [_centerSpawnX, _centerSpawnY];
if (_newCenterZ <= 0) then { _newCenterZ = 0; };

private _allObjectsData = ["duws_zone_outpost_1"] call fnc_composition_rows;

private _tiltTypes = [
    "Land_HBarrierBig_F", "Land_HBarrier_5_F", "Land_BagBunker_Large_F",
    "Land_BagFence_Round_F", "Land_BagFence_Short_F", "Land_BagFence_Long_F",
    "Land_BagFence_Corner_F", "Land_BagFence_End_F", "Land_SandbagBarricade_01_hole_F",
    "Land_Razorwire_F"
];

// Cover props via the shared placer -- tilted, then frozen and hardened (cargo towers/houses excepted:
// left simulated and destructible). Weapon rows are stood up by the fnc_static_place pass below.
[_allObjectsData, [_centerSpawnX, _centerSpawnY], _zoneKey, [0, _tiltTypes, "all"]] call fnc_composition_place;

sleep 2;

private _weaponList = [];
private _origin = [_centerSpawnX, _centerSpawnY, _newCenterZ];
{
    // Index 5 is the prefab convention's isWeapon; the ground pass above placed everything else.
    if !(_x select 5) then { continue; };
    _weaponList pushBack ([_x, _origin, "opfor", _zoneKey, "world"] call fnc_static_place);
} forEach _allObjectsData;

sleep 2;
// Pass the guns this composition placed, not a class+radius search: one a search missed stayed
// frozen for the campaign, and a radius also claims a neighbouring composition's guns.
[_weaponList, _centerSpawn] call DUWS_fnc_crewCompositionStatics;

{
    _x params ["_class", "_offsetX", "_offsetY", "_dir"];
    private _obj = createVehicle [_class, [_centerSpawnX + _offsetX, _centerSpawnY + _offsetY, 0], [], 0, "CAN_COLLIDE"];
    [_obj, _zoneKey] call fnc_duws_keep;
    _obj setPosATL [_centerSpawnX + _offsetX, _centerSpawnY + _offsetY, 0];
    _obj setDir _dir;
    [_obj, "opfor"] spawn fnc_fill_ammobox;
} forEach [
    ["Box_East_Ammo_F",    -3.686,  -5.465,   8.5],
    ["Box_East_Ammo_F",     0.721,   6.906, 336.7],
    ["Box_East_Ammo_F",    -0.809,  -8.145, 280.6],
    ["Box_East_Grenades_F",-0.143,   7.285,  90.6],
    ["Box_East_AmmoOrd_F",  1.607,   6.793,  43.3]
];

// Backup camp light.
private _light1 = createVehicle ["Land_Camping_Light_F", [_centerSpawnX, _centerSpawnY, 0], [], 0, "NONE"];
[_light1, _zoneKey] call fnc_duws_keep;
_light1 setPosATL [_centerSpawnX, _centerSpawnY, 0];
_light1 allowdamage false;
_light1 setdamage 0;