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

// Objects that must keep simulation: animated, drivable or interactable.
private _keepSimulation = [
    "Land_Campfire_F",
    "Land_TentDome_F",
    "Land_BagBunker_Tower_F",
    "Land_Cargo_Patrol_V1_F",
    "Land_Cargo_Tower_V1_F"
];

// Each row: [class, offsetX, offsetY, offsetZ, dir, isWeapon].
// --DUWS-COMPOSITION BEGIN name="Recon Outpost" schema=A--
private _allObjectsData = [
    ["Land_Campfire_F", 2.07837, 0.423828, 0.220279, 210, false],
    ["Land_WoodPile_F", 5.72485, 1.771, 0.26063, 277.8, false],
    ["Land_Sleeping_bag_F", 4.42407, -2.36719, 0.026516, 317.5, false],
    ["Land_Sleeping_bag_F", 2.20337, -3.50586, 0.026516, 357.9, false],
    ["Land_BagFence_Round_F", -14.4607, 5.20312, 0.420007, 113.6, false],
    ["Land_BagFence_Round_F", -12.3083, 6.05811, 0.420007, 200.2, false],
    ["Land_BagFence_Round_F", -13.8083, 3, 0.420007, 29.3, false],
    ["Land_Camping_Light_F", 0.179932, 1.40967, 0.11937, 178.7, false],
    ["Land_Sleeping_bag_brown_F", 5.89087, -0.193359, 0.026516, 281.5, false],
    ["Land_BagFence_Round_F", 4.35376, -13.9336, 0.420007, 2.5, false],
    ["Land_Axe_F", 4.82056, 1.19141, 0.0278602, 24.9, false],
    ["Land_CanisterPlastic_F", -1.05054, -2.05322, 0.348518, 209, false],
    ["Land_FMradio_F", 3.05493, -2.59424, 0.0733042, 171.8, false],
    ["Land_TinContainer_F", -0.378662, -2.5415, 0.100071, 269.5, false],
    ["Land_CanisterPlastic_F", -0.702881, -2.61328, 0.348518, 78.4, false],
    ["Land_BakedBeans_F", 3.99829, 1.28076, 0.0597858, 266.6, false],
    ["Land_MetalWire_F", 4.65259, 2.94141, 0.00330877, 207.2, false],
    ["Land_Gloves_F", 4.6311, 1.10889, 0.000614166, 281.1, false],
    ["Land_Sacks_heap_F", -1.21069, 6.47607, 0.391482, 93.1, false],
    ["Land_CampingChair_V1_F", -0.341553, 0.76709, 0.508352, 280.4, false],
    ["Land_Bucket_F", 6.12524, 5.0625, 0.166041, 246.3, false],
    ["Land_CampingChair_V1_F", 1.69165, 3.03076, 0.508352, 346.7, false],
    ["Land_Razorwire_F", 17.5641, -11.0073, 0.755762, 316.3, false],
    ["Land_Razorwire_F", 21.891, -3.81006, 0.755762, 284.5, false],
    ["Land_Razorwire_F", -11.2927, -3.56689, 0.755762, 72.4, false],
    ["Land_Razorwire_F", -6.99194, -10.0879, 0.755762, 40.7, false],
    ["Land_BagFence_Short_F", 6.28735, -13.0786, 0.414979, 315.2, false],
    ["Land_BagFence_Short_F", 2.42407, -12.8618, 0.414979, 224.3, false],
    ["Land_CanisterPlastic_F", 16.7438, -5.00586, 0.348518, 99.9, false],
    ["Land_TentDome_F", 1.86743, 8.47852, 0.619941, 267, false],
    ["Land_TentDome_F", 6.13306, 7.87061, 0.619941, 280.8, false],
    ["Land_Garbage_square5_F", 1.96313, 3.10889, 0.0401311, 189.4, false],
    ["Land_BagBunker_Tower_F", 15.2249, 5.02344, 2.21072, 253.9, false],
    ["I_G_HMG_02_high_F", -3.93335, 12.5117, 1.68063, 325.5, true],
    ["I_G_HMG_02_high_F", -12.9271, 4.67236, 1.68063, 284, true],
    ["I_G_HMG_02_high_F", 4.22876, -12.3501, 1.68063, 175.5, true],
    ["I_G_HMG_02_high_F", 17.1467, 5.146, 4.46064, 91.2, true],
    ["Land_BagFence_Round_F", -5.68921, 12.8359, 0.420007, 99.9, false],
    ["Land_BagFence_Round_F", -3.80444, 14.1953, 0.420007, 187.5, false],
    ["Land_BagFence_Short_F", -5.19897, 10.8335, 0.414979, 58.2, false],
    ["Land_BagFence_Short_F", -2.16968, 12.9292, 0.414979, 55.2, false],
    ["Land_Sleeping_bag_brown_F", -8.80835, 0.237793, 0.026516, 135.5, false],
    ["Land_Sleeping_bag_brown_F", -2.88062, -3.03516, 0.026516, 284.1, false],
    ["Land_Sleeping_bag_F", -6.1521, 1.16992, 0.026516, 182.6, false],
    ["Land_Sleeping_bag_F", -3.70093, -0.119629, 0.026516, 230.3, false],
    ["Land_Sleeping_bag_F", -4.90601, -5.48438, 0.026516, 337.4, false],
    ["Land_Sleeping_bag_brown_F", -9.70288, -2.24463, 0.026516, 91.1, false],
    ["Land_Campfire_F", -6.35327, -2.31689, 0.220279, 27.4, false],
    ["Land_WoodPile_F", -7.75366, -5.3208, 0.26063, 120.2, false],
    ["Land_Ammobox_rounds_F", -8.01147, 1.04248, 0.106058, 80.3, false],
    ["Land_Ammobox_rounds_F", -7.62085, 0.995605, 0.106058, 36.8, false],
    ["Land_CratesShabby_F", 16.8706, -3.92822, 0.760534, 358.4, false],
    ["Land_Sacks_heap_F", 15.9059, -6.6499, 0.391482, 27.1, false],
    ["Land_Matches_F", -6.92749, -1.4707, 0.0117965, 5, false],
    ["Land_ButaneCanister_F", -3.48608, 10.4609, 0.100182, 60.5, false],
    ["Land_CanisterPlastic_F", -3.9939, 10.082, 0.348518, 266.7, false],
    ["Land_Canteen_F", -8.92944, -2.97656, 0.130985, 73.4, false],
    ["Land_DuctTape_F", -8.60132, -3.01367, 0.0256953, 33.6, false],
    ["Land_GasCanister_F", -3.32202, 10.6152, 0.0559797, 96.2, false],
    ["Land_BakedBeans_F", -6.34741, -5.16406, 0.0597858, 333.9, false],
    ["Land_BakedBeans_F", -6.17944, -5.17969, 0.0597858, 30.6, false],
    ["Land_Canteen_F", -3.6521, -1.42969, 0.130985, 43.1, false],
    ["Land_PainKillers_F", -3.77905, -1.17188, 0.0432186, 5, false],
    ["Land_Bandage_F", -3.20679, 10.4707, 0.0258865, 350.7, false],
    ["Land_Bandage_F", -3.34546, 10.4429, 0.0258865, 82.3, false],
    ["Land_Axe_fire_F", -8.36108, -4.32227, 0.0281787, 5.8, false],
    ["Land_WoodenBox_F", 17.451, -5.46484, 0.000695229, 290.3, false],
    ["Land_WoodenBox_F", 18.0541, -3.12842, 0.000695229, 250.2, false],
    ["Land_Garbage_square3_F", -6.47437, -4.23828, 0.0526114, 198.8, false],
    ["Land_TTowerSmall_2_F", 14.2489, 0.650391, 8.47943, 178.375, false],
    ["Land_TBox_F", 16.2897, 0.634277, 1.70755, 345.734, false],
    ["Land_HBarrier_5_F", 19.3862, 0.416992, 0.74121, 74.0217, false],
    ["Land_HBarrier_5_F", 19.2687, -4.75879, 0.74121, 115.833, false],
    ["Land_HBarrier_5_F", 16.0093, -9.09619, 0.74121, 138.828, false],
    ["Land_HBarrier_5_F", 11.3506, -11.7412, 0.74121, 341.995, false],
    ["Land_Razorwire_F", 22.4609, 4.55615, 0.755762, 85.4453, false],
    ["Land_Razorwire_F", 10.4813, -14.8105, 0.755762, 170.311, false],
    ["Land_HBarrier_5_F", 16.3109, 11.4062, 0.74121, 74.4692, false],
    ["Land_HBarrier_5_F", 13.297, 15.1489, 0.74121, 27.5659, false],
    ["Land_HBarrier_5_F", 8.04541, 16.6411, 0.74121, 6.24766, false],
    ["CamoNet_BLUFOR_open_F", 8.01892, 12.0376, 1.16854, 196.646, false],
    ["CamoNet_BLUFOR_open_F", 7.71741, -8.65234, 1.16854, 347.478, false],
    ["Land_Sacks_heap_F", 14.7701, -7.72363, 0.391482, 344.137, false],
    ["Land_CratesWooden_F", 12.8402, -9.05811, 0.739696, 340.219, false],
    ["Land_CratesWooden_F", 10.1125, -9.74414, 0.739696, 177.22, false],
    ["Box_FIA_Ammo_F", 11.1573, -7.33936, 1.36147, 0, false]
];
// --DUWS-COMPOSITION END--

