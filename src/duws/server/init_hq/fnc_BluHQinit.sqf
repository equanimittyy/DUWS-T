// Locality: server -- spawned from server/server_init.sqf:102, which spells it fnc_bluHQinit;
// SQF names are case-insensitive.
#include "..\..\shared\includes\action_style.hpp"

// The officer is invulnerable (allowDamage false) until OPFOR come within this of him -- wider than
// the 200 m the contact alert calls the base, so a marksman on a ridge stays a loss worth keeping,
// and drawn on no map. Enemy presence in the ring, not the source of a shot, is what makes him mortal;
// while mortal, a HandleDamage veto still drops identifiable friendly fire so it cannot end the
// campaign.
#define OFFICER_GUARD_RADIUS 500

if (isNil "PosOfBLUHQ") exitWith {};

private _hqInCompX = 10.0413;
private _hqInCompY = 11.3066;
private _compCenterX = 1041.4962;
private _compCenterY = 6115.1133;

private _offsetX = _compCenterX - _hqInCompX;
private _offsetY = _compCenterY - _hqInCompY;

private _spawnBaseX = (PosOfBLUHQ select 0) + _offsetX;
private _spawnBaseY = (PosOfBLUHQ select 1) + _offsetY;
private _newCenterZ = getTerrainHeightASL [_spawnBaseX, _spawnBaseY];
if (_newCenterZ <= 0) then { _newCenterZ = 0; };

private _hqObj = objNull;
private _supplyCrate = objNull;
private _mapBoard = objNull;
private _medTent = objNull;
private _guardBoxObj = objNull;
private _barGateObj = objNull;
private _repairDepot = objNull;
private _helipad = objNull;
private _allTowersList = [];

