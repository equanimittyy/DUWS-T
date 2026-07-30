// Locality: server -- inherited from server/init_zones/fnc_createzone.sqf.
// 原始 Composition 中心: [1594.1437, 4.375, 2276.9558] (x, z, y)
_centerSpawn = _this select 0;
// Zone construction is campaign property, filed under the zone it stands in so the whole
// composition -- turret, sandbag and camo net alike -- can be released together. A wrecked
// turret leaves its undamaged surroundings behind, and nothing about those props marks them
// as garbage; only the key knows they belonged to something.
private _zoneKey = format ["zone_%1_%2", round (_centerSpawn select 0), round (_centerSpawn select 1)];
_centerSpawnX = _centerSpawn select 0;
_centerSpawnY = _centerSpawn select 1;

private _origCenterZ = 4.375;
private _newCenterZ = getTerrainHeightASL [_centerSpawnX, _centerSpawnY];
if (_newCenterZ <= 0) then { _newCenterZ = 0; };

// 需要保留模拟的物体（如可互动物体）
private _keepSimulation = [];

// 所有物体: [类名, X偏移, Y偏移, Z海拔, 方向度数, 是否为武器]
// --DUWS-COMPOSITION BEGIN name="Storage Bunker" schema=A--
private _allObjectsData = [
    // === 子层 "Improvised Bunker 05" (29个物体) ===
    ["Land_HouseWallRuin_Corner_01_F",  0.2312,  -4.9382, 1.4370,   0.0, false],
    ["Land_HouseWallRuin_Door_01_F",   -6.0481,  -0.1902, 2.5046,  90.0, false],
    ["Land_HouseWallRuin_Corner_02_F",  0.2019,   5.0598, 1.6564, 180.0, false],
    ["Land_DirtPatch_05_F",             2.3269,   5.4348, 0.6250,   0.0, false],
    ["Land_DirtPatch_05_F",             1.2019,  -5.6902, 1.3515,   0.0, false],
    ["Land_DirtPatch_05_F",            -4.4231,  -1.8152, 0.6250,   0.0, false],
    ["CraterLong_02_small_F",           4.2019,  -5.5652, 0.6700,   0.0, false],
    ["Land_Barricade_01_10m_F",         3.5769,   0.4348, 0.0,    270.0, false],
    ["Land_BagFence_Long_F",            3.8269,   1.1848, 1.0443,  90.0, false],
    ["Land_BagFence_Short_F",           3.8269,  -1.1902, 1.0393,  90.0, false],
    ["VirtualReammoBox_small_F",        2.6941,   1.5813, 0.8350, 109.3, false],
    ["Land_Ammobox_rounds_F",           1.8269,   1.4348, 0.7304, 158.9, false],
    ["Land_WoodenCrate_01_F",           2.3269,   3.1848, 0.9549, 279.7, false],
    ["Land_WoodenCrate_01_stack_x3_F",  2.3074,   6.1926, 1.3329, 258.5, false],
    ["Land_Plank_01_4m_F",              2.3269,   4.4348, 1.2937,   0.0, false],
    ["VirtualReammoBox_small_F",        1.8406,   2.2297, 0.8350,  89.8, false],
    ["Land_Ammobox_rounds_F",           2.2019,   3.3098, 1.4574, 327.6, false],
    ["Land_Ammobox_rounds_F",           2.2019,   2.9348, 1.4568, 177.8, false],
    ["Land_SlumWall_01_s_4m_F",         3.3269,  -0.0652, 0.8790, 270.0, false],
    ["Land_ChairWood_F",                0.8347,   6.7083, 0.6243,  24.6, false],
    ["Land_Plank_01_4m_F",              1.4011,  -5.8777, 0.6687, 240.9, false],
    ["VirtualReammoBox_small_F",        0.1746,  -6.5613, 0.9408,  75.9, false],
    ["Land_FoodContainer_01_F",         2.2507,   3.8528, 1.5805, 157.1, false],
    ["Land_EmergencyBlanket_01_discarded_F", 1.3601, -5.8171, 0.7728, 231.8, false],
    ["Land_EmergencyBlanket_01_stack_F",0.1257,  -6.5007, 1.3604, 144.7, false],
    ["Land_TinContainer_F",             2.1316,   3.6321, 1.4525,  34.7, false],
    ["Land_BagFence_Long_F",           -4.3098,   7.8098, 1.0443, 180.0, false],
    ["Land_Garbage_line_F",            -0.1321,  -6.0515, 0.6752, 240.3, false],
    ["Land_Pallets_stack_F",           -4.7922,  -4.0300, 1.0546,   0.0, false],

    // === 外层物体 ===
    ["CamoNet_BLUFOR_open_F",          -1.1750,   0.8430, 1.7928,  89.3, false],
    ["I_HMG_01_high_F",                 1.9109,  -0.6707, 3.0873,  89.3, true],
    ["I_GMG_01_high_F",                -4.1204,   6.1321, 3.3724,   0.0, true],
    ["Land_BagFence_Long_F",           -7.8333,  -0.2996, 1.0443, 271.6, false],
    ["B_HMG_01_high_F",                -5.6497,  -0.0398, 3.2307, 271.0, true],
    ["Box_NATO_AmmoVeh_F",             -0.9192,   6.4172, 1.4148,   0.0, false],
    ["B_Mortar_01_F",                  -5.1575,  -8.0242, 2.2792, 211.9, true],
    ["Land_BagFence_Round_F",          -6.0637,  -9.5222, 1.0443,  25.2, false]
];
// --DUWS-COMPOSITION END--

