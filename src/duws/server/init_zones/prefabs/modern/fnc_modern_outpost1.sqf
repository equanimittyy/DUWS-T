// Locality: server -- inherited from server/init_zones/fnc_createzone.sqf.
// fnc_modern_outpost1.sqf (基于 composition 偏移量重构版)
// 原始 Composition 中心: [3302.7124, 5, 707.04645] (x, z, y)
_centerSpawn = _this select 0;
// Zone construction is campaign property, filed under the zone it stands in so the whole
// composition -- turret, sandbag and camo net alike -- can be released together. A wrecked
// turret leaves its undamaged surroundings behind, and nothing about those props marks them
// as garbage; only the key knows they belonged to something.
private _zoneKey = format ["zone_%1_%2", round (_centerSpawn select 0), round (_centerSpawn select 1)];
// Emplacements are filed apart from the rest of the composition: capture releases the guns,
// while the cover, crates and camp kit stay with the position.
private _gunsKey = "guns_" + _zoneKey;
_centerSpawnX = _centerSpawn select 0;
_centerSpawnY = _centerSpawn select 1;

private _origCenterZ = 5.0;             // 原始中心海拔
private _newCenterZ = getTerrainHeightASL [_centerSpawnX, _centerSpawnY];
if (_newCenterZ <= 0) then { _newCenterZ = 0; };

// 所有物体数据: [类名, 中心X偏移, 中心Y偏移, 原Z海拔, 方向(度), 是否武器]
// --DUWS-COMPOSITION BEGIN name="Outpost 1" schema=A--
private _allObjectsData = [
    // === 武器（外层） ===
    ["I_HMG_02_high_F",  -7.4336,  25.0707, 2.3202,   0.0, true],
    ["I_HMG_02_high_F",   6.3711, -29.4488, 2.3223, 180.0, true],
    ["I_HMG_02_high_F", -10.2656, -22.4390, 6.6555, 177.6, true],
    ["B_static_AA_F",   -16.3594,  12.5004, 1.5592,   0.0, true],
    ["I_HMG_02_high_F", -24.1992,   4.5336, 1.8397, 273.0, true],
    ["B_Mortar_01_F",    20.4199,  -1.7847, 1.6701,   0.0, true],
    ["I_HMG_02_high_F",   9.1772,  21.1506, 6.6164,   0.0, true],

    // === 杂物（外层） ===
    ["Land_BagFence_Round_F", -25.8027,  4.5981, 0.4193,  87.9, false],
    ["Land_GarbageBags_F",       8.2363,  1.3950, 0.4956,   0.0, false],
    ["Land_GarbageHeap_03_F",  -13.2920, 18.5410, 0.5271,   0.0, false],

    // === 子层 "Camp Audacity" 物体 ===
    ["Land_HBarrierBig_F",      12.8906, -23.2379, 1.2100,   0.8, false],
    ["Land_BagBunker_Large_F",   4.0254, -26.2457, 1.0680,   0.8, false],
    ["Land_PortableLight_double_F", -10.7266, -24.3961, 1.0838,   0.8, false],
    ["Land_ToiletBox_F",        19.2832,  10.0082, 1.2508,  90.3, false],
    ["Land_WaterTank_F",       -18.7188,  -8.2984, 0.6849, 358.9, false],
    ["Land_HBarrierBig_F",      20.6113, -20.1617, 1.2100, 318.5, false],
    ["Land_HBarrierBig_F",      24.0156, -12.6304, 1.2100, 272.9, false],
    ["Land_HBarrier_5_F",       -7.6172, -25.7398, 0.7405,   0.8, false],
    ["Land_HBarrier_5_F",      -13.1602, -25.6754, 0.7405,   0.8, false],
    ["Land_HBarrier_5_F",       -5.4746, -22.1851, 0.7405, 272.1, false],
    ["Land_HBarrierBig_F",     -17.0176, -22.2066, 1.2100, 272.4, false],
    ["Land_HBarrierBig_F",     -20.6133, -15.2964, 1.2100, 217.5, false],
    ["Land_HBarrierBig_F",     -24.0645,  -7.9586, 1.2100, 272.4, false],
    ["Land_HBarrierBig_F",     -18.6973,  -4.7750, 1.2100,   0.8, false],
    ["Land_HBarrierBig_F",     -13.5625,  21.1508, 1.2100, 178.7, false],
    ["Land_BagBunker_Large_F",  -4.7500,  21.7836, 1.0680, 178.7, false],
    ["Land_PortableLight_double_F", 9.8027, 23.1352, 1.0838, 178.7, false],
    ["Land_HBarrierBig_F",     -21.1523,  17.7953, 1.2100, 136.3, false],
    ["Land_HBarrierBig_F",     -24.1133,  10.6293, 1.2100,  90.6, false],
    ["Land_HBarrier_5_F",       6.6582,  24.5668, 0.7405, 178.7, false],
    ["Land_HBarrier_5_F",      12.1992,  24.6938, 0.7405, 178.7, false],
    ["Land_HBarrier_5_F",       4.6484,  20.9145, 0.7405,  89.9, false],
    ["Land_HBarrierBig_F",     16.1934,  21.3774, 1.2100,  90.3, false],
    ["Land_HBarrierBig_F",     20.0293,  14.5903, 1.2100,  35.4, false],
    ["Land_HBarrierBig_F",     23.7559,   7.3930, 1.2100,  90.3, false],
    ["Land_HBarrier_5_F",      24.1465,   0.2641, 0.7405,  90.8, false],
    ["Land_HBarrierBig_F",     18.5215,   4.0082, 1.2100, 178.7, false],
    ["Land_HBarrier_5_F",      24.0234,  -5.3726, 0.7405,  90.8, false],
    ["Land_Cargo20_military_green_F", 13.8574, 0.3442, 1.4693, 180.7, false],
    ["Land_HBarrier_5_F",     -11.4629,  -4.9156, 0.7405,   0.8, false],
    ["Land_HBarrier_5_F",      11.2930,   3.8168, 0.7405,   0.6, false],
    ["Land_ToiletBox_F",       19.3301,   7.8207, 1.2508,  90.3, false],
    ["Land_WaterBarrel_F",     -9.5488,  -7.2359, 0.5668, 189.7, false],
    ["Land_PortableLight_double_F", -19.7227, 16.2211, 1.0838, 314.9, false],
    ["Land_PortableLight_double_F", -15.8047, -17.1382, 1.0838, 241.5, false],
    ["Land_Cargo20_military_green_F", 20.6582, -8.6695, 1.4693,  89.6, false],
    ["Land_Cargo_Patrol_V1_F", 10.3125,  20.3168, 4.9050, 178.8, false],
    ["Land_Cargo_Patrol_V1_F",-11.0332, -21.4097, 4.9050,   0.1, false],
    ["Land_Pallets_F",         14.9492,   6.5317, 0.3183, 354.9, false],
    ["Land_MetalBarrel_F",    -10.8008,  -7.9273, 0.4227, 297.4, false]
];
// --DUWS-COMPOSITION END--