// Format: [class, world X, world Y, world Z ASL, dir deg, isWeapon]
// --DUWS-COMPOSITION BEGIN name="HQ Main Base" schema=A anchor=hqInComp--
private _allObjectsData = [
    ["Land_TimberPile_05_F", 11.47421, 19.76128, 0.595282, 75.9751, false],
    ["Land_Cargo_HQ_V1_F", 10.0413, 11.3066, 3.87609, 165.875, false],
    ["Land_PortableLight_double_F", 6.49291, -19.1948, 1.057, 214.375, false],
    ["Land_PortableLight_double_F", -1.1664, 16.88726, 1.08975, 258.484, false],
    ["Land_PortableLight_double_F", 33.754, -6.1701, 1.08523, 167.475, false],
    ["Land_PortableLight_double_F", 33.6973, -20.2924, 1.07915, 121.275, false],
    ["TargetP_Zom_F", 40.1207, 7.67251, 0.881256, 76.0751, false],
    ["TargetP_Zom_F", 40.4091, 6.45274, 0.881256, 76.0751, false],
    ["TargetP_Zom_F", 40.6674, 5.3873, 0.881256, 76.0751, false],
    ["TargetP_Zom_F", 39.8571, 8.7538, 0.881256, 76.0751, false],
    ["Land_HelipadSquare_F", 12.5887, -10.1014, -0.0168171, 256.075, false],
    ["Land_PortableLight_double_F", 36.2363, 23.4904, 1.107, 2.57507, false],
    ["Land_MedicalTent_01_NATO_generic_inner_F", 39.737, -9.6138, 1.38285, 166.275, false],
    ["Land_Sleeping_bag_F", 41.1145, -5.3468, 0.0404491, 77.8753, false],
    ["Land_Sleeping_bag_brown_F", 43.1083, -12.6526, 0.0329342, 81.2751, false],
    ["Land_Sleeping_bag_blue_F", 41.5577, -6.9902, 0.0384483, 71.4753, false],
    ["Land_Sleeping_bag_F", 41.9901, -8.591, 0.0373268, 78.7751, false],
    ["Land_Sleeping_bag_blue_F", 42.3839, -10.1021, 0.0362072, 71.4752, false],
    ["MapBoard_altis_F", 30.1609, 9.96962, 0.982065, 10.9751, false],
    ["Land_RepairDepot_01_green_F", 12.94407, 1.42687, 2.41118, 256.075, false],
    ["Land_ClothesLine_01_F", 18.69283, -25.1009, 1.23125, 346.875, false],
    ["Land_ParkingMeter_01_F", 9.113384, -24.1112, 0.459938, 46.2751, false],
    ["RoadBarrier_F", 8.11852, -22.4627, 0.529808, 256.075, false],
    ["Land_dirt_road_damage_long_02_F", 15.29007, -20.6055, -0.0241928, 256.075, false],
    ["Land_WoodenBox_02_F", 9.410007, -1.5098, 0.476482, 346.075, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 27.5942, -24.138, 0.785501, 346.075, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 21.7958, -25.5952, 0.777208, 346.075, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 10.205074, -28.4865, 0.770662, 346.075, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 6.67176, -26.1756, 0.770651, 76.0751, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 5.22842, -20.3912, 0.775724, 76.0751, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 3.77573, -14.5858, 0.775928, 76.0751, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 2.3733, -8.8688, 0.783493, 76.0751, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 0.935879999999999, -3.0313, 0.785723, 76.0751, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", -0.489600000000001, 2.74379, 0.792898, 76.0751, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", -1.9382, 8.56297, 0.795723, 76.0751, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 33.4135, -22.7093, 0.793774, 346.075, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 39.2424, -21.2737, 0.799475, 346.075, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 45.0573, -19.8669, 0.796333, 346.075, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 47.3774, -16.3057, 0.802462, 256.075, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 45.9141, -10.4976, 0.810328, 256.075, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 43.0389, 1.1264, 0.825724, 256.075, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 41.5617, 6.93462, 0.825724, 256.075, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 40.1282, 12.75794, 0.825724, 256.075, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 38.6685, 18.55386, 0.825724, 256.075, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 37.2252, 24.3622, 0.825724, 256.075, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 33.6599, 26.6974, 0.825724, 166.075, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 16.309, 22.4576, 0.817297, 166.075, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", 10.514518, 21.01012, 0.815723, 166.075, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", -1.1127, 18.10729, 0.81123, 166.075, false],
    ["Land_CamoConcreteWall_01_pole_v1_F", 30.6458, 25.9673, 0.748152, 346.075, false],
    ["Land_CamoConcreteWall_01_pole_v1_F", -4.1169, 17.33939, 0.737411, 346.075, false],
    ["Land_CamoConcreteWall_01_l_4m_d_v2_F", -3.0222, 14.49482, 0.780607, 76.0751, false],
    ["Land_CamoConcreteWall_01_l_4m_d_v2_F", 44.1017, -4.756, 0.796289, 256.075, false],
    ["Land_CamoConcreteWall_01_l_4m_d_v1_F", 15.92204, -26.6372, 0.750999, 346.075, false],
    ["Land_CamoConcreteWall_01_l_4m_d_v1_F", 4.82164, 19.14093, 0.788137, 166.075, false],
    ["Land_GuardTower_02_F", 34.4535, 24.0735, 3.44459, 31.0751, false],
    ["Land_GuardTower_02_F", -0.6534, 15.37403, 3.42285, 301.075, false],
    ["Land_GuardTower_02_F", 9.411693, -25.8396, 3.39288, 211.075, false],
    ["Land_GuardTower_02_F", 44.7722, -17.1174, 3.42253, 121.075, false],
    ["CamoNet_BLUFOR_open_F", 32.1902, 4.96532, 1.18102, 346.075, false],
    ["Land_GuardBox_01_brown_F", 19.57593, 25.8494, 0.888489, 166.075, false],
    ["Land_CzechHedgehog_01_old_F", 17.25506, 29.2232, 0.721874, 346.075, false],
    ["Land_CzechHedgehog_01_old_F", 14.12179, 25.0153, 0.715223, 211.075, false],
    ["Land_CzechHedgehog_01_old_F", 30.9747, 32.7124, 0.721872, 301.075, false],
    ["Land_CzechHedgehog_01_old_F", 33.6794, 33.458, 0.721872, 256.075, false],
    ["Land_SandbagBarricade_01_half_F", 30.9767, 30.9314, 0.692169, 345.575, false],
    ["Land_SandbagBarricade_01_half_F", 18.84211, 28.2144, 0.692169, 345.575, false],
    ["Land_SandbagBarricade_01_half_F", 16.8831, 27.7156, 0.692169, 345.575, false],
    ["Land_SandbagBarricade_01_half_F", 16.31234, 24.6207, 0.687159, 255.775, false],
    ["Land_SandbagBarricade_01_F", 15.88874, 26.6352, 1.30664, 255.875, false],
    ["Land_SandbagBarricade_01_half_F", 16.51917, 23.8557, 0.686167, 255.875, false],
    ["Land_SandbagBarricade_01_hole_F", 32.77, 31.316, 1.31141, 345.375, false],
    ["Land_SandbagBarricade_01_F", 34.5608, 31.6642, 1.30891, 347.075, false],
    ["Land_SandbagBarricade_01_F", 35.6205, 31.1583, 1.30891, 77.0751, false],
    ["Land_SandbagBarricade_01_F", 36.9243, 27.9941, 1.30891, 76.3751, false],
    ["Land_SandbagBarricade_01_hole_F", 36.2596, 29.5755, 1.31141, 53.8751, false],
    ["Land_SandbagBarricade_01_half_F", 34.3436, 12.34787, 0.686457, 345.575, false],
    ["Land_SandbagBarricade_01_F", 32.535, 11.80649, 1.30047, 166.075, false],
    ["Land_SandbagBarricade_01_F", 29.0571, 10.966094, 1.29891, 166.075, false],
    ["Land_SandbagBarricade_01_hole_F", 30.7999, 11.545669, 1.30141, 345.375, false],
    ["Land_SandbagBarricade_01_half_F", 27.1423, 10.652983, 0.682169, 345.575, false],
    ["Land_SandbagBarricade_01_half_F", 35.6999, 13.33288, 0.689411, 76.0751, false],
    ["Land_SandbagBarricade_01_half_F", 35.0279, 15.01155, 0.691362, 254.175, false],
    ["Land_SandbagBarricade_01_F", 35.5168, 16.30207, 1.30891, 345.575, false],
    ["Land_BagFence_End_F", 37.2348, 26.7301, 0.432846, 346.075, false],
    ["Land_TTowerSmall_1_F", 27.8059, -0.954800000000001, 4.98351, 161.775, false],
    ["Land_Loudspeakers_F", 8.25946, 0.3407, 3.49475, 346.075, false],
    ["Land_BagFence_Short_F", 44.6967, -6.8756, 0.429829, 76.0751, false],
    ["Land_BagFence_Short_F", 44.3391, -5.2124, 0.432096, 256.075, false],
    ["Land_BagFence_Round_F", 17.04625, 3.56396, 0.415043, 241.375, false],
    ["Land_BagFence_End_F", 15.85629, 4.53854, 0.405699, 5.77509, false],
    ["Land_GarbageBarrel_02_F", 17.13978, 1.48183, 0.594526, 204.575, false],
    ["Land_CzechHedgehog_01_old_F", 2.83962, 20.0776, 0.710775, 116.975, false],
    ["Oil_Spill_F", 31.0784, -21.4511, -0.00919914, 255.975, false],
    ["Land_Tank_rust_F", 28.0179, -22.4232, 1.34365, 165.975, false],
    ["Land_CampingChair_V2_F", 26.377, 6.67981, 0.516781, 223.975, false],
    ["Land_TablePlastic_01_F", 28.1604, 7.26084, 0.456594, 195.175, false],
    ["Land_CampingChair_V2_F", 26.9629, 6.15923, 0.516567, 206.375, false],
    ["Land_CampingChair_V2_F", 27.7407, 5.9109, 0.516977, 195.675, false],
    ["Land_CampingChair_V2_F", 28.8266, 5.78745, 0.517908, 191.475, false],
    ["Land_CampingChair_V2_F", 26.7364, 7.92646, 0.519119, 296.675, false],
    ["Land_Portable_generator_F", 17.9526, 1.84223, 0.353132, 302.775, false],
    ["WaterPump_01_forest_F", 38.7457, 11.663749, 1.09222, 330.275, false],
    ["Land_ShootingPos_Roof_01_F", 5.83547, -2.9029, 1.00015, 165.875, false],
    ["Land_Pallet_vertical_F", 8.18671, -2.53, 0.722336, 74.6752, false],
    ["Land_PalletTrolley_01_khaki_F", 5.07381, -3.7015, 0.530968, 256.475, false],
    ["Land_GarbageBarrel_02_F", 30.2847, -20.1657, 0.593351, 215.175, false],
    ["Land_GarbageBarrel_02_F", 31.0533, -19.9143, 0.594543, 3.47507, false],
    ["Land_GarbageBarrel_02_buried_F", 30.9098, 26.7942, 0.406921, 317.275, false],
    ["ModuleEffectsFire_F", 30.8903, 26.8639, 0.0231838, 346.075, false],
    ["Land_GarbageBarrel_02_buried_F", 40.9711, 4.03607, 0.406921, 317.275, false],
    ["ModuleEffectsFire_F", 40.9512, 4.10774, 0.0231838, 346.075, false],
    ["Land_WoodenCrate_01_F", 9.907725, -2.705, 0.336653, 346.075, false],
    ["Land_WoodenCrate_01_stack_x3_F", 15.71863, 21.18984, 0.721056, 346.075, false],
    ["Land_WoodenCrate_01_F", 17.28733, 21.5078, 0.362463, 166.075, false],
    ["Land_WoodenCrate_01_stack_x5_F", 7.1473, -2.5296, 0.947853, 346.075, false],
    ["Land_LampShabby_F", 19.12027, 23.1654, 3.79081, 346.075, false],
    ["Land_LampShabby_F", -0.251300000000001, 2.74443, 3.76233, 256.075, false],
    ["Land_LampShabby_F", 18.96417, -26.2963, 3.74521, 166.075, false],
    ["Land_LampShabby_F", 43.7006, -1.6835, 3.79462, 76.0751, false],
    ["Land_LampShabby_F", 37.8922, 21.5025, 3.79521, 76.0751, false],
    ["Land_LampShabby_F", 39.2588, -21.2613, 3.76895, 166.075, false],
    ["Land_LampShabby_F", 1.74789, 18.64984, 3.78255, 346.075, false],
    ["Land_Bench_F", 15.75287, 9.09223, 0.249794, 346.075, false],
    ["Land_Pallet_F", 3.27926, -3.2974, 0.084219, 166.075, false],
    ["Box_Syndicate_Ammo_F", 4.99193, -3.5859, 0.193226, 346.075, false],
    ["Box_IED_Exp_F", 2.98574, -3.6417, 0.193712, 346.075, false],
    ["Box_Syndicate_WpsLaunch_F", 3.52433, -3.2864, 0.163168, 255.575, false],
    ["Land_Ammobox_rounds_F", 3.85288, -3.1443, 0.0885448, 346.809, false],
    ["Land_Ammobox_rounds_F", 3.93312, -3.4488, 0.0885448, 166.809, false],
    ["Land_FireExtinguisher_F", 25.6747, 10.26125, 0.39834, 303.475, false],
    ["Land_FireExtinguisher_F", 16.01377, 7.65429, 0.386269, 303.475, false],
    ["Land_WaterBottle_01_pack_F", 27.3972, 7.22295, 0.142988, 249.175, false],
    ["Land_BarGate_F", 25.4348, 26.6798, 4.07346, 345.275, false],
    ["B_supplyCrate_F", 29.4458, -1.4788, 0.893028, 12.9751, false]
];
// --DUWS-COMPOSITION END--

