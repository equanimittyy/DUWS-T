// Locality: server -- spawned from server/server_init.sqf:102, which spells it fnc_bluHQinit;
// SQF names are case-insensitive.
#include "..\..\shared\includes\action_style.hpp"

if (isNil "PosOfBLUHQ") exitWith {};

// 核心坐标定义
private _hqInCompX = 10.0413;
private _hqInCompY = 11.3066;
private _compCenterX = 1041.4962;
private _compCenterY = 6115.1133;

// 计算偏移
private _offsetX = _compCenterX - _hqInCompX;
private _offsetY = _compCenterY - _hqInCompY;

// 基准生成坐标
private _spawnBaseX = (PosOfBLUHQ select 0) + _offsetX;
private _spawnBaseY = (PosOfBLUHQ select 1) + _offsetY;
private _newCenterZ = getTerrainHeightASL [_spawnBaseX, _spawnBaseY];
if (_newCenterZ <= 0) then { _newCenterZ = 0; };

// 用于存储关键交互对象和建筑对象的变量
private _hqObj = objNull;
private _supplyCrate = objNull;
private _mapBoard = objNull;
private _medTent = objNull;
private _guardBoxObj = objNull;
private _barGateObj = objNull;
private _repairDepot = objNull;
private _helipad = objNull;
private _allTowersList = [];

