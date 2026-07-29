// Locality: server -- inherited from server/init_zones/fnc_createzone.sqf.
// fnc_modern_Outpost2.sqf (基于 composition 偏移量重构版)
// 原始 Composition 中心: [1523.1245, 4.9986, 2312.0906] (x, z, y)
_centerSpawn = _this select 0;
// Zone construction is campaign property, filed under the zone it stands in so the whole
// composition -- turret, sandbag and camo net alike -- can be released together. A wrecked
// turret leaves its undamaged surroundings behind, and nothing about those props marks them
// as garbage; only the key knows they belonged to something.
private _zoneKey = format ["zone_%1_%2", round (_centerSpawn select 0), round (_centerSpawn select 1)];
_centerSpawnX = _centerSpawn select 0;
_centerSpawnY = _centerSpawn select 1;

private _origCenterZ = 4.9986;
private _newCenterZ = getTerrainHeightASL [_centerSpawnX, _centerSpawnY];
if (_newCenterZ <= 0) then { _newCenterZ = 0; };

// 所有物体: [类名, 中心X偏移, 中心Y偏移, 原Z海拔, 方向(度), 是否武器]
// --DUWS-COMPOSITION BEGIN name="Outpost 2" schema=A--
private _allObjectsData = [
    // === 武器 (外层) ===
    ["I_HMG_02_high_F",   2.9954,   3.1680, 20.8515,  38.3, true],
    ["I_HMG_02_high_F",  -4.7976,  -5.9805, 20.5753, 221.6, true],
    ["B_static_AA_F",     3.3958,  -5.0742, 19.7144,   0.0, true],
    ["I_HMG_02_high_F", -12.6550, -17.2539,  3.0942, 232.0, true],
    ["I_HMG_02_high_F",  15.0422, -15.1953,  3.2772, 145.9, true],
    ["I_HMG_02_high_F",  19.9758,   8.8711,  3.5737,  67.5, true],
    ["I_HMG_02_high_F", -19.3191,   8.2207,  2.9832, 310.3, true],
    ["I_HMG_02_high_F",   0.8879,  21.3711,  3.1796,   8.1, true],
    ["B_Mortar_01_F",    -2.3132,   1.6465, 19.7446,   0.0, true],

    // === 沙袋/铁丝网 (外层) ===
    ["Land_SandbagBarricade_01_hole_F", -14.1472, -19.0254, 1.2896, 221.7, false],
    ["Land_BagFence_Short_F",           -15.0359, -16.8301, 0.4157,  92.9, false],
    ["Land_BagFence_Short_F",           -11.7449, -19.9863, 0.4157, 168.6, false],
    ["Land_SandbagBarricade_01_hole_F",  16.7102, -16.8027, 1.2896, 135.5, false],
    ["Land_BagFence_Short_F",            14.4602, -17.5430, 0.4157,   6.7, false],
    ["Land_BagFence_Short_F",            17.8293, -14.4707, 0.4157,  82.4, false],
    ["Land_SandbagBarricade_01_hole_F",  21.8860,  10.1719, 1.2896,  57.2, false],
    ["Land_BagFence_Short_F",            22.1555,   7.8184, 0.4157, 288.4, false],
    ["Land_BagFence_Short_F",            19.8274,  11.7402, 0.4157,   4.1, false],
    ["Land_SandbagBarricade_01_hole_F", -21.3582,   9.3203, 1.2896, 299.9, false],
    ["Land_BagFence_Short_F",           -19.3894,  10.6367, 0.4157, 171.2, false],
    ["Land_BagFence_Short_F",           -21.8093,   6.7734, 0.4157, 246.9, false],
    ["Land_SandbagBarricade_01_hole_F",   0.7317,  23.6738, 1.2896, 357.8, false],
    ["Land_BagFence_Short_F",             2.8938,  22.7070, 0.4157, 229.1, false],
    ["Land_BagFence_Short_F",            -1.6667,  22.7031, 0.4157, 304.8, false],

    // === 子层 "Camp Bravery" 物体 ===
    ["Land_Cargo_Tower_V1_F",     -0.1511,  -1.3262, 12.8876, 268.9, false],
    ["Land_HBarrierBig_F",        -4.3992, -20.7070,  1.2114, 182.0, false],
    ["Land_HBarrierBig_F",         5.3879, -19.8320,  1.2114, 178.7, false],
    ["Land_HBarrierBig_F",         7.9778,  22.4082,  1.2114, 227.0, false],
    ["Land_HBarrierBig_F",        14.9133,  17.3203,  1.2114, 209.0, false],
    ["Land_HBarrierBig_F",       -13.4382,  16.3770,  1.2114, 158.8, false],
    ["Land_HBarrierBig_F",        -6.3132,  21.2949,  1.2114, 136.0, false],
    ["Land_HBarrierBig_F",       -21.0457,  -1.9629,  1.2114, 246.8, false],
    ["Land_HBarrierBig_F",        -8.3445,   2.6133,  1.2114,  90.0, false],
    ["Land_HBarrierBig_F",        -7.9519,  -5.7129,  1.2114,  89.2, false],
    ["Land_HBarrierBig_F",         7.0481,   3.0918,  1.2114,  91.0, false],
    ["Land_HBarrierBig_F",         7.2727,  -5.3438,  1.2114,  91.0, false],
    ["Land_HBarrierBig_F",        23.6321,   1.7637,  1.2114, 292.3, false],
    ["Land_HBarrierBig_F",        21.9329,  -6.6719,  1.2114, 274.4, false],
    ["Land_HBarrierBig_F",       -18.2800, -10.1191,  1.2114, 260.9, false],
    ["Land_PortableLight_double_F", -3.8816, -5.3789,  9.6742,  89.0, false],
    ["Land_PortableLight_double_F", -1.1707,  2.8984,  5.7267, 271.1, false],
    ["Land_Razorwire_F",           20.4504, -20.4336,  0.7565, 138.5, false],
    ["Land_Razorwire_F",           26.9778,  12.6758,  0.7565,  63.3, false],
    ["Land_Razorwire_F",            0.3254,  29.0039,  0.7565, 354.0, false],
    ["Land_Razorwire_F",          -25.6843,  10.7168,  0.7565, 298.8, false],
    ["Land_Razorwire_F",          -17.2996, -22.4121,  0.7565, 222.6, false],
    ["Land_Razorwire_F",           -3.7664, -26.7402,  0.7565, 177.9, false],
    ["Land_Razorwire_F",            5.8411, -25.4219,  0.7565, 175.7, false],
    ["Land_Razorwire_F",          -25.2625,  -8.2285,  0.7565, 251.5, false],
    ["Land_Razorwire_F",          -13.9597,  23.8633,  0.7565, 142.9, false],
    ["Land_Razorwire_F",           16.1125,  26.0684,  0.7565, 214.4, false],
    ["Land_Razorwire_F",           30.4290,  -3.2207,  0.7565, 279.5, false],
    ["Land_Pallets_stack_F",      -10.0671,  -4.6543,  0.4310, 263.8, false],
    ["Land_PaperBox_closed_F",     -8.1609, -12.9941,  0.6446, 270.0, false],
    ["Land_WaterTank_F",            9.7825,   0.5371,  0.6863,  52.9, false],
    ["Land_WaterTank_F",            9.8411,  -1.4824,  0.6863, 359.5, false],
    ["Land_PaperBox_closed_F",     -9.7449, -11.4609,  0.6446, 300.4, false],
    ["Land_Pallets_stack_F",      -10.8542,  -0.9668,  0.4310, 225.0, false],
    ["Land_ToiletBox_F",          -10.8835,   8.9063,  1.3300, 120.4, false],
    ["Land_HBarrier_5_F",           5.0833,   8.4063,  0.7405, 179.1, false],
    ["Land_HBarrier_5_F",          -6.6492,   7.8203,  0.7419, 178.5, false],
    ["Land_HBarrier_5_F",           5.5676, -10.4727,  0.7419, 178.3, false],
    ["Land_HBarrier_5_F",          -5.8425, -10.8711,  0.7419, 178.9, false]
];
// --DUWS-COMPOSITION END--