// The base's guns, in the same frame as the walls around them but on their own fence, not merged into
// the composition above, because the two halves have different lifetimes: props are built once, guns
// are replaced on every redeploy (init_hq/fnc_redeployHQUnits.sqf replays these rows alone through
// fnc_placeHQUnits). The Eden export emits nothing past the heading column, so a permanent/rebuilt
// flag on one merged array would survive only by being hand-carried back across 135 prop rows every
// round trip. Do not merge them: the zone prefabs' single-fence-plus-isWeapon shape works there only
// because a prefab is built once and never rebuilt. (The guns were originally placed off model-space
// offsets, which is why the composition above holds 135 props and no weapon -- importing it showed a
// firing position with no gun.)
//
// Height is the one thing that cannot be a row: a row's Z is discarded (the placement loop below
// snaps every prop to the terrain), and these two sit above it by a measured amount taken against an
// anchor's getPosWorld, because a building's own modelToWorld Z is unusable
// (init_hq/fnc_placeHQUnits.sqf). So the last two columns name the anchor class and the offset,
// resolved by whatever object of that class is nearest the row -- move the gun in Eden and its height
// follows the thing it stands on.
//
// Column 5 is the faction role holding the classname, or "" for a gun resolved by its class. The
// column 0 class is what the role resolves to on the stock faction, so the import draws the right
// silhouette whether or not a mod is loaded.
// --DUWS-COMPOSITION BEGIN name="HQ Turrets" schema=A anchor=hqInComp--
private _weaponData = [
    ["I_HMG_02_high_F", 31.26595, 28.56276, 0, 352.975, "",                  "Land_SandbagBarricade_01_hole_F", 1.21321],
    ["B_static_AA_F",   10.54204, 10.59272, 0, 165.875, "",                  "Land_Cargo_HQ_V1_F",              1.252556]
];
// --DUWS-COMPOSITION END--