// 格式: [类名, 世界X, 世界Y, 世界Z海拔, 方向度, 是否武器]
// --DUWS-COMPOSITION BEGIN name="HQ Main Base" schema=A anchor=hqInComp--
private _allObjectsData = [
    ["Land_TimberPile_05_F",                17.9016,   7.8813,  0.5821, 179.9, false],
    ["Land_Cargo_HQ_V1_F",                  10.0413,  11.3066,  3.8754, 269.8, false],
    ["Land_PortableLight_double_F",        -18.7095,  22.0903,  1.0838, 318.3, false],
    ["Land_PortableLight_double_F",         11.9955,  16.3091,  4.2103,  46.9, false],
    ["Land_PortableLight_double_F",        -12.6289,  -7.5039,  1.0838, 271.4, false],
    ["Land_PortableLight_double_F",        -26.3215,  -4.0498,  1.0838, 225.2, false],
    ["TargetP_Zom_F",                       -0.7255, -17.0151,  0.8581, 180.0, false],
    ["TargetP_Zom_F",                       -1.9780, -17.0010,  0.8581, 180.0, false],
    ["TargetP_Zom_F",                       -3.0748, -16.9956,  0.8581, 180.0, false],
    ["TargetP_Zom_F",                        0.3878, -17.0190,  0.8581, 180.0, false],
    ["Land_HelipadSquare_F",              -11.3513,  13.9858,  0.0,     0.0, false],
    ["Land_PortableLight_double_F",        15.5630, -17.0508,  1.0838, 106.5, false],
    ["Land_MedicalTent_01_NATO_generic_inner_F", -17.4105, -12.4819, 1.3746, 270.2, false],
    ["Land_Sleeping_bag_F",                -13.6006, -14.8462,  0.0258, 181.8, false],
    ["Land_Sleeping_bag_brown_F",          -21.1715, -15.0229,  0.0258, 185.2, false],
    ["Land_Sleeping_bag_blue_F",           -15.3020, -14.8813,  0.0258, 175.4, false],
    ["Land_Sleeping_bag_F",                -16.9602, -14.9150,  0.0258, 182.7, false],
    ["Land_Sleeping_bag_blue_F",           -18.5222, -14.9341,  0.0258, 175.4, false],
    ["MapBoard_altis_F",                     3.9012,  -7.9009,  0.9689, 114.9, false],
    ["Land_RepairDepot_01_green_F",         -0.2466,  10.8662,  2.4180,   0.0, false],
    ["Land_ClothesLine_01_F",              -27.3785,  11.6709,  1.2581,  90.8, false],
    ["Land_ParkingMeter_01_F",            -24.1132,  20.7305,  0.4868, 150.2, false],
    ["RoadBarrier_F",                      -22.2731,  21.2998,  0.5566,   0.0, false],
    ["Land_dirt_road_damage_long_02_F",    -22.1962,  13.8916,  0.0,     0.0, false],
    ["Land_WoodenBox_02_F",                 -2.2466,  15.0039,  0.4866,  90.0, false],
    // 围墙
    ["Land_CamoConcreteWall_01_l_4m_v1_F", -28.5852,   2.7983,  0.8025,  90.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", -28.6052,   8.7778,  0.8025,  90.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", -28.6213,  20.7236,  0.8025,  90.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", -25.5288,  23.5977,  0.8025, 180.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", -19.5671,  23.6064,  0.8025, 180.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", -13.5830,  23.6191,  0.8025, 180.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F",  -7.6960,  23.6045,  0.8025, 180.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F",  -1.6846,  23.5942,  0.8025, 180.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F",   4.2642,  23.5884,  0.8025, 180.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F",  10.2615,  23.5938,  0.8025, 180.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", -28.5996,  -3.1934,  0.8025,  90.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", -28.6089,  -9.1968,  0.8025,  90.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", -28.6431, -15.1787,  0.8025,  90.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", -25.7446, -18.2876,  0.8025,   0.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F", -19.7554, -18.2651,  0.8025,   0.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F",  -7.7813, -18.2715,  0.8025,   0.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F",  -1.7876, -18.2354,  0.8025,   0.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F",   4.2095, -18.2451,  0.8025,   0.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F",  10.1846, -18.2241,  0.8025,   0.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F",  16.1724, -18.2207,  0.8025,   0.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F",  19.2964, -15.3213,  0.8025, 270.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F",  19.3555,   2.5396,  0.8025, 270.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F",  19.3450,   8.5117,  0.8025, 270.0, false],
    ["Land_CamoConcreteWall_01_l_4m_v1_F",  19.3254,  20.4956,  0.8025, 270.0, false],
    ["Land_CamoConcreteWall_01_pole_v1_F",   19.3125, -12.2207,  0.7250,  90.0, false],
    ["Land_CamoConcreteWall_01_pole_v1_F",   19.3027,  23.5967,  0.7249,  90.0, false],
    ["Land_CamoConcreteWall_01_l_4m_d_v2_F",16.2803,  23.2188,  0.7778, 180.0, false],
    ["Land_CamoConcreteWall_01_l_4m_d_v2_F",-13.7461, -17.8882,  0.7778,   0.0, false],
    ["Land_CamoConcreteWall_01_l_4m_d_v1_F",-28.2026,  14.7295,  0.7778,  90.0, false],
    ["Land_CamoConcreteWall_01_l_4m_d_v1_F", 18.9004,  14.4873,  0.7778, 270.0, false],
    // 哨塔
    ["Land_GuardTower_02_F",                16.5581, -15.4609,  3.7125, 135.0, false],
    ["Land_GuardTower_02_F",                16.5635,  20.7080,  3.7129,  45.0, false],
    ["Land_GuardTower_02_F",               -25.8621,  20.8560,  3.7125, 315.0, false],
    ["Land_GuardTower_02_F",               -25.9058, -15.5635,  3.7129, 225.0, false],
    ["CamoNet_BLUFOR_open_F",                   -1.4436,  -8.6650,  1.1678,  90.0, false],
    ["Land_GuardBox_01_brown_F",            21.8607,  -1.4473,  1.4467, 270.0, false],
    ["Land_CzechHedgehog_01_old_F",         25.6975,  -0.0068,  0.6987,  90.0, false],
    ["Land_CzechHedgehog_01_old_F",         22.3645,   4.0454,  0.6987, 315.0, false],
    ["Land_CzechHedgehog_01_old_F",         25.7825, -14.1655,  0.6987,  45.0, false],
    ["Land_CzechHedgehog_01_old_F",         25.8510, -16.9697,  0.6987,   0.0, false],
    ["Land_SandbagBarricade_01_half_F",     24.0503, -13.7368,  0.6690,  89.5, false],
    ["Land_SandbagBarricade_01_half_F",     24.3351,  -1.3047,  0.6690,  89.5, false],
    ["Land_SandbagBarricade_01_half_F",     24.3204,   0.7163,  0.6690,  89.5, false],
    ["Land_SandbagBarricade_01_half_F",     21.4552,   2.0151,  0.6690, 359.7, false],
    ["Land_SandbagBarricade_01_F",          23.5133,   1.9419,  1.2857, 359.8, false],
    ["Land_SandbagBarricade_01_half_F",     20.6622,   1.9990,  0.6690, 359.8, false],
    ["Land_SandbagBarricade_01_hole_F",     23.9929, -15.5693,  1.2882,  89.3, false],
    ["Land_SandbagBarricade_01_F",          23.8999, -17.3921,  1.2857,  91.0, false],
    ["Land_SandbagBarricade_01_F",          23.1526, -18.2983,  1.2857, 181.0, false],
    ["Land_SandbagBarricade_01_F",          19.7681, -18.8022,  1.2857, 180.3, false],
    ["Land_SandbagBarricade_01_hole_F",     21.4634, -18.5371,  1.2882, 157.8, false],
    ["Land_SandbagBarricade_01_half_F",      5.2031, -12.5327,  0.6690,  89.5, false],
    ["Land_SandbagBarricade_01_F",           5.1138, -10.6465,  1.2857, 270.0, false],
    ["Land_SandbagBarricade_01_F",           5.1343,  -7.0684,  1.2857, 270.0, false],
    ["Land_SandbagBarricade_01_hole_F",      5.2773,  -8.8994,  1.2882,  89.3, false],
    ["Land_SandbagBarricade_01_half_F",      5.2915,  -5.1348,  0.6690,  89.5, false],
    ["Land_SandbagBarricade_01_half_F",      5.8337, -14.0859,  0.6690, 180.0, false],
    ["Land_SandbagBarricade_01_half_F",      7.6245, -13.8369,  0.6690, 358.1, false],
    ["Land_SandbagBarricade_01_F",           8.7593, -14.6221,  1.2857,  89.5, false],
    ["Land_BagFence_End_F",                 18.4661, -18.7998,  0.4097,  90.0, false],
    ["Land_TTowerSmall_1_F",                -6.1357,  -2.9858,  4.9838, 265.7, false],
    ["Land_Loudspeakers_F",                 -0.1735,  15.6743,  3.5032,  90.0, false],
    ["Land_BagFence_Short_F",             -15.9468, -17.9551,  0.4143, 180.0, false],
    ["Land_BagFence_Short_F",             -14.2454, -18.0083,  0.4143,   0.0, false],
    ["Land_BagFence_Round_F",               0.8402,   6.3711,  0.4193, 345.3, false],
    ["Land_BagFence_End_F",                 2.0730,   7.2905,  0.4097, 109.7, false],
    ["Land_GarbageBarrel_02_F",            -1.2023,   6.7798,  0.6013, 308.5, false],
    ["Land_CzechHedgehog_01_old_F",        20.2880,  16.1841,  0.6987, 220.9, false],
    ["Oil_Spill_F",                        -26.8159,  -1.2295,  0.0,   359.9, false],
    ["Land_Tank_rust_F",                   -27.0232,   1.9751,  1.3575, 269.9, false],
    ["Land_CampingChair_V2_F",              1.6199,  -3.4360,  0.5065, 327.9, false],
    ["Land_TablePlastic_01_F",              1.7538,  -5.3066,  0.4435, 299.1, false],
    ["Land_CampingChair_V2_F",              0.9731,  -3.8789,  0.5065, 310.3, false],
    ["Land_CampingChair_V2_F",              0.5442,  -4.5747,  0.5065, 299.6, false],
    ["Land_CampingChair_V2_F",              0.1638,  -5.5991,  0.5065, 295.4, false],
    ["Land_CampingChair_V2_F",              2.7423,  -4.0840,  0.5065,  40.6, false],
    ["Land_Portable_generator_F",          -1.0496,   5.9053,  0.3592,  46.7, false],
    ["WaterPump_01_forest_F",               3.4807, -16.6416,  1.0695,  74.2, false],
    ["Land_ShootingPos_Roof_01_F",         -2.7392,  18.8081,  1.0162, 269.8, false],
    ["Land_Pallet_vertical_F",             -2.9432,  16.4365,  0.7354, 178.6, false],
    ["Land_PalletTrolley_01_khaki_F",      -3.3298,  19.7393,  0.5478,   0.4, false],
    ["Land_GarbageBarrel_02_F",           -25.3772,  -0.7686,  0.6013, 319.1, false],
    ["Land_GarbageBarrel_02_F",           -25.3188,  -1.5742,  0.6013, 107.4, false],
    // 火焰区域1
    ["Land_GarbageBarrel_02_buried_F",     20.0510, -12.6758,  0.3837,  61.2, false],
    ["ModuleEffectsFire_F",                20.1252, -12.6743,  1.4145,  90.0, false],
    // 火焰区域2
    ["Land_GarbageBarrel_02_buried_F",     -4.4591, -16.9648,  0.3837,  61.2, false],
    ["ModuleEffectsFire_F",                -4.3849, -16.9634,  1.4145,  90.0, false],
    // 其余杂物
    ["Land_WoodenCrate_01_F",              -3.5266,  14.8086,  0.3482,  90.0, false],
    ["Land_WoodenCrate_01_stack_x3_F",     18.2676,   3.4175,  0.7079,  90.0, false],
    ["Land_WoodenCrate_01_F",              18.1987,   1.8188,  0.3482, 270.0, false],
    ["Land_WoodenCrate_01_stack_x5_F",     -2.6919,  17.4453,  0.9620,  90.0, false],
    ["Land_LampShabby_F",                  19.3660,  -0.3594,  3.7720,  90.0, false],
    ["Land_LampShabby_F",                   4.2074,  23.3569,  3.7720,   0.0, false],
    ["Land_LampShabby_F",                 -28.6045,  11.6953,  3.7720, 270.0, false],
    ["Land_LampShabby_F",                 -10.6672, -18.2373,  3.7720, 180.0, false],
    ["Land_LampShabby_F",                  13.2351, -18.1797,  3.7720, 180.0, false],
    ["Land_LampShabby_F",                 -28.6011,  -9.2144,  3.7720, 270.0, false],
    ["Land_LampShabby_F",                  19.1633,  17.5889,  3.7720,  90.0, false],
    ["Land_Bench_F",                        6.5167,   6.2954,  0.2467,  90.0, false],
    ["Land_Pallet_F",                      -2.5063,  21.3848,  0.1010, 270.0, false],
    ["Box_Syndicate_Ammo_F",              -3.1986,  19.7910,  0.2841,  90.0, false],
    ["Box_IED_Exp_F",                     -2.7705,  21.7520,  0.4146,  90.0, false],
    ["Box_Syndicate_WpsLaunch_F",         -2.5542,  21.1431,  0.3841, 359.5, false],
    ["Land_Ammobox_rounds_F",             -2.4954,  20.7905,  0.4460,  90.0, false],
    ["Land_Ammobox_rounds_F",             -2.8113,  20.7861,  0.5711, 270.0, false],
    ["Land_FireExtinguisher_F",             5.2646,  -3.6177,  0.3852,  47.4, false],
    ["Land_FireExtinguisher_F",             5.0587,   6.3882,  0.3852,  47.4, false],
    ["Land_WaterBottle_01_pack_F",          1.9010,  -4.5571,  1.0179, 353.1, false],
    ["Land_BarGate_F",                     21.2584,  -7.3345,  4.0503,  89.2, false],
    ["B_supplyCrate_F",                    -7.0382,  -4.4521,  1.1657, 116.9, false]
];
// --DUWS-COMPOSITION END--