private _tiltTypes = [
    "Land_HBarrierBig_F", "Land_HBarrier_5_F", "Land_BagBunker_Large_F",
    "Land_BagFence_Round_F", "Land_BagFence_Short_F", "Land_BagFence_Long_F",
    "Land_BagFence_Corner_F", "Land_BagFence_End_F",
    "Land_SandbagBarricade_01_hole_F", "Land_Razorwire_F",
    "Land_BagBunker_Tower_F"
];

// Cover props via the shared placer -- tilted, frozen (bar the keep-simulated set), fragile decoratives
// hardened. Weapon rows are skipped here and stood up by the fnc_static_place pass below.
[_allObjectsData, [_centerSpawnX, _centerSpawnY], _zoneKey, [0, _tiltTypes, ["Land_CampingChair_V1_F","Land_Camping_Light_F","Land_TentDome_F","Land_WaterTank_F","Land_Pallets_stack_F","Land_PaperBox_closed_F","Land_Ammobox_rounds_F","Land_WoodenBox_F","Land_CratesShabby_F","Land_FMradio_F","Land_TinContainer_F","Land_CanisterPlastic_F","Land_Axe_F","Land_Bucket_F","Land_Matches_F","Land_ButaneCanister_F","Land_GasCanister_F","Land_Canteen_F","Land_DuctTape_F","Land_PainKillers_F","Land_Bandage_F","Land_Sacks_heap_F","Land_WoodPile_F","Land_MetalWire_F","Land_Gloves_F","Land_BakedBeans_F"], _keepSimulation]] call fnc_composition_place;

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

// Fallback camp light at the centre, only if the composition left none nearby.
_lightDefault = nearestObject [_centerSpawn, "Land_Camping_Light_F"];
if (isNull _lightDefault) then {
    private _light1 = createVehicle ["Land_Camping_Light_F", [_centerSpawnX, _centerSpawnY, 0], [], 0, "NONE"];
    [_light1, _zoneKey] call fnc_duws_keep;
    _light1 setPosATL [_centerSpawnX, _centerSpawnY, 0];
    _light1 allowdamage false;
    _light1 setdamage 0;
};