private _lightTypes = ["Land_PortableLight_double_F", "Land_LampShabby_F"];

private _invulnerableTypes = [
    "Land_PortableLight_double_F",
    "Land_MedicalTent_01_NATO_generic_inner_F",
    "B_supplyCrate_F",
    "Land_GuardTower_02_F",
    "Land_LampShabby_F",
    "Land_GuardBox_01_brown_F",
    "Land_BarGate_F",
    "Land_Tank_rust_F",
    "Land_ClothesLine_01_F",
    "Land_ShootingPos_Roof_01_F",
    "Land_RepairDepot_01_green_F",
    "RoadBarrier_F",
    "Land_ParkingMeter_01_F",
    "Land_Portable_generator_F",
    "Land_GarbageBarrel_02_F",
    "Land_Cargo_HQ_V1_F",
    "Land_FireExtinguisher_F",
    "TargetP_Zom_F",
    "WaterPump_01_forest_F",
    "Land_HelipadSquare_F",
    "Land_WoodenBox_02_F",
    "Land_WoodenCrate_01_stack_x5_F",
    "Land_WoodenCrate_01_F",
    "Land_WoodenCrate_01_stack_x3_F",
    "Land_Pallet_vertical_F",
    "Land_PalletTrolley_01_khaki_F",
    "Land_Pallet_F"
];