// 需要贴合地形的工事类型
private _tiltTypes = [
    "Land_HBarrierBig_F", "Land_HBarrier_5_F", "Land_BagBunker_Large_F",
    "Land_BagFence_Round_F", "Land_BagFence_Short_F", "Land_BagFence_Long_F",
    "Land_BagFence_Corner_F", "Land_BagFence_End_F", "Land_SandbagBarricade_01_hole_F",
    "Land_Razorwire_F"
];

// ========= 第一步：非武器物体 贴地 =========
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

    // 哨塔保留模拟，其余静态物体禁用模拟
    if (_class != "Land_Cargo_Patrol_V1_F") then {
        _obj enableSimulation false;
    };
    // 部分易碎物品无敌
    if (_class in ["Land_WaterTank_F","Land_WaterBarrel_F","Land_MetalBarrel_F","Land_Pallets_F","Land_ToiletBox_F","Land_Cargo20_military_green_F"]) then {
        _obj allowDamage false;
    };
} forEach _allObjectsData;

sleep 2;

// ========= 第二步：武器物体 海拔还原 =========
private _weaponList = [];
{
    _x params ["_class", "_offsetX", "_offsetY", "_offsetZ", "_dir", "_isWeapon"];
    if (!_isWeapon) then { continue; };

    private _newX = _centerSpawnX + _offsetX;
    private _newY = _centerSpawnY + _offsetY;
    private _newZ = _newCenterZ + _offsetZ;   // 相对海拔直接累加

    private _obj = createVehicle [_class, [_newX, _newY, _newZ], [], 0, "CAN_COLLIDE"];
    [_obj, _gunsKey] call fnc_duws_keep;
    _obj enableSimulation false;
    _obj setPosWorld [_newX, _newY, _newZ];
    // 枪口方向：从中心指向武器位置
    _obj setDir (_centerSpawn getDir [_newX, _newY]);
    _obj setPosWorld [_newX, _newY, _newZ];
    _weaponList pushBack _obj;
} forEach _allObjectsData;

sleep 2;
// ========= 第三步：分配炮手 =========
private _hmgList = nearestObjects [_centerSpawn, ["I_HMG_02_high_F"], 130];
private _mortarList = nearestObjects [_centerSpawn, ["B_Mortar_01_F"], 130];
private _aaList = nearestObjects [_centerSpawn, ["B_static_AA_F"], 130];
private _allWeapons = _hmgList + _mortarList + _aaList;

if (count _allWeapons > 0) then {
    private _unitTypes = [];
    for "_i" from 1 to (count _allWeapons) do { _unitTypes pushBack opfor_SOLDIER_X; };
    private _spawnPos = _centerSpawn findEmptyPosition [0, 30, "I_HMG_02_high_F"];
    if (count _spawnPos == 0) then { _spawnPos = _centerSpawn; };
    private _guardGroup = [_spawnPos, EAST, _unitTypes, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    _guardGroup deleteGroupWhenEmpty true;

    private _idx = 0;
    { (units _guardGroup select _idx) moveInGunner _x; _idx = _idx + 1; } forEach _hmgList;
    { (units _guardGroup select _idx) moveInGunner _x; _idx = _idx + 1; } forEach _mortarList;
    { (units _guardGroup select _idx) moveInGunner _x; _idx = _idx + 1; } forEach _aaList;

    // 炮手上缴后统一激活模拟
    { if (!isNull _x) then { _x enableSimulation true; }; } forEach _allWeapons;
    [_guardGroup, _centerSpawn] call bis_fnc_taskDefend;
};

// ========= 弹药箱（沿用原有布局） =========
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

// 营地灯
private _light1 = createVehicle ["Land_Camping_Light_F", [_centerSpawnX, _centerSpawnY, 0], [], 0, "NONE"];
[_light1, _zoneKey] call fnc_duws_keep;
_light1 setPosATL [_centerSpawnX, _centerSpawnY, 0];
_light1 allowdamage false;
_light1 setdamage 0;