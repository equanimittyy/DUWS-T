// fnc_modern_CommStation.sqf (基于 composition 偏移量重构版)
_centerSpawn = _this select 0;
_centerSpawnX = _centerSpawn select 0;
_centerSpawnY = _centerSpawn select 1;

private _origCenterZ = 5.0;
private _newCenterZ = getTerrainHeightASL [_centerSpawnX, _centerSpawnY];
if (_newCenterZ <= 0) then { _newCenterZ = 0; };

// 全部物体 [类名, 偏移X, 偏移Y, 原Z海拔, 方向度, 是否武器]
private _allObjectsData = [
    // ===== 子层 "Camp Endurance" (50个) =====
    ["Land_HBarrier_5_F",           -11.3762,  -6.4556, 0.7405, 268.1, false],
    ["Land_HBarrier_5_F",            -9.5251, -10.9905, 0.7405, 227.2, false],
    ["Land_HBarrier_5_F",            11.7156,  -6.4097, 0.7405, 267.5, false],
    ["Land_HBarrier_5_F",            10.0084, -10.4739, 0.7405, 135.9, false],
    ["Land_HBarrier_5_F",            11.1830,   4.7688, 0.7405,  87.9, false],
    ["Land_HBarrier_5_F",             5.2806,  11.0784, 0.7405, 178.6, false],
    ["Land_HBarrier_5_F",             9.3257,   9.2964, 0.7405,  46.9, false],
    ["Land_HBarrier_5_F",            -5.7834,  10.6943, 0.7405, 356.5, false],
    ["Land_HBarrier_5_F",           -11.8129,   4.6897, 0.7405,  87.3, false],
    ["Land_Cargo_Patrol_V1_F",       -0.1263,   9.4963, 4.9050, 178.6, false],
    ["Land_Cargo_House_V1_F",        -5.8494,  -4.2407, 0.6900, 267.7, false],
    ["Land_Cargo_House_V1_F",         5.8696,   3.0283, 0.6900,  87.6, false],
    ["Land_HBarrier_5_F",             5.5326, -12.3162, 0.7405, 178.6, false],
    ["Land_HBarrier_5_F",            -5.4733, -12.6033, 0.7405, 178.6, false],
    ["Land_HBarrier_5_F",            -0.2291,  10.8889, 0.7405, 178.6, false],
    ["Land_HBarrier_5_F",            11.4440,  -0.8071, 0.7405,  87.8, false],
    ["Land_HBarrier_5_F",           -11.5475,  -0.8464, 0.7405,  87.9, false],
    ["Land_Razorwire_F",             14.3993, -14.9250, 0.7551, 314.6, false],
    ["Land_Razorwire_F",             13.8960,  14.4539, 0.7551, 226.5, false],
    ["Land_Razorwire_F",            -13.8828, -15.5498, 0.7551, 226.6, false],
    ["Land_Razorwire_F",             18.4553,  -0.1501, 0.7551, 265.4, false],
    ["Land_Razorwire_F",             -0.6996,  18.6753, 0.7551, 177.2, false],
    ["Land_Razorwire_F",            -18.5095,  -0.6072, 0.7551, 265.4, false],
    ["Land_HBarrier_1_F",           -10.2968, -19.1758, 0.7021, 318.4, false],
    ["Land_HBarrier_1_F",           -17.0604, -11.8965, 0.7021, 318.4, false],
    ["Land_HBarrier_1_F",           -18.0189,  -5.3652, 0.7021, 355.5, false],
    ["Land_HBarrier_1_F",           -18.8959,   4.0586, 0.7021, 355.5, false],
    ["Land_HBarrier_1_F",            -5.3956,  18.4792, 0.7021,  86.9, false],
    ["Land_HBarrier_1_F",             4.2430,  19.0261, 0.7021,  86.9, false],
    ["Land_HBarrier_1_F",            10.7054,  17.9106, 0.7021, 137.7, false],
    ["Land_HBarrier_1_F",            17.4554,  11.0747, 0.7021, 137.7, false],
    ["Land_HBarrier_1_F",            18.2482,   4.7017, 0.7021, 173.4, false],
    ["Land_HBarrier_1_F",            19.0236,  -5.0874, 0.7021, 173.4, false],
    ["Land_HBarrier_1_F",            17.7323, -11.5598, 0.7021, 224.6, false],
    ["Land_HBarrier_1_F",            10.9628, -18.4524, 0.7021, 224.6, false],
    ["Land_HBarrier_3_F",            -4.1083, -19.2993, 0.7983, 358.8, false],
    ["Land_HBarrier_3_F",             4.5148, -19.0024, 0.7983, 358.8, false],
    ["Land_PortableLight_double_F",   9.0575,  -9.5046, 1.0838, 136.7, false],
    ["Land_PortableLight_double_F",  -3.7432, -11.2083, 1.0838, 340.7, false],
    ["Land_PaperBox_closed_F",       -9.3374,   3.7556, 0.6432, 312.1, false],
    ["Land_PaperBox_closed_F",       -7.4218,   3.0793, 0.6432,  69.6, false],
    ["Land_WaterTank_F",             -6.2468,  -9.4587, 0.6849, 358.4, false],
    ["Land_ToiletBox_F",              9.2805,  -1.7283, 1.2201,  88.4, false],
    ["Land_HBarrier_1_F",           -11.7710,   7.5996, 0.7021,  42.7, false],
    ["Land_HBarrier_1_F",            -8.7881,  10.3762, 0.7021,  48.2, false],
    ["Land_TTowerSmall_2_F",          5.5544,   0.2683, 8.4787, 358.8, false],
    ["Land_GarbageBarrel_01_F",       8.8469,  -5.6638, 0.6138, 164.0, false],
    ["Land_ToiletBox_F",              9.3645,  -4.2947, 1.2201,  88.4, false],
    ["Land_HBarrier_3_F",           -15.8307,   9.7515, 0.7983, 305.4, false],
    ["Land_HBarrier_3_F",           -11.0609,  14.7278, 0.7983, 324.8, false],

    // ===== 外层独立物体 =====
    ["I_G_HMG_02_high_F",           -0.8254,  10.4836, 6.5372,   0.0, true],
    ["Land_HelipadSquare_F",          0.4856,  -1.7646, 0.0,    358.2, false],
    ["Land_BagFence_Round_F",         0.1228, -14.0510, 0.4193,   0.0, false],
    ["I_HMG_02_high_F",             -0.0344, -12.2378, 2.4627, 183.4, true],
    ["B_Mortar_01_F",                 6.8885,  -8.8210, 2.2766,   0.0, true],
    ["B_static_AA_F",                -8.0374,   6.6863, 1.8252,   0.0, true],
    ["Land_BagFence_Round_F",         7.4681,  17.4617, 0.4193, 190.0, false],
    ["I_HMG_02_high_F",              7.3066,  15.6484, 2.4627,  13.4, true],
    ["Land_BagFence_Round_F",       -17.4053,   6.4526, 0.4193, 107.3, false],
    ["I_HMG_02_high_F",            -15.6263,   6.0654, 2.4627, 290.6, true]
];