// Cleared before the props go down rather than at placement time: this is the first point the final
// HQ position is known, and the one path both random and manual placement pass through. 50 m is the
// composition's own reach -- its farthest wall stands 47 m from the HQ building every offset above is
// measured against.
[PosOfBLUHQ, 50] call fnc_clear_foliage;

{
    _x params ["_class","_origX","_origY","_origZ","_dir","_isWeapon"];
    if (_isWeapon) then { continue; };
    
    private _newX = _spawnBaseX + (_origX - _compCenterX);
    private _newY = _spawnBaseY + (_origY - _compCenterY);
    private _obj = createVehicle [_class, [_newX, _newY, 0], [], 0, "CAN_COLLIDE"];
    [_obj, "HQ"] call fnc_duws_keep;
    _obj setPosATL [_newX, _newY, 0];
    _obj setDir _dir;
    
    // Global, not the local form: enableSimulation only affects the machine it runs on, so a
    // server-side call leaves every client still simulating props the server has frozen. They then
    // settle, drift and fall differently on each machine, which is how the base ends up looking
    // different to a joining player than it does to the host.
    if (_class in _lightTypes || _class == "B_supplyCrate_F") then {
        _obj enableSimulationGlobal true;
    } else {
        _obj enableSimulationGlobal false;
    };

    if (_class == "CamoNet_BLUFOR_open_F" || (toLower _class) find "land_camo" == 0) then {
        _obj allowDamage false;
    };

    if (_class in _invulnerableTypes) then {
        _obj allowDamage false;
    };
    
    if (_class == "Land_Cargo_HQ_V1_F") then { _hqObj = _obj; };
    if (_class == "B_supplyCrate_F") then { _supplyCrate = _obj; };
    if (_class == "MapBoard_altis_F") then { _mapBoard = _obj; };
    if (_class == "Land_MedicalTent_01_NATO_generic_inner_F") then { _medTent = _obj; };
    if (_class == "Land_GuardTower_02_F") then { _allTowersList pushBack _obj; };
    if (_class == "Land_GuardBox_01_brown_F") then { _guardBoxObj = _obj; };
    if (_class == "Land_BarGate_F") then { _barGateObj = _obj; };
    if (_class == "Land_RepairDepot_01_green_F") then { _repairDepot = _obj; };
    if (_class == "Land_HelipadSquare_F") then { _helipad = _obj; };
} forEach _allObjectsData;

bluHQ_object = _hqObj;
publicVariable "bluHQ_object";

// Every anchor fnc_placeHQUnits reads lives in these keys. They are written before the placement
// call rather than beside each spawn so the rebuild -- which has nothing but the namespace to work
// from -- places its units off exactly the data this build used.

// The guns, resolved out of their fence into the world positions the rebuild works from. Anchors
// travel as a class and a position rather than as an object reference: an anchor destroyed between
// build and rebuild would leave a null behind, where the class is re-found against whatever is
// standing there now.
// Resolved here rather than by fnc_static_place: this fence's product is data, not objects. The
// rebuild runs it again against whatever is standing on the anchors now, so the class is decided
// once per build and carried, and an unroled row is decided by its class through the same table
// every zone prefab uses.
missionNamespace setVariable ["HQ_redeploy_weaponData", _weaponData apply {
    _x params ["_class", "_origX", "_origY", "", "_dir", "_role", "_anchorClass", "_hOffset"];
    [
        [_class, "blufor", _role] call fnc_static_resolve,
        [_spawnBaseX + (_origX - _compCenterX), _spawnBaseY + (_origY - _compCenterY)],
        _dir, _anchorClass, _hOffset
    ]
}, true];

