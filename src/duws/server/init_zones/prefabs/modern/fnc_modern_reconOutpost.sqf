// Locality: server -- inherited from server/init_zones/fnc_createzone.sqf.
// fnc_modern_reconOutpost.sqf (基于 composition 偏移量重构版)
// 原始 Composition 中心: [1540.2646, 5, 2299.9314] (x, z, y)
_centerSpawn = _this select 0;
_centerSpawnX = _centerSpawn select 0;
_centerSpawnY = _centerSpawn select 1;

private _origCenterZ = 5.0;
private _newCenterZ = getTerrainHeightASL [_centerSpawnX, _centerSpawnY];
if (_newCenterZ <= 0) then { _newCenterZ = 0; };

// 需要保留模拟的物体（有动画、可驾驶、可交互）
private _keepSimulation = [
    "Land_Campfire_F",
    "Land_TentDome_F",
    "Land_BagBunker_Tower_F",
    "Land_Cargo_Patrol_V1_F",
    "Land_Cargo_Tower_V1_F"
];

// 所有物体: [类名, X偏移, Y偏移, Z海拔, 方向度数, 是否为武器]
// --DUWS-COMPOSITION BEGIN name="Recon Outpost" schema=A--
private _allObjectsData = [
    // === 内层 Layer (72个物体) ===
    ["Land_Campfire_F",             2.0784,   0.4236, 0.2196, 210.0, false],
    ["Land_WoodPile_F",             5.7249,   1.7712, 0.2599, 277.8, false],
    ["Land_Sleeping_bag_F",         4.4241,  -2.3674, 0.0258, 317.5, false],
    ["Land_Sleeping_bag_F",         2.2034,  -3.5061, 0.0258, 357.9, false],
    ["Land_BagFence_Round_F",     -14.4607,   5.2029, 0.4193, 113.6, false],
    ["Land_BagFence_Round_F",     -12.3084,   6.0583, 0.4193, 200.2, false],
    ["Land_BagFence_Round_F",     -13.8084,   3.0000, 0.4193,  29.3, false],
    ["Land_Camping_Light_F",        0.1799,   1.4099, 0.1187, 178.7, false],
    ["Land_Sleeping_bag_brown_F",   5.8909,  -0.1936, 0.0258, 281.5, false],
    ["Land_BagFence_Round_F",       4.3538, -13.9338, 0.4193,   2.5, false],
    ["Land_Axe_F",                  4.8206,   1.1912, 0.0272,  24.9, false],
    ["Land_CanisterPlastic_F",     -1.0505,  -2.0530, 0.3478, 209.0, false],
    ["Land_FMradio_F",              3.0549,  -2.5940, 0.0726, 171.8, false],
    ["Land_TinContainer_F",        -0.3787,  -2.5413, 0.0994, 269.5, false],
    ["Land_CanisterPlastic_F",     -0.7029,  -2.6135, 0.3478,  78.4, false],
    ["Land_BakedBeans_F",           3.9983,   1.2810, 0.0591, 266.6, false],
    ["Land_MetalWire_F",            4.6526,   2.9412, 0.0026, 207.2, false],
    ["Land_Gloves_F",               4.6311,   1.1091, 0.0000, 281.1, false],
    ["Land_Sacks_heap_F",          -1.2107,   6.4763, 0.3908,  93.1, false],
    ["Land_CampingChair_V1_F",     -0.3416,   0.7673, 0.5077, 280.4, false],
    ["Land_Bucket_F",               6.1252,   5.0623, 0.1653, 246.3, false],
    ["Land_CampingChair_V1_F",      1.6917,   3.0310, 0.5077, 346.7, false],
    ["Land_Razorwire_F",           15.5061, -10.5178, 0.7551, 316.3, false],
    ["Land_Razorwire_F",           19.4280,  -3.7834, 0.7551, 284.5, false],
    ["Land_Razorwire_F",          -11.2927,  -3.5667, 0.7551,  72.4, false],
    ["Land_Razorwire_F",           -6.9919, -10.0881, 0.7551,  40.7, false],
    ["Land_BagFence_Short_F",       6.2874, -13.0784, 0.4143, 315.2, false],
    ["Land_BagFence_Short_F",       2.4241, -12.8616, 0.4143, 224.3, false],
    ["Land_CanisterPlastic_F",      7.6448, -11.2952, 0.3478,  99.9, false],
    ["Land_TentDome_F",             1.8674,   8.4783, 0.6192, 267.0, false],
    ["Land_TentDome_F",             6.1331,   7.8708, 0.6192, 280.8, false],
    ["Land_Garbage_square5_F",      1.9631,   3.1091, 0.0394, 189.4, false],
    ["Land_BagBunker_Tower_F",     15.2249,   5.0232, 2.2100, 253.9, false],
    ["I_G_HMG_02_high_F",         -3.9333,  12.5115, 3.0972, 325.5, true],
    ["I_G_HMG_02_high_F",        -12.7068,   4.2205, 3.1264, 284.0, true],
    ["I_G_HMG_02_high_F",          4.2288, -12.3499, 2.5396, 175.5, true],
    ["I_G_HMG_02_high_F",         17.1467,   5.1462, 4.8121,  91.2, true],
    ["B_G_Quadbike_01_F",         10.1975,  -2.4592, 2.2605, 111.8, false],
    ["B_G_Quadbike_01_F",          8.7561,  -6.0510, 2.4316, 153.4, false],
    ["B_UAV_01_F",                -0.8142,  -0.6995, 0.7226,   0.0, false],
    ["Land_BagFence_Round_F",     -5.6892,  12.8357, 0.4193,  99.9, false],
    ["Land_BagFence_Round_F",     -3.8044,  14.1951, 0.4193, 187.5, false],
    ["Land_BagFence_Short_F",     -5.1990,  10.8337, 0.4143,  58.2, false],
    ["Land_BagFence_Short_F",     -2.1697,  12.9294, 0.4143,  55.2, false],
    ["Land_Sleeping_bag_brown_F", -8.8084,   0.2380, 0.0258, 135.5, false],
    ["Land_Sleeping_bag_brown_F", -2.8806,  -3.0354, 0.0258, 284.1, false],
    ["Land_Sleeping_bag_F",       -6.1521,   1.1697, 0.0258, 182.6, false],
    ["Land_Sleeping_bag_F",       -3.7009,  -0.1194, 0.0258, 230.3, false],
    ["Land_Sleeping_bag_F",       -4.9060,  -5.4846, 0.0258, 337.4, false],
    ["Land_Sleeping_bag_brown_F", -9.7029,  -2.2444, 0.0258,  91.1, false],
    ["Land_Campfire_F",           -6.3533,  -2.3167, 0.2196,  27.4, false],
    ["Land_WoodPile_F",           -7.7537,  -5.3206, 0.2599, 120.2, false],
    ["Land_Ammobox_rounds_F",    -8.0115,   1.0427, 0.1054,  80.3, false],
    ["Land_Ammobox_rounds_F",    -7.6208,   0.9958, 0.1054,  36.8, false],
    ["Land_CratesShabby_F",      15.8479,  -2.3831, 0.7598, 358.4, false],
    ["Land_Sacks_heap_F",        14.3303,  -2.3225, 0.3908,  27.1, false],
    ["Land_Matches_F",           -6.9275,  -1.4709, 0.0111,   5.0, false],
    ["Land_ButaneCanister_F",    -3.4861,  10.4607, 0.0995,  60.5, false],
    ["Land_CanisterPlastic_F",   -3.9939,  10.0818, 0.3478, 266.7, false],
    ["Land_Canteen_F",           -8.9294,  -2.9768, 0.1303,  73.4, false],
    ["Land_DuctTape_F",          -8.6013,  -3.0139, 0.0250,  33.6, false],
    ["Land_GasCanister_F",       -3.3220,  10.6150, 0.0553,  96.2, false],
    ["Land_BakedBeans_F",        -6.3474,  -5.1643, 0.0591, 333.9, false],
    ["Land_BakedBeans_F",        -6.1794,  -5.1799, 0.0591,  30.6, false],
    ["Land_Canteen_F",           -3.6521,  -1.4299, 0.1303,  43.1, false],
    ["Land_PainKillers_F",       -3.7791,  -1.1721, 0.0425,   5.0, false],
    ["Land_Bandage_F",           -3.2068,  10.4705, 0.0252, 350.7, false],
    ["Land_Bandage_F",           -3.3455,  10.4431, 0.0252,  82.3, false],
    ["Land_Axe_fire_F",          -8.3611,  -4.3225, 0.0275,   5.8, false],
    ["Land_WoodenBox_F",         14.5881,  -5.3850, 0.0,      290.3, false],
    ["Land_WoodenBox_F",         15.9026,  -4.3811, 0.0,      250.2, false],
    ["Land_Garbage_square3_F",   -6.4744,  -4.2385, 0.0519, 198.8, false],

    // === 外层额外武器 ===
    ["B_static_AA_F",            -1.2732,  -5.5061, 2.0122,   0.0, true],
    ["B_static_AA_F",             6.1526,  -2.4729, 1.9200,   0.0, true],
    ["B_Mortar_01_F",             3.2151,  -5.8928, 1.7602,  76.2, true]
];
// --DUWS-COMPOSITION END--

