// Locality: server -- inherited from server/init_zones/fnc_createzone.sqf.
// fnc_modern_vehfittingstation.sqf (基于 composition 偏移量重构版)
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

// 保留模拟的物体（可交互、可破坏）
private _keepSimulation = [
    "Land_RepairDepot_01_green_F",
    "FlexibleTank_01_forest_F"
];

// 所有物体 [类名, 偏移X, 偏移Y, Z海拔, 方向(度), 是否为武器]
// --DUWS-COMPOSITION BEGIN name="Vehicle Refit Station" schema=A--
private _allObjectsData = [
    // ===== 子层 "Camp Courage" (34个) =====
    ["Land_PortableLight_double_F", -0.1337, 12.2014, 1.0838, 228.3, false],
    ["Land_ToiletBox_F",              3.0636,  9.7249, 1.2508, 359.2, false],
    ["Land_Cargo_Patrol_V3_F",       10.5656,-11.4802, 4.9050, 314.0, false],
    ["Land_HBarrier_5_F",             5.3195, 12.1604, 0.7405, 180.6, false],
    ["Land_HBarrier_5_F",             0.6593, 14.1526, 0.7405, 230.8, false],
    ["Land_HBarrier_5_F",            16.7042,  1.9905, 0.7405, 240.9, false],
    ["Land_HBarrier_5_F",            16.8722, -3.1677, 0.7405, 109.9, false],
    ["Land_HBarrier_5_F",            -6.8641,-16.8748, 0.7405,  21.7, false],
    ["Land_HBarrier_5_F",            17.1827,-11.5212, 0.7405,  93.7, false],
    ["Land_HBarrier_5_F",            15.0870,-16.1931, 0.7405, 133.9, false],
    ["Land_HBarrier_5_F",           -13.4188, -2.8630, 0.7405,  88.7, false],
    ["Land_HBarrier_5_F",           -15.3759,  2.4182, 0.7405,  50.8, false],
    ["Land_HBarrier_5_F",           -17.3680,  6.8557, 0.7405,  88.1, false],
    ["Land_HBarrier_5_F",           -16.7489, 12.4026, 0.7405, 108.4, false],
    ["Land_HBarrier_5_F",            -2.1884,-16.1599, 0.7405, 324.9, false],
    ["Land_HBarrier_5_F",             7.3800,  8.5901, 0.7405, 271.4, false],
    ["Land_HBarrier_5_F",            -3.7001, 16.3811, 0.7405, 177.7, false],
    ["Land_HBarrier_5_F",            -9.1415, 16.0940, 0.7405, 177.7, false],
    ["Land_HBarrier_5_F",           -11.2137,-15.3123, 0.7405,  48.1, false],
    ["Land_HBarrier_5_F",             2.9816,-15.1091, 0.7405,  23.9, false],
    ["Land_HBarrier_5_F",             7.1241,  2.9612, 0.7405, 273.5, false],
    ["Land_PortableLight_double_F",  -5.5731, 14.0276, 1.0838, 357.0, false],
    ["Land_PortableLight_double_F",  14.0031,-14.8689, 1.0838, 311.6, false],
    ["Land_WaterTank_F",              1.0812,  9.0764, 0.6849, 270.4, false],
    ["Land_HBarrier_5_F",            15.6788,  7.2327, 0.7405, 270.6, false],
    ["Land_PaperBox_closed_F",        4.5265,-13.5837, 0.6432, 246.7, false],
    ["Land_Tyres_F",                  6.0148, -0.7400, 0.2723, 202.6, false],
    ["Land_ToiletBox_F",              5.5831,  9.7463, 1.2508, 359.2, false],
    ["Land_HBarrier_5_F",           -11.3173, -6.8435, 0.7405,  36.6, false],
    ["Land_PortableLight_double_F", -13.7723,  7.0471, 1.0838,  88.6, false],
    ["Land_PaperBox_open_empty_F",    6.6554,-14.1716, 0.6070,  33.2, false],
    ["Land_HBarrier_3_F",           -14.2762,-13.4841, 0.7983, 180.6, false],
    ["Land_GarbageBags_F",           -2.6259, 13.7581, 0.4336, 158.2, false],
    ["Land_HBarrier_5_F",           -13.7782, 15.1096, 0.7405, 153.5, false],

    // ===== 外层物体 =====
    ["Land_HelipadCircle_F",         -6.2059,  3.3499, 0.0,     0.0, false],
    ["Land_RepairDepot_01_green_F", -10.7743, 11.5706, 2.4180, 247.6, false],
    ["FlexibleTank_01_forest_F",    -14.0497,  5.4749, 0.5129,   0.0, false],
    ["FlexibleTank_01_forest_F",    -13.8993,  4.3342, 0.5129,   0.0, false],
    ["B_Mortar_01_F",                 3.8605,  0.9358, 2.0663,  59.9, true],
    ["B_static_AA_F",                -2.2079, 10.5569, 2.1954,   0.0, true],
    ["I_HMG_02_high_F",              10.1378,-12.9998, 6.6387, 130.6, true],
    ["Land_HBarrier_3_F",            15.7394, -7.4431, 0.7983,  56.7, false],
    ["Land_HBarrier_3_F",            10.9054,-18.2459, 0.7983,   0.0, false],
    ["Land_HBarrier_3_F",             7.4816,-17.1033, 0.7983, 213.2, false]
];
// --DUWS-COMPOSITION END--