// Unit-type pool. Broadcast because client_init reads it to caption the guards, and because a FOB's own
// patrol draws from it too (init_hq/fnc_guardsFOB.sqf) -- the HQ_ prefix is where it is set, not
// who may read it.
private _baseGuardTypes = [blufor_SOLDIER_X, blufor_LAT_SOLDIER_X, blufor_GL_SOLDIER_X, blufor_TL_SOLDIER_X, blufor_SL_SOLDIER_X, blufor_AR_SOLDIER_X, blufor_MARK_SOLDIER_X];
missionNamespace setVariable ["HQ_redeploy_guardTypes", _baseGuardTypes, true];

missionNamespace setVariable ["HQ_redeploy_towers", _allTowersList, true];

// Door pair: model XY, height offset, facing offset from the HQ building heading, anim.
// The facing is relative to the building, not absolute: re-exporting the composition rotates the
// whole frame, and an absolute facing stays behind and ends up turning the pair inward.
missionNamespace setVariable ["HQ_redeploy_hqGuardsData", [
    [[-5.49573, -0.923828], -4.10893, -90, "STAND"],
    [[-4.84598, -3.90649], -4.03631, -90, "STAND_IA"]
], true];
missionNamespace setVariable ["HQ_redeploy_medGuardsData", [
    [[1.49021, -5.54492], -1.37312, "STAND_IA"],
    [[3.18945, -5.54492], -1.37312, "STAND"]
], true];

if (!isNull _medTent) then { missionNamespace setVariable ["HQ_medTent_netId", netId _medTent, true]; };
if (!isNull _guardBoxObj) then { missionNamespace setVariable ["HQ_guardBox_netId", netId _guardBoxObj, true]; };

private _patrolSpawnXY = _hqObj modelToWorld [1.27142, -21.9805, 0];
missionNamespace setVariable ["HQ_redeploy_patrolSpawnPos", [
    _patrolSpawnXY select 0,
    _patrolSpawnXY select 1,
    (getPosWorld _hqObj select 2) + (-3.87396)
], true];

call fnc_placeHQUnits;

private _xyWorld = _hqObj modelToWorld [0.0896273, -0.0180664, 0];
private _worldPos = [
    _xyWorld select 0,
    _xyWorld select 1,
    (getPosWorld _hqObj select 2) + (-3.27229)
];
private _offGrp = [_worldPos, WEST, [blufor_OFFICER_X], [], [], [0.4,0.6]] call BIS_fnc_spawnGroup;
private _officer = (units _offGrp) select 0;
_officer allowDamage false;  // the proximity monitor below flips this true only while OPFOR hold the ring
// Global: the local form freezes the officer on the server alone, so every client keeps
// simulating a unit hard-placed at an absolute Z and renders it falling.
_officer enableSimulationGlobal false;
_officer setPosWorld _worldPos;
_officer setDir ((getDir _hqObj) - 90);  // outward, relative to the building so a re-exported frame carries it
_officer setBehaviour "CARELESS";
_officer setCombatMode "BLUE";
_officer disableAI "TARGET"; _officer disableAI "AUTOTARGET";
_officer disableAI "FSM"; _officer disableAI "MOVE";
_officer setVariable ["asr_ai_exclude", true];
_officer setVariable ["NOAI", 1, false];
_officer setVariable ["Vcm_Disable", true];
_officer setVariable ["lambs_danger_disableAI", true];
removeBackpackGlobal _officer;
// An "Acts_" ambient animation holds through death: the corpse keeps the standing pose and never
// ragdolls, so hits read as having no effect and the officer looks invulnerable. The tower guards
// escape this because BIS_fnc_ambientAnimCombat breaks its own animation; a raw switchMove has
// nothing that does. Clearing the move lets the death animation play.
_officer addEventHandler ["Killed", {
    params ["_unit"];
    [_unit, ""] remoteExec ["switchMove", 0];
    // The queued pose goes with it. Left in the queue, a player joining after the officer dies is
    // handed the standing animation for a corpse -- the state clearing the move exists to prevent,
    // arriving by the other route.
    remoteExec ["", format ["hq_pose_%1", netId _unit]];
}];
// Loss condition: friendly fire must never end the campaign. The proximity gate below (allowDamage)
// blocks all damage while OPFOR are outside OFFICER_GUARD_RADIUS, so this only fires once they breach
// it -- there it drops any hit an identifiable WEST shooter dealt (_instigator the player behind an
// explosive or vehicle, _source a direct hit). Unattributed blasts still land, as the ring intends.
_officer addEventHandler ["HandleDamage", {
    params ["_unit", "", "_damage", "_source", "", "", "_instigator"];
    private _by = [_source, _instigator] select (!isNull _instigator);
    if (!isNull _by && {side _by == WEST}) exitWith { 0 };
    _damage
}];
hq_blu1 = _officer; publicVariable "hq_blu1";
[_officer] spawn {
    // Polled, not hung off the Killed handler above: that runs wherever the officer is local, and
    // campaign_lost_ending is deliberately not broadcast, so a client-side firing would leave the
    // server without the ending it names. The same poll gates his mortality via allowDamage -- the
    // reliable primitive that stops bullets, blasts and setDamage alike while the ring is clear,
    // which a per-hit HandleDamage veto could not. Killable only while OPFOR hold the ring.
    while { alive hq_blu1 } do {
        hq_blu1 allowDamage (([getPos hq_blu1, OFFICER_GUARD_RADIUS, EAST] call fnc_side_count_at) > 0);
        sleep 1;
    };
    campaign_lost = true;
    campaign_lost_body = "STR_DUWS_T_CAMPAIGN_LOST_OFFICER";
    // Names the outro card as well as the hint: both endings are worded, and the debriefing
    // class is read on the server only, so it needs no broadcast.
    campaign_lost_ending = "officerkilled";
    publicVariable "campaign_lost";
    publicVariable "campaign_lost_body";
    ["INFO", "WARCOM", "Commanding officer killed: campaign lost"] call fnc_log;
};
[_officer] spawn {
    params ["_u"];
    sleep 0.5;
    if (isNull _u || {!alive _u}) exitWith {};
    _u enableSimulationGlobal true;
    // switchMove is local, so posing from the server dressed the officer on the host and nowhere
    // else. Applied after simulation is back -- a frozen unit does not take the animation -- and
    // keyed so a joiner is posed too rather than meeting a man standing to attention.
    [_u, "acts_StandingSpeakingUnarmed"] remoteExec ["switchMove", 0, format ["hq_pose_%1", netId _u]];
};