private _lightTypes = ["Land_PortableLight_double_F", "Land_LampShabby_F"];

// 需要设置为无敌的物体类型列表
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

// ========== 生成所有物体并记录关键对象 ==========
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
    // server-side call leaves every client still simulating props the server has frozen. They
    // then settle, drift and fall differently on each machine, which is how the base ends up
    // looking different to a joining player than it does to the host.
    if (_class in _lightTypes || _class == "B_supplyCrate_F") then {
        _obj enableSimulationGlobal true;
    } else {
        _obj enableSimulationGlobal false;
    };

    // 混凝土墙和伪装网设为无敌（原有逻辑）
    if (_class == "CamoNet_BLUFOR_open_F" || (toLower _class) find "land_camo" == 0) then {
        _obj allowDamage false;
    };

    // 新增：对指定类型物体禁用伤害
    if (_class in _invulnerableTypes) then {
        _obj allowDamage false;
    };
    
    // 记录关键对象
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

// 设置全局 HQ 建筑变量
bluHQ_object = _hqObj;
publicVariable "bluHQ_object";

// Every anchor fnc_placeHQUnits reads lives in these keys. They are written before the placement
// call rather than beside each spawn so the rebuild -- which has nothing but the namespace to work
// from -- places its units off exactly the data this build used.