// 需要贴合地形的工事类型
private _tiltTypes = [
    "Land_HBarrierBig_F","Land_HBarrier_5_F","Land_HBarrier_3_F","Land_BagBunker_Large_F",
    "Land_BagFence_Round_F","Land_BagFence_Short_F","Land_BagFence_Long_F",
    "Land_BagFence_Corner_F","Land_BagFence_End_F","Land_SandbagBarricade_01_hole_F",
    "Land_Razorwire_F"
];

// ─────────── 第一步：非武器物体 贴地 ───────────
{
    _x params ["_class", "_offsetX", "_offsetY", "_offsetZ", "_dir", "_isWeapon"];
    if (_isWeapon) then { continue; };

    private _newX = _centerSpawnX + _offsetX;
    private _newY = _centerSpawnY + _offsetY;

    private _obj = createVehicle [_class, [_newX, _newY, 0], [], 0, "CAN_COLLIDE"];
    [_obj, _zoneKey] call fnc_duws_keep;
    _obj setPosATL [_newX, _newY, 0];

    if (_class in _tiltTypes) then {
        _obj setVectorUp (surfaceNormal [_newX, _newY]);
    };
    _obj setDir _dir;

    // 保留模拟的物体不强制禁用
    if !(_class in _keepSimulation) then {
        _obj enableSimulationGlobal false;
    };

    // 易碎品无敌
    if (_class in ["Land_WaterTank_F","Land_PaperBox_closed_F","Land_PaperBox_open_empty_F","Land_GarbageBags_F"]) then {
        _obj allowDamage false;
    };
} forEach _allObjectsData;

sleep 2;

// ─────────── 第二步：武器 海拔还原 ───────────
private _weaponList = [];
{
    _x params ["_class", "_offsetX", "_offsetY", "_offsetZ", "_dir", "_isWeapon"];
    if (!_isWeapon) then { continue; };

    private _newX = _centerSpawnX + _offsetX;
    private _newY = _centerSpawnY + _offsetY;
    private _newZ = _newCenterZ + _offsetZ;

    private _obj = createVehicle [_class, [_newX, _newY, _newZ], [], 0, "CAN_COLLIDE"];
    [_obj, _zoneKey] call fnc_duws_keep;
    _obj enableSimulationGlobal false;
    _obj setPosWorld [_newX, _newY, _newZ];
    _obj setDir (_centerSpawn getDir [_newX, _newY]);
    _obj setPosWorld [_newX, _newY, _newZ];
    _weaponList pushBack _obj;
} forEach _allObjectsData;

sleep 2;
// ─────────── 第三步：分配炮手 ───────────
private _hmgList = nearestObjects [_centerSpawn, ["I_HMG_02_high_F"], 150];
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

    { if (!isNull _x) then { _x enableSimulationGlobal true; }; } forEach _allWeapons;
    [_guardGroup, _centerSpawn] call bis_fnc_taskDefend;
};

// 营地灯（备用）
private _light1 = createVehicle ["Land_Camping_Light_F", [_centerSpawnX, _centerSpawnY, 0], [], 0, "NONE"];
[_light1, _zoneKey] call fnc_duws_keep;
_light1 setPosATL [_centerSpawnX, _centerSpawnY, 0];
_light1 allowdamage false;
_light1 setdamage 0;