private _barrierPosX = _spawnBaseX + (-22.2731 - _compCenterX);
private _barrierPosY = _spawnBaseY + (21.2998 - _compCenterY);
private _barrier = nearestObject [[_barrierPosX, _barrierPosY, 0] apply { _x + 0 }, "RoadBarrier_F"];
if (!isNull _barrier) then {
    private _xyWorld = _barrier modelToWorld [2.41602, 0.460938, 0];
    private _worldPos = [
        _xyWorld select 0,
        _xyWorld select 1,
        (getPosWorld _barrier select 2) + (-0.490046)
    ];
    private _grp = [_worldPos, WEST, [blufor_HELI_PILOT_X], [], [], [0.4,0.6]] call BIS_fnc_spawnGroup;
    private _unit = (units _grp) select 0;
    private _dirToTent = [_worldPos, getPosWorld _medTent] call BIS_fnc_dirTo;
    _unit allowDamage true;
    _unit enableSimulationGlobal false;
    _unit setPosWorld _worldPos;
    _unit setUnitPos "UP";
    _unit disableAI "MOVE";
    _unit setDir _dirToTent;
    removeAllWeapons _unit;
    removeGoggles _unit;
    _unit unassignItem "NVGoggles";
    _unit removeItem "NVGoggles";
    _unit unassignItem "NVGoggles_OPFOR";
    _unit removeItem "NVGoggles_OPFOR";
    _unit unassignItem "NVGoggles_INDEP";
    _unit removeItem "NVGoggles_INDEP";
    // He keeps the helmet his own class spawns in rather than being dressed as ground crew: the
    // construction hard hat is DLC content, so a player who does not own it met the base wearing a
    // purchase prompt.
    [_unit] spawn {
        params ["_u"];
        sleep 0.5;
        if (isNull _u || {!alive _u}) exitWith {};
        _u enableSimulationGlobal true;
        // Broadcast and keyed, same as the officer: a local switchMove posed him for the host
        // alone, and it has to wait for simulation to come back before it takes.
        [_u, "Acts_PointingLeftUnarmed"] remoteExec ["switchMove", 0, format ["hq_pose_%1", netId _u]];
    };
    // Clears the pose on death; the Acts_ animation otherwise holds and the corpse stands.
    // The queued pose is dropped with it, or a joiner re-poses the corpse.
    _unit addEventHandler ["Killed", {
        params ["_u"];
        [_u, ""] remoteExec ["switchMove", 0];
        remoteExec ["", format ["hq_pose_%1", netId _u]];
    }];
};