// 机枪锚定沙袋
private _mgAnchorPosX = _spawnBaseX + (24.0503 - _compCenterX);
private _mgAnchorPosY = _spawnBaseY + (-13.7368 - _compCenterY);
private _mgAnchor = nearestObject [[_mgAnchorPosX, _mgAnchorPosY, 0] apply { _x + 0 }, "Land_SandbagBarricade_01_hole_F"];
missionNamespace setVariable ["HQ_redeploy_mgAnchor", _mgAnchor, true];

// AA炮：基于HQ建筑的模型XY与高度偏移
missionNamespace setVariable ["HQ_redeploy_aaData", [
    [blufor_TURRET_AA, [-0.31131, 0.814453], 1.252556]
], true];

// 兵种池。Broadcast because client_init reads it to caption the guards, and because a FOB's own
// patrol draws from it too (init_hq/fnc_guardsFOB.sqf) -- the HQ_ prefix is where it is set, not
// who may read it.
private _baseGuardTypes = [blufor_SOLDIER_X, blufor_SOLDIER_LAT_X, blufor_SOLDIER_GL_X, blufor_SOLDIER_TL_X, blufor_SOLDIER_SL_X, blufor_SOLDIER_AR_X, blufor_MARKSMAN_X];
missionNamespace setVariable ["HQ_redeploy_guardTypes", _baseGuardTypes, true];

