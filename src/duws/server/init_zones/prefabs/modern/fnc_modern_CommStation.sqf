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
// --DUWS-COMPOSITION BEGIN name="Comm Station" schema=A--
private _allObjectsData = [
    ["Land_HBarrier_5_F", 11.7953, 5.65381, 0.74071, 92.0639, false],
    ["Land_HBarrier_5_F", 10.2622, 10.3057, 0.74071, 51.1638, false],
    ["Land_HBarrier_5_F", -11.2444, 7.2041, 0.74071, 91.4638, false],
    ["Land_HBarrier_5_F", -9.2605, 11.1406, 0.74071, 319.864, false],
    ["Land_HBarrier_5_F", -11.486, -3.98438, 0.74071, 271.864, false],
    ["Land_HBarrier_5_F", -6.03394, -10.687, 0.74071, 2.56386, false],
    ["Land_HBarrier_5_F", -9.94592, -8.62939, 0.74071, 230.864, false],
    ["Land_HBarrier_5_F", 5.0304, -11.0688, 0.74071, 180.464, false],
    ["Land_HBarrier_5_F", 11.4604, -5.49512, 0.74071, 271.264, false],
    ["Land_Cargo_Patrol_V1_F", -0.6427, -9.54541, 4.905196, 2.56386, false],
    ["Land_Cargo_House_V1_F", 6.49707, 3.82617, 0.6902, 91.6638, false],
    ["Land_Cargo_House_V1_F", -6.06482, -2.61523, 0.6902, 271.564, false],
    ["Land_HBarrier_5_F", -4.66797, 12.6694, 0.74071, 2.56386, false],
    ["Land_HBarrier_5_F", 6.33142, 12.1948, 0.74071, 2.56386, false],
    ["Land_HBarrier_5_F", -0.52417, -10.8784, 0.74071, 2.56386, false],
    ["Land_HBarrier_5_F", -11.3607, 1.59619, 0.74071, 271.764, false],
    ["Land_HBarrier_5_F", 11.5784, 0.0458984, 0.74071, 271.864, false],
    ["Land_Razorwire_F", -13.3331, 15.8843, 0.75526, 138.564, false],
    ["Land_Razorwire_F", -14.8619, -13.459, 0.75526, 50.4638, false],
    ["Land_Razorwire_F", 14.9246, 14.5527, 0.75526, 50.5639, false],
    ["Land_Razorwire_F", -18.4009, 1.42529, 0.75526, 89.3638, false],
    ["Land_Razorwire_F", -0.59314, -18.6792, 0.75526, 1.16385, false],
    ["Land_Razorwire_F", 18.5072, -0.67334, 0.75526, 89.3638, false],
    ["Land_HBarrier_1_F", 11.5977, 18.418, 0.7023, 142.364, false],
    ["Land_HBarrier_1_F", 17.8419, 10.689, 0.7023, 142.364, false],
    ["Land_HBarrier_1_F", 18.3467, 4.10645, 0.7023, 179.464, false],
    ["Land_HBarrier_1_F", 18.5701, -5.35498, 0.7023, 179.464, false],
    ["Land_HBarrier_1_F", 4.10535, -18.8076, 0.7023, 270.864, false],
    ["Land_HBarrier_1_F", -5.5481, -18.687, 0.7023, 270.864, false],
    ["Land_HBarrier_1_F", -11.918, -17.1279, 0.7023, 321.664, false],
    ["Land_HBarrier_1_F", -18.1793, -9.8418, 0.7023, 321.664, false],
    ["Land_HBarrier_1_F", -18.5294, -3.42871, 0.7023, 357.364, false],
    ["Land_HBarrier_1_F", -18.6263, 6.39014, 0.7023, 357.364, false],
    ["Land_HBarrier_1_F", -16.8909, 12.7578, 0.7023, 48.5639, false],
    ["Land_HBarrier_1_F", -9.66101, 19.1665, 0.7023, 48.5639, false],
    ["Land_HBarrier_3_F", 5.43262, 18.9692, 0.79854, 182.764, false],
    ["Land_HBarrier_3_F", -3.19043, 19.2695, 0.79854, 182.764, false],
    ["Land_PortableLight_double_F", -8.37891, 10.1074, 1.08401, 320.664, false],
    ["Land_PortableLight_double_F", 4.50903, 10.9229, 1.08401, 164.664, false],
    ["Land_PaperBox_closed_F", 9.05554, -4.3916, 0.64339, 136.064, false],
    ["Land_PaperBox_closed_F", 7.19116, -3.58496, 0.64339, 253.564, false],
    ["Land_WaterTank_F", 6.88574, 9.00439, 0.68511, 182.364, false],
    ["Land_ToiletBox_F", -9.13879, 2.36572, 1.22026, 272.364, false],
    ["Land_HBarrier_1_F", 11.2175, -8.39551, 0.7023, 226.664, false],
    ["Land_HBarrier_1_F", 8.0498, -10.9585, 0.7023, 232.164, false],
    ["Land_TTowerSmall_2_F", -5.55969, 0.116699, 8.47893, 182.764, false],
    ["Land_GarbageBarrel_01_F", -8.43433, 6.26172, 0.61404, 347.964, false],
    ["Land_ToiletBox_F", -9.04517, 4.93213, 1.22026, 272.364, false],
    ["Land_HBarrier_3_F", 15.1188, -10.8223, 0.79854, 129.364, false],
    ["Land_HBarrier_3_F", 10.0164, -15.457, 0.79854, 148.764, false],
    ["I_G_HMG_02_high_F", 0.536377, -10.6025, 6.28723, 183.964, true],
    ["Land_HelipadSquare_F", -0.362549, 1.79395, 0.000199999999999978, 182.164, false],
    ["Land_BagFence_Round_F", 0.848877, 14.0259, 0.41951, 183.964, false],
    ["I_HMG_02_high_F", 0.880371, 12.2061, 1.67994, 7.36384, true],
    ["Land_BagFence_Round_F", -8.65735, -16.9043, 0.41951, 13.9639, false],
    ["I_HMG_02_high_F", -8.37097, -15.106, 1.67994, 197.364, true],
    ["Land_BagFence_Round_F", 16.9176, -7.64014, 0.41951, 291.264, false],
    ["I_HMG_02_high_F", 15.1697, -7.13086, 1.67994, 114.564, true]
];
// --DUWS-COMPOSITION END--

private _tiltTypes = [
    "Land_HBarrierBig_F","Land_HBarrier_5_F","Land_HBarrier_3_F","Land_HBarrier_1_F",
    "Land_BagBunker_Large_F","Land_BagFence_Round_F","Land_BagFence_Short_F",
    "Land_BagFence_Long_F","Land_BagFence_Corner_F","Land_BagFence_End_F",
    "Land_SandbagBarricade_01_hole_F","Land_Razorwire_F"
];

// Cover props via the shared placer -- tilted, frozen, hardened. Weapon rows are skipped here and stood
// up by the fnc_static_place pass below.
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