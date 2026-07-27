// Locality: server -- inherited from server/init_zones/fnc_createzone.sqf.
// fnc_modern_FieldHospital.sqf (基于 composition 偏移量重构版)
_centerSpawn = _this select 0;
// Zone construction is campaign property, filed under the zone it stands in so the whole
// composition -- turret, sandbag and camo net alike -- can be released together. A wrecked
// turret leaves its undamaged surroundings behind, and nothing about those props marks them
// as garbage; only the key knows they belonged to something.
private _zoneKey = format ["zone_%1_%2", round (_centerSpawn select 0), round (_centerSpawn select 1)];
_centerSpawnX = _centerSpawn select 0;
_centerSpawnY = _centerSpawn select 1;

private _origCenterZ = 5.0;
private _newCenterZ = getTerrainHeightASL [_centerSpawnX, _centerSpawnY];
if (_newCenterZ <= 0) then { _newCenterZ = 0; };

// 保留物理模拟的物体（如载具、可互动物体等）
private _keepSimulation = [
    "C_Offroad_01_F",
    "B_Slingload_01_Medevac_F",
    "Land_Medevac_house_V1_F",
    "Land_Medevac_HQ_V1_F"
];

// 所有物体 [类名, X偏移, Y偏移, Z海拔, 方向度, 是否武器]
// --DUWS-COMPOSITION BEGIN name="Field Hospital" schema=A--
private _allObjectsData = [
    // ===== 子层 "Camp Defiance" (36个) =====
    ["Land_HBarrier_5_F",           -7.1416,  17.8892, 0.7405,   0.0, false],
    ["Land_HBarrier_5_F",            9.6323, -11.6357, 0.7405,   2.1, false],
    ["Land_HBarrier_5_F",           15.6372,  -7.3691, 0.7405, 307.3, false],
    ["Land_HBarrier_5_F",          -12.7100,  17.8989, 0.7405,   0.0, false],
    ["Land_HBarrier_5_F",          -12.3638, -11.1143, 0.7405,   2.1, false],
    ["Land_HBarrier_5_F",            6.0835, -13.5000, 0.7405, 270.6, false],
    ["Land_HBarrier_5_F",            5.9878, -19.1602, 0.7405, 270.6, false],
    ["Land_HBarrier_5_F",           -9.0337, -13.2227, 0.7405, 270.6, false],
    ["Land_HBarrier_5_F",           -9.0728, -18.8770, 0.7405, 270.6, false],
    ["Land_HBarrier_5_F",           -1.4854,  17.8423, 0.7405,   0.0, false],
    ["Land_HBarrier_5_F",           17.1450,  -2.7715, 0.7405, 269.8, false],
    ["Land_HBarrier_5_F",          -17.6875,   3.4185, 0.7405, 269.8, false],
    ["Land_HBarrier_5_F",          -17.9316,   9.1636, 0.7405, 269.8, false],
    ["Land_HBarrier_5_F",            0.6235,   8.8125, 0.7405, 269.8, false],
    ["Land_HBarrier_5_F",            0.5864,  14.3516, 0.7405, 269.8, false],
    ["Land_HBarrier_3_F",           12.9722, -10.7202, 0.7983, 130.0, false],
    ["Land_HBarrier_5_F",          -16.4438,  -7.6958, 0.7405, 238.8, false],
    ["Land_HBarrier_5_F",          -16.8589,  14.8750, 0.7405, 305.8, false],
    ["Land_HBarrier_5_F",            2.4136, -21.1631, 0.7405,   2.1, false],
    ["Land_HBarrier_5_F",            2.7026, -11.3135, 0.7405,   2.1, false],
    ["Land_HBarrier_5_F",            0.6792,  -7.6699, 0.7405, 270.1, false],
    ["Land_HBarrier_5_F",          -17.7148,  -2.0444, 0.7405, 269.8, false],
    ["Land_GarbageBags_F",           3.9810,  -8.4639, 0.4336, 301.6, false],
    ["Land_HBarrier_3_F",            0.4399, -18.6670, 0.7983,  92.5, false],
    ["Land_HBarrier_5_F",           17.1450,   8.3633, 0.7405, 269.8, false],
    ["Land_HBarrier_5_F",           17.1528,  13.9336, 0.7405, 269.8, false],
    ["Land_HBarrier_5_F",           17.1177,   2.9043, 0.7405, 269.8, false],
    ["Land_HBarrier_5_F",            9.6211,  17.6216, 0.7405, 180.7, false],
    ["Land_HBarrier_5_F",            4.0684,  17.7544, 0.7405, 180.7, false],
    ["Land_HBarrier_5_F",           15.0566,  17.4907, 0.7405, 180.7, false],
    ["Land_JunkPile_F",            -13.6982,  -4.3535, 0.2747, 270.8, false],
    ["Land_Pallets_stack_F",       -12.2007,  -2.7388, 0.4296,  44.6, false],
    ["Land_GarbageBarrel_01_F",     -5.5024,   1.4419, 0.6138, 271.8, false],
    ["Land_Garbage_square5_F",       0.4150, -14.4429, 0.0394, 271.8, false],
    ["Land_CratesShabby_F",        -12.4106,  -1.2290, 0.7598, 161.9, false],
    ["Land_Loudspeakers_F",         -0.3633,   5.9341, 3.5032, 271.8, false],

    // ===== 外层物体 =====
    ["Land_GarbageHeap_03_F",       15.4849,  11.8174, 0.5271, 269.5, false],
    ["MedicalGarbage_01_5x5_v1_F",  14.8599,   8.7910, 0.0345,   0.0, false],
    ["MedicalGarbage_01_5x5_v1_F",   5.7739,   8.8716, 0.0345,   0.0, false],
    ["MedicalGarbage_01_5x5_v1_F",  13.2690,  -0.1372, 0.0345, 100.1, false],
    ["MedicalGarbage_01_5x5_v1_F",  -0.1826,  -4.8872, 0.0345, 173.5, false],
    ["MedicalGarbage_01_5x5_v1_F",  -9.8877,   1.2275, 0.0345,   0.0, false],
    ["MedicalGarbage_01_5x5_v1_F",  -6.4658,   0.0679, 0.0345, 173.5, false],
    ["B_Slingload_01_Medevac_F",    14.7212,   2.7690, 1.3591,   0.0, false],
    ["Land_PortableCabinet_01_medical_F", 1.9746, 6.6299, 0.4179, 187.5, false],
    ["Land_Medevac_house_V1_F",      5.5991,  12.0322, 0.7000,   0.0, false],
    ["Land_Medevac_HQ_V1_F",        -9.6787,   7.0381, 3.8693, 270.3, false],
    ["I_HMG_02_high_F",            -12.2876,   4.1353, 5.6637, 190.4, true],
    ["I_HMG_02_high_F",            -10.8438,  13.5112, 5.7147,   0.0, true],
    ["I_Mortar_01_F",              -11.2017,   7.6265, 4.9096,   0.0, true],
    ["B_static_AA_F",                0.6030,   3.5054, 1.6752,   0.0, true],
    ["C_Offroad_01_F",               3.1694, -16.2651, 1.6115,   0.0, false],
    ["Land_HelipadRescue_F",         6.8320,   0.2212, 0.0,      0.0, false],
    ["Land_BagFence_Round_F",        0.8296, -24.9683, 0.4193,   0.0, false],
    ["I_HMG_02_high_F",              0.5581, -23.5117, 2.2937, 176.3, true]
];
// --DUWS-COMPOSITION END--

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
    // Anything that can drive itself away is left out of the composition: a base exclusion zone
    // is how a player keeps a vehicle now, so a zone quadbike abandoned at a captured outpost
    // clears like anything else. Tested on the object rather than the class because a slung
    // cargo container is cargo, not transport, and must stay tagged -- canMove tells them apart
    // without depending on which config branch each one hangs off.
    if !(canMove _obj) then { [_obj, _zoneKey] call fnc_duws_keep };
    _obj setPosATL [_newX, _newY, 0];

    // 工事倾斜
    if (_class in _tiltTypes) then {
        _obj setVectorUp (surfaceNormal [_newX, _newY]);
    };
    _obj setDir _dir;

    // 保留模拟的不禁用，其余禁用
    if !(_class in _keepSimulation) then {
        _obj enableSimulation false;
    };

    // 易碎品无敌
    if (_class in ["Land_Pallets_stack_F","Land_GarbageBarrel_01_F","Land_CratesShabby_F","Land_PortableCabinet_01_medical_F"]) then {
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
    [_obj, _zoneKey] call fnc_duws_keep;
    _obj enableSimulation false;
    _obj setPosWorld [_newX, _newY, _newZ];
    _obj setDir (_centerSpawn getDir [_newX, _newY]);
    _obj setPosWorld [_newX, _newY, _newZ];
    _weaponList pushBack _obj;
} forEach _allObjectsData;

sleep 2;
// ── 第三步：分配炮手 ──
private _hmgList = nearestObjects [_centerSpawn, ["I_HMG_02_high_F"], 150];
private _mortarList = nearestObjects [_centerSpawn, ["I_Mortar_01_F"], 150];
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