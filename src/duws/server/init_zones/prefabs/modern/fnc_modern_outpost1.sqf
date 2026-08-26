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

// Each row: [class, offsetX, offsetY, offsetZ, dir, isWeapon].
// --DUWS-COMPOSITION BEGIN name="Outpost 1" schema=A--
private _allObjectsData = [
    ["I_HMG_02_high_F", -7.43359, 25.0708, 1.85828, 0, true],
    ["I_HMG_02_high_F", 6.37109, -29.4487, 1.85828, 180, true],
    ["I_HMG_02_high_F", -9.94666, -22.7729, 6.02398, 177.6, true],
    ["I_HMG_02_high_F", -24.1992, 4.53369, 1.67994, 273, true],
    ["I_HMG_02_high_F", 8.9248, 21.7534, 6.02398, 0, true],
    ["Land_BagFence_Round_F", -25.8027, 4.59814, 0.41951, 87.9, false],
    ["Land_GarbageBags_F", 8.23633, 1.39502, 0.43383, 0, false],
    ["Land_GarbageHeap_03_F", -13.292, 18.541, 0.52727, 0, false],
    ["Land_HBarrierBig_F", 12.8906, -23.2378, 1.2102, 0.8, false],
    ["Land_BagBunker_Large_F", 4.02539, -26.2456, 0.88989, 0.8, false],
    ["Land_PortableLight_double_F", -10.7266, -24.396, 1.08401, 0.8, false],
    ["Land_ToiletBox_F", 19.2832, 10.0083, 1.22026, 90.3, false],
    ["Land_WaterTank_F", -18.7188, -8.29834, 0.68511, 358.9, false],
    ["Land_HBarrierBig_F", 20.6113, -20.1616, 1.2102, 318.5, false],
    ["Land_HBarrierBig_F", 24.0156, -12.6304, 1.2102, 272.9, false],
    ["Land_HBarrier_5_F", -7.61719, -25.7397, 0.74071, 0.8, false],
    ["Land_HBarrier_5_F", -13.1602, -25.6753, 0.74071, 0.8, false],
    ["Land_HBarrier_5_F", -5.47461, -22.1851, 0.74071, 272.1, false],
    ["Land_HBarrierBig_F", -17.0176, -22.2065, 1.2102, 272.4, false],
    ["Land_HBarrierBig_F", -20.6133, -15.2964, 1.2102, 217.5, false],
    ["Land_HBarrierBig_F", -24.0645, -7.9585, 1.2102, 272.4, false],
    ["Land_HBarrierBig_F", -18.6973, -4.7749, 1.2102, 0.8, false],
    ["Land_HBarrierBig_F", -13.5625, 21.1509, 1.2102, 178.7, false],
    ["Land_BagBunker_Large_F", -4.75, 21.7837, 0.88989, 178.7, false],
    ["Land_PortableLight_double_F", 9.80273, 23.1353, 1.08401, 178.7, false],
    ["Land_HBarrierBig_F", -21.1523, 17.7954, 1.2102, 136.3, false],
    ["Land_HBarrierBig_F", -24.1133, 10.6294, 1.2102, 90.6, false],
    ["Land_HBarrier_5_F", 6.6582, 24.5669, 0.74071, 178.7, false],
    ["Land_HBarrier_5_F", 12.1992, 24.6938, 0.74071, 178.7, false],
    ["Land_HBarrier_5_F", 4.64844, 20.9146, 0.74071, 89.9, false],
    ["Land_HBarrierBig_F", 16.1934, 21.3774, 1.2102, 90.3, false],
    ["Land_HBarrierBig_F", 20.0293, 14.5903, 1.2102, 35.4, false],
    ["Land_HBarrierBig_F", 23.7559, 7.39307, 1.2102, 90.3, false],
    ["Land_HBarrier_5_F", 24.1465, 0.26416, 0.74071, 90.8, false],
    ["Land_HBarrierBig_F", 18.5215, 4.0083, 1.2102, 178.7, false],
    ["Land_HBarrier_5_F", 24.0234, -5.37256, 0.74071, 90.8, false],
    ["Land_Cargo20_military_green_F", 13.8574, 0.344238, 1.32451, 180.7, false],
    ["Land_HBarrier_5_F", -11.4629, -4.91553, 0.74071, 0.8, false],
    ["Land_HBarrier_5_F", 11.293, 3.81689, 0.74071, 0.6, false],
    ["Land_ToiletBox_F", 19.3301, 7.8208, 1.22026, 90.3, false],
    ["Land_WaterBarrel_F", -9.54883, -7.23584, 0.56695, 189.7, false],
    ["Land_PortableLight_double_F", -19.7227, 16.2212, 1.08401, 314.9, false],
    ["Land_PortableLight_double_F", -15.8047, -17.1382, 1.08401, 241.5, false],
    ["Land_Cargo20_military_green_F", 20.6582, -8.66943, 1.32451, 89.6, false],
    ["Land_Cargo_Patrol_V1_F", 10.3125, 20.3169, 4.905196, 178.8, false],
    ["Land_Cargo_Patrol_V1_F", -11.0332, -21.4097, 4.905196, 0.1, false],
    ["Land_Pallets_F", 14.9492, 6.53174, 0.31852, 354.9, false],
    ["Land_MetalBarrel_F", -10.8008, -7.92725, 0.42287, 297.4, false],
    ["I_static_AA_F", -15.1704, 12.4702, 0.98343, 6.96169, true],
    ["I_static_AA_F", 12.2748, -14.583, 0.98343, 183.743, true],
    ["Land_BagFence_Round_F", 7.35559, 27.4692, 0.41951, 257.072, false],
    ["I_static_AT_F", 5.15588, 26.9292, 0.98173, 353.101, true],
    ["Land_BagFence_Round_F", -8.24023, -28.1763, 0.41951, 86.8726, false],
    ["I_static_AT_F", -5.98071, -28.0186, 0.98173, 182.902, true],
    ["Land_Razorwire_F", 12.5715, 27.0698, 0.75526, 0, false],
    ["Land_Razorwire_F", -13.0522, -27.7612, 0.75526, 0, false]
];
// --DUWS-COMPOSITION END--

private _tiltTypes = [
    "Land_HBarrierBig_F", "Land_HBarrier_5_F", "Land_BagBunker_Large_F",
    "Land_BagFence_Round_F", "Land_BagFence_Short_F", "Land_BagFence_Long_F",
    "Land_BagFence_Corner_F", "Land_BagFence_End_F", "Land_SandbagBarricade_01_hole_F",
    "Land_Razorwire_F"
];

// Cover props via the shared placer -- tilted, frozen, fragile props hardened. Land_Cargo_Patrol_V1_F
// stays simulated, as before. Weapon rows are stood up by the fnc_static_place pass below.
[_allObjectsData, [_centerSpawnX, _centerSpawnY], _zoneKey, [0, _tiltTypes, ["Land_WaterTank_F","Land_WaterBarrel_F","Land_MetalBarrel_F","Land_Pallets_F","Land_ToiletBox_F","Land_Cargo20_military_green_F"], ["Land_Cargo_Patrol_V1_F"]]] call fnc_composition_place;

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