// 需要贴合地形的工事类型
private _tiltTypes = [
    "Land_HBarrierBig_F", "Land_HBarrier_5_F", "Land_BagBunker_Large_F",
    "Land_BagFence_Round_F", "Land_BagFence_Short_F", "Land_BagFence_Long_F",
    "Land_BagFence_Corner_F", "Land_BagFence_End_F",
    "Land_SandbagBarricade_01_hole_F", "Land_Razorwire_F"
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

    // 高塔保留模拟，其余静态物体禁用模拟
    if (_class != "Land_Cargo_Tower_V1_F") then {
        _obj enableSimulationGlobal false;
    };
    // 部分物品无敌
    if (_class in ["Land_WaterTank_F","Land_Pallets_stack_F","Land_PaperBox_closed_F"]) then {
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
// ========= 第三步：分配炮手 =========
private _hmgList = nearestObjects [_centerSpawn, ["I_HMG_02_high_F"], 150];
private _mortarList = nearestObjects [_centerSpawn, ["B_Mortar_01_F"], 150];
private _aaList = nearestObjects [_centerSpawn, ["B_static_AA_F"], 150];
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

    { if (!isNull _x) then { _x enableSimulationGlobal true; }; } forEach _allWeapons;
    [_guardGroup, _centerSpawn] call bis_fnc_taskDefend;
};

// 营地灯
private _light1 = createVehicle ["Land_Camping_Light_F", [_centerSpawnX, _centerSpawnY, 0], [], 0, "NONE"];
[_light1, _zoneKey] call fnc_duws_keep;
_light1 setPosATL [_centerSpawnX, _centerSpawnY, 0];
_light1 allowdamage false;
_light1 setdamage 0;