// 地形倾斜类型
private _tiltTypes = [
    "Land_HBarrierBig_F", "Land_HBarrier_5_F", "Land_BagBunker_Large_F",
    "Land_BagFence_Round_F", "Land_BagFence_Short_F", "Land_BagFence_Long_F",
    "Land_BagFence_Corner_F", "Land_BagFence_End_F",
    "Land_SandbagBarricade_01_hole_F", "Land_Razorwire_F",
    "Land_BagBunker_Tower_F"
];

// ========= 第一步：非武器/非载具物体贴地；载具贴地保留模拟 =========
{
    _x params ["_class", "_offsetX", "_offsetY", "_offsetZ", "_dir", "_isWeapon"];
    if (_isWeapon) then { continue; };

    private _newX = _centerSpawnX + _offsetX;
    private _newY = _centerSpawnY + _offsetY;

    // 载具特殊处理：贴地，保留模拟
    if (_class isKindOf "AllVehicles") then {
        private _obj = createVehicle [_class, [_newX, _newY, 0], [], 0, "CAN_COLLIDE"];
        _obj setPosATL [_newX, _newY, 0];
        _obj setDir _dir;
        continue;
    };

    private _obj = createVehicle [_class, [_newX, _newY, 0], [], 0, "CAN_COLLIDE"];
    _obj setPosATL [_newX, _newY, 0];

    // 工事倾斜
    if (_class in _tiltTypes) then {
        _obj setVectorUp (surfaceNormal [_newX, _newY]);
    };
    _obj setDir _dir;

    // 需要模拟的物体不禁用；其余静态物体禁用模拟
    if !(_class in _keepSimulation) then {
        _obj enableSimulation false;
    };

    // 易碎装饰无敌
    if (_class in ["Land_CampingChair_V1_F","Land_Camping_Light_F","Land_TentDome_F","Land_WaterTank_F","Land_Pallets_stack_F","Land_PaperBox_closed_F","Land_Ammobox_rounds_F","Land_WoodenBox_F","Land_CratesShabby_F","Land_FMradio_F","Land_TinContainer_F","Land_CanisterPlastic_F","Land_Axe_F","Land_Bucket_F","Land_Matches_F","Land_ButaneCanister_F","Land_GasCanister_F","Land_Canteen_F","Land_DuctTape_F","Land_PainKillers_F","Land_Bandage_F","Land_Sacks_heap_F","Land_WoodPile_F","Land_MetalWire_F","Land_Gloves_F","Land_BakedBeans_F"]) then {
        _obj allowDamage false;
    };
} forEach _allObjectsData;