// 需要贴合地形的工事类型
private _tiltTypes = [
    "Land_HouseWallRuin_Corner_01_F", "Land_HouseWallRuin_Corner_02_F",
    "Land_HouseWallRuin_Door_01_F", "Land_Barricade_01_10m_F",
    "Land_SlumWall_01_s_4m_F",
    "Land_BagFence_Long_F", "Land_BagFence_Short_F", "Land_BagFence_Round_F"
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

    // 工事倾斜
    if (_class in _tiltTypes) then {
        _obj setVectorUp (surfaceNormal [_newX, _newY]);
    };
    _obj setDir _dir;

    // 禁用模拟（除了保留列表里的）
    if !(_class in _keepSimulation) then {
        _obj enableSimulationGlobal false;
    };
    // 全部设为无敌
    _obj allowDamage false;
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
private _hmgList = nearestObjects [_centerSpawn, ["I_HMG_01_high_F", "B_HMG_01_high_F"], 80];
private _gmgList = nearestObjects [_centerSpawn, ["I_GMG_01_high_F"], 80];
private _mortarList = nearestObjects [_centerSpawn, ["B_Mortar_01_F"], 80];
private _allWeapons = _hmgList + _gmgList + _mortarList;

if (count _allWeapons > 0) then {
    private _unitTypes = [];
    for "_i" from 1 to (count _allWeapons) do { _unitTypes pushBack opfor_SOLDIER_X; };
    private _spawnPos = _centerSpawn findEmptyPosition [0, 30];
    if (count _spawnPos == 0) then { _spawnPos = _centerSpawn; };
    private _guardGroup = [_spawnPos, EAST, _unitTypes, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    _guardGroup deleteGroupWhenEmpty true;

    private _idx = 0;
    { (units _guardGroup select _idx) moveInGunner _x; _idx = _idx + 1; } forEach _hmgList;
    { (units _guardGroup select _idx) moveInGunner _x; _idx = _idx + 1; } forEach _gmgList;
    { (units _guardGroup select _idx) moveInGunner _x; _idx = _idx + 1; } forEach _mortarList;

    { if (!isNull _x) then { _x enableSimulationGlobal true; }; } forEach _allWeapons;
    [_guardGroup, _centerSpawn] call bis_fnc_taskDefend;
};

// 营地灯（备用）
private _light1 = createVehicle ["Land_Camping_Light_F", [_centerSpawnX, _centerSpawnY, 0], [], 0, "NONE"];
[_light1, _zoneKey] call fnc_duws_keep;
_light1 setPosATL [_centerSpawnX, _centerSpawnY, 0];
_light1 allowdamage false;
_light1 setdamage 0;