if (!isNull _supplyCrate) then {
    clearMagazineCargoGlobal _supplyCrate;
    clearWeaponCargoGlobal _supplyCrate;
    clearItemCargoGlobal _supplyCrate;
    clearBackpackCargoGlobal _supplyCrate;
    _supplyCrate addMagazineCargoGlobal ["Money_roll", 20];
    // Suffixed JIP ids throughout this block: an object-keyed id is that object's netId, so a
    // second broadcast against the same object would silently evict the first. Each prop takes
    // one adder today, and the suffix is what keeps that true if one ever takes two.
    [_supplyCrate] remoteExec ["fnc_addQuickChangeActions", 0, format ["hq_quickchange_%1", netId _supplyCrate]];
};

if (!isNull _medTent) then {
    // Broadcast to everyone rather than to interfaced machines alone, and keyed, because the
    // adder now decides per player which of its three entries apply -- a joiner has to run it for
    // themselves rather than inherit the host's answer.
    [_medTent] remoteExec ["fnc_medtent_actions", 0, format ["hq_medtent_%1", netId _medTent]];
};

if (!isNull _mapBoard) then {
    missionNamespace setVariable ["HQ_mapBoard_netId", netId _mapBoard, true];
    [_mapBoard] remoteExec ["fnc_addBoardKillhouseActions", 0, format ["hq_mapboard_%1", netId _mapBoard]];
};

if (!isNull _hqObj) then {
    [_hqObj] remoteExec ["fnc_addHQBuildingActions", 0, format ["hq_building_%1", netId _hqObj]];
};

// Gate auto-trigger: object passed by netId, since the trigger statement is a string
if (!isNull _barGateObj && {isNil {_barGateObj getVariable "gate_trigger_added"}}) then {
    _barGateObj setVariable ["gate_trigger_added", true, true];
    private _gateNetId = netId _barGateObj;
    _trgGate = createTrigger ["EmptyDetector", getPosWorld _barGateObj, false];
    _trgGate setTriggerArea [12, 12, 0, false, 12];
    _trgGate setTriggerActivation ["ANYPLAYER", "PRESENT", true];
    _trgGate setTriggerStatements [
        "this",
        format [
            "private _g = objectFromNetId '%1'; if (!isNull _g && {alive _g}) then { _g animate ['door_1_rot', 1]; [_g] spawn { params ['_gt']; sleep 15; if (!isNull _gt && {alive _gt}) then { _gt animate ['door_1_rot', 0]; }; }; };",
            _gateNetId
        ],
        ""
    ];
};

_markername = format["%1%2",round (PosOfBLUHQ select 0),round (PosOfBLUHQ select 1)];
blu_hq_markername = _markername; publicVariable "blu_hq_markername";
createMarker [str(_markername), PosOfBLUHQ];
str(_markername) setMarkerShape "ICON";
str(_markername) setMarkerType "mil_flag";
str(_markername) setMarkerColor "ColorBlue";
str(_markername) setMarkerText "Main Base";

// Server-local, matching the zone's contact trigger: a global trigger runs its statement on every
// machine, which would raise the alert and drop its markers once per player.
_trgWarning = createTrigger["EmptyDetector",PosOfBLUHQ,false];
_trgWarning setTriggerArea[200,200,0,false];
_trgWarning setTriggerActivation["EAST","PRESENT",true];
_trgWarning setTriggerStatements["this", "['Main Base', thisList] call fnc_enemy_contact;", ""];
_trgWarning setTriggerTimeout [10, 10, 10, true];

private _respawnXY = _medTent modelToWorld [-0.243752, -7.28516, 0];
private _respawnPos = [
    _respawnXY select 0,
    _respawnXY select 1,
    (getPosWorld _medTent select 2) + (-2.02112)
];
"respawn_west" setMarkerPos _respawnPos;

if (!isNull _repairDepot) then { missionNamespace setVariable ["HQ_repairDepot_netId", netId _repairDepot, true]; };
if (!isNull _helipad) then { missionNamespace setVariable ["HQ_helipad_netId", netId _helipad, true]; };

// Hold the interaction-critical HQ fixtures out of Zeus, so a game master cannot delete the base's
// building, heal tent, map board or vehicle depot (fnc_asset_guard).
{ if (!isNull _x) then { [_x] call fnc_guard_register } } forEach [_hqObj, _medTent, _mapBoard, _repairDepot];

HQ_pos_found_generated = true; publicVariable "HQ_pos_found_generated";
["INFO", "BOOT", format ["BLUFOR HQ built at %1", PosOfBLUHQ]] call fnc_log;
// Drawn through the shared function so the HQ, every FOB and the MHQ all advertise the one radius
// the cleanup sweep honours -- a separate hardcoded figure drifts from it (200 m against a sweep
// that spares 250).
[PosOfBLUHQ] call fnc_baseRangeMarker;