sleep 2;

// ========= 第二步：武器物体海拔还原 =========
private _weaponList = [];
{
    _x params ["_class", "_offsetX", "_offsetY", "_offsetZ", "_dir", "_isWeapon"];
    if (!_isWeapon) then { continue; };

    private _newX = _centerSpawnX + _offsetX;
    private _newY = _centerSpawnY + _offsetY;
    // 武器 Z 坐标 = 新中心海拔 + 原始海拔偏移（虽然 offsetZ 已经是绝对海拔，但相对中心差值才是高度差）
    private _newZ = _newCenterZ + _offsetZ;

    private _obj = createVehicle [_class, [_newX, _newY, _newZ], [], 0, "CAN_COLLIDE"];
    _obj enableSimulation false;
    _obj setPosWorld [_newX, _newY, _newZ];
    _obj setDir (_centerSpawn getDir [_newX, _newY]);
    _obj setPosWorld [_newX, _newY, _newZ]; // 确保
    _weaponList pushBack _obj;
} forEach _allObjectsData;

sleep 2;
// ========= 第三步：分配炮手 =========
private _hmgList = nearestObjects [_centerSpawn, ["I_G_HMG_02_high_F", "I_HMG_02_high_F"], 150];
private _mortarList = nearestObjects [_centerSpawn, ["B_Mortar_01_F"], 150];
private _aaList = nearestObjects [_centerSpawn, ["B_static_AA_F"], 150];
private _allWeapons = _hmgList + _mortarList + _aaList;

if (count _allWeapons > 0) then {
    private _unitTypes = [];
    for "_i" from 1 to (count _allWeapons) do { _unitTypes pushBack opfor_SOLDIER_X; };
    private _spawnPos = _centerSpawn findEmptyPosition [0, 30];
    if (count _spawnPos == 0) then { _spawnPos = _centerSpawn; };
    private _guardGroup = [_spawnPos, EAST, _unitTypes, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    _guardGroup deleteGroupWhenEmpty true;

    private _idx = 0;
    { (units _guardGroup select _idx) moveInGunner _x; _idx = _idx + 1; } forEach _hmgList;
    { (units _guardGroup select _idx) moveInGunner _x; _idx = _idx + 1; } forEach _mortarList;
    { (units _guardGroup select _idx) moveInGunner _x; _idx = _idx + 1; } forEach _aaList;

    { if (!isNull _x) then { _x enableSimulation true; }; } forEach _allWeapons;
    [_guardGroup, _centerSpawn] call bis_fnc_taskDefend;
};

// 营地灯（已有 Land_Camping_Light_F，额外在中心加一个保底）
_lightDefault = nearestObject [_centerSpawn, "Land_Camping_Light_F"];
if (isNull _lightDefault) then {
    private _light1 = createVehicle ["Land_Camping_Light_F", [_centerSpawnX, _centerSpawnY, 0], [], 0, "NONE"];
    _light1 setPosATL [_centerSpawnX, _centerSpawnY, 0];
    _light1 allowdamage false;
    _light1 setdamage 0;
};