missionNamespace setVariable ["HQ_redeploy_towers", _allTowersList, true];

// 门口双人组：模型XY、高度偏移、朝向、动作
missionNamespace setVariable ["HQ_redeploy_hqGuardsData", [
    [[-5.49573, -0.923828], -4.10893, 180, "STAND"],
    [[-4.84598, -3.90649], -4.03631, 180, "STAND_IA"]
], true];
missionNamespace setVariable ["HQ_redeploy_medGuardsData", [
    [[1.49021, -5.54492], -1.37312, "STAND_IA"],
    [[3.18945, -5.54492], -1.37312, "STAND"]
], true];

// 医疗帐篷与警卫室的网络ID
if (!isNull _medTent) then { missionNamespace setVariable ["HQ_medTent_netId", netId _medTent, true]; };
if (!isNull _guardBoxObj) then { missionNamespace setVariable ["HQ_guardBox_netId", netId _guardBoxObj, true]; };

// 巡逻队：随机兵种，出生点用实测的模型坐标和高度偏移
private _patrolUnits = [];
for "_i" from 1 to base_patrol_squad do { _patrolUnits pushBack (selectRandom _baseGuardTypes); };
private _patrolSpawnXY = _hqObj modelToWorld [1.27142, -21.9805, 0];
missionNamespace setVariable ["HQ_redeploy_patrolUnits", _patrolUnits, true];
missionNamespace setVariable ["HQ_redeploy_patrolSpawnPos", [
    _patrolSpawnXY select 0,
    _patrolSpawnXY select 1,
    (getPosWorld _hqObj select 2) + (-3.87396)
], true];

call fnc_placeHQUnits;