// 需要贴合地形的工事类型
private _tiltTypes = [
    "Land_HBarrierBig_F","Land_HBarrier_5_F","Land_HBarrier_3_F","Land_HBarrier_1_F",
    "Land_BagBunker_Large_F","Land_BagFence_Round_F","Land_BagFence_Short_F",
    "Land_BagFence_Long_F","Land_BagFence_Corner_F","Land_BagFence_End_F",
    "Land_SandbagBarricade_01_hole_F","Land_Razorwire_F"
];

// ── 第一步：非武器物体 贴地 ──
{
    _x params ["_class","_offsetX","_offsetY","_offsetZ","_dir","_isWeapon"];
    if (_isWeapon) then { continue; };

    private _newX = _centerSpawnX + _offsetX;
    private _newY = _centerSpawnY + _offsetY;

    private _obj = createVehicle [_class, [_newX, _newY, 0], [], 0, "CAN_COLLIDE"];
    _obj setPosATL [_newX, _newY, 0];

    if (_class in _tiltTypes) then {
        _obj setVectorUp (surfaceNormal [_newX, _newY]);
    };
    _obj setDir _dir;

    // 禁用模拟（所有静态物体）
    _obj enableSimulation false;

    // 易碎物品无敌
    if (_class in ["Land_WaterTank_F","Land_PaperBox_closed_F","Land_ToiletBox_F","Land_GarbageBarrel_01_F"]) then {
        _obj allowDamage false;
    };
} forEach _allObjectsData;

sleep 2;

// ── 第二步：武器 海拔还原 ──
private _weaponList = [];
{
    _x params ["_class","_offsetX","_offsetY","_offsetZ","_dir","_isWeapon"];
    if (!_isWeapon) then { continue; };

    private _newX = _centerSpawnX + _offsetX;
    private _newY = _centerSpawnY + _offsetY;
    private _newZ = _newCenterZ + _offsetZ;

    private _obj = createVehicle [_class, [_newX, _newY, _newZ], [], 0, "CAN_COLLIDE"];
    _obj enableSimulation false;
    _obj setPosWorld [_newX, _newY, _newZ];
    _obj setDir (_centerSpawn getDir [_newX, _newY]);
    _obj setPosWorld [_newX, _newY, _newZ];
    _weaponList pushBack _obj;
} forEach _allObjectsData;

sleep 2;
// ── 第三步：分配炮手 ──
private _hmgList = nearestObjects [_centerSpawn, ["I_G_HMG_02_high_F","I_HMG_02_high_F"], 150];
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