// 军官：模型XY + 世界Z偏移，精确放置
private _xyWorld = _hqObj modelToWorld [0.0896273, -0.0180664, 0];
private _worldPos = [
    _xyWorld select 0,
    _xyWorld select 1,
    (getPosWorld _hqObj select 2) + (-3.27229)
];
private _offGrp = [_worldPos, WEST, [blufor_OFFICER_X], [], [], [0.4,0.6]] call BIS_fnc_spawnGroup;
private _officer = (units _offGrp) select 0;
_officer allowDamage true;
// Global: the local form freezes the officer on the server alone, so every client keeps
// simulating a unit hard-placed at an absolute Z and renders it falling.
_officer enableSimulationGlobal false;
_officer setPosWorld _worldPos;
_officer setDir 180;  // 面朝外，如需调整修改此角度
_officer setBehaviour "CARELESS";
_officer setCombatMode "BLUE";
_officer disableAI "TARGET"; _officer disableAI "AUTOTARGET";
_officer disableAI "FSM"; _officer disableAI "MOVE";
_officer setVariable ["asr_ai_exclude", true];
_officer setVariable ["NOAI", 1, false];
_officer setVariable ["Vcm_Disable", true];
_officer setVariable ["lambs_danger_disableAI", true];
removeBackpackGlobal _officer;
// An "Acts_" ambient animation holds through death: the corpse keeps the standing pose and
// never ragdolls, so hits read as having no effect and the officer looks invulnerable. The
// tower guards escape this because BIS_fnc_ambientAnimCombat breaks its own animation; a raw
// switchMove has nothing that does. Clearing the move lets the death animation play.
_officer addEventHandler ["Killed", {
    params ["_unit"];
    [_unit, ""] remoteExec ["switchMove", 0];
    // The queued pose goes with it. Left in the queue, a player joining after the officer dies
    // is handed the standing animation for a corpse -- the state clearing the move exists to
    // prevent, arriving by the other route.
    remoteExec ["", format ["hq_pose_%1", netId _unit]];
}];
// He is a campaign loss condition, so he cannot be one of the team's to end. Damage is refused
// outright rather than merely discounted at the point of death: counting only OPFOR kills would
// still let anyone delete the officer the HQ terminal and the request menu hang off, and losing
// him to a stray burst in a base firefight is the ordinary case, not the malicious one.
// _instigator names the player behind an explosive or a vehicle where _source is the thing that
// did the damage; either being WEST is enough to refuse.
_officer addEventHandler ["HandleDamage", {
    params ["", "", "_damage", "_source", "", "", "_instigator"];
    private _by = [_source, _instigator] select (!isNull _instigator);
    if (!isNull _by && {side _by == WEST}) exitWith { 0 };
    _damage
}];
hq_blu1 = _officer; publicVariable "hq_blu1";
blu_officer_object = _officer; publicVariable "blu_officer_object";
[_officer] spawn {
    waitUntil {sleep 10; !alive hq_blu1};
    ["TaskFailed", ["", localize "STR_DUWS_T_amiszycs"]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated, false];
    campaign_lost = true;
    campaign_lost_body = "STR_DUWS_T_CAMPAIGN_LOST_OFFICER";
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

// 路障旁工兵：基于 RoadBarrier 模型XY + 世界Z偏移放置，特定装备
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
    removeHeadgear _unit;
    _unit unassignItem "NVGoggles";
    _unit removeItem "NVGoggles";
    _unit unassignItem "NVGoggles_OPFOR";
    _unit removeItem "NVGoggles_OPFOR";
    _unit unassignItem "NVGoggles_INDEP";
    _unit removeItem "NVGoggles_INDEP";
    // 计算朝向帐篷的方向
    [_unit, _dirToTent] spawn {
        params ["_u", "_dir"];
        sleep 0.5;
        _u addHeadgear "H_Construction_headset_orange_F";
        _u addGoggles "G_EyeProtectors_F";
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

// ========== 交互动作 ==========
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
    [_mapBoard] remoteExec ["fnc_addBoardKillhouseActions", 0, format ["hq_mapboard_%1", netId _mapBoard]];
};

if (!isNull _hqObj) then {
    [_hqObj] remoteExec ["fnc_addHQBuildingActions", 0, format ["hq_building_%1", netId _hqObj]];
};

// 大门自动触发器：使用 netId 传递对象引用
if (!isNull _barGateObj && {isNil {_barGateObj getVariable "gate_trigger_added"}}) then {
    _barGateObj setVariable ["gate_trigger_added", true, true];
    private _gateNetId = netId _barGateObj;   // 捕获网络ID
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

// ========== 标记、触发器、重生点 ==========
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

// 重生点：帐篷门口 (测量坐标)
private _respawnXY = _medTent modelToWorld [-0.243752, -7.28516, 0];
private _respawnPos = [
    _respawnXY select 0,
    _respawnXY select 1,
    (getPosWorld _medTent select 2) + (-2.02112)
];
"respawn_west" setMarkerPos _respawnPos;

// 保存维修站和停机坪的ID（原有功能）
if (!isNull _repairDepot) then { missionNamespace setVariable ["HQ_repairDepot_netId", netId _repairDepot, true]; };
if (!isNull _helipad) then { missionNamespace setVariable ["HQ_helipad_netId", netId _helipad, true]; };

HQ_pos_found_generated = true; publicVariable "HQ_pos_found_generated";
["INFO", "BOOT", format ["BLUFOR HQ built at %1", PosOfBLUHQ]] call fnc_log;
// Drawn through the shared function so the HQ, every FOB and the MHQ all advertise the one radius
// the cleanup sweep honours -- this used to say 200 m against a sweep that spared 250.
[PosOfBLUHQ] call fnc_baseRangeMarker;