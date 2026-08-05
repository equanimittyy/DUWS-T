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

private _newCenterZ = getTerrainHeightASL [_centerSpawnX, _centerSpawnY];
if (_newCenterZ <= 0) then { _newCenterZ = 0; };

// 需要保留模拟的物体（如可互动物体）
private _keepSimulation = [];

// 所有物体: [类名, X偏移, Y偏移, Z海拔, 方向度数, 是否为武器]
// --DUWS-COMPOSITION BEGIN name="Storage Bunker" schema=A--
private _allObjectsData = [
    // === 子层 "Improvised Bunker 05" (29个物体) ===
    ["Land_HouseWallRuin_Corner_01_F", 0.231201, -4.93799, 1.66813, 0, false],
    ["Land_HouseWallRuin_Door_01_F", -6.0481, -0.19043, 1.70266, 90, false],
    ["Land_HouseWallRuin_Corner_02_F", 0.201904, 5.05957, 1.65661, 180, false],
    ["Land_DirtPatch_05_F", 2.3269, 5.43457, 0.6252, 0, false],
    ["Land_DirtPatch_05_F", 1.2019, -5.69043, 0.6252, 0, false],
    ["Land_DirtPatch_05_F", -4.4231, -1.81543, 0.6252, 0, false],
    ["CraterLong_02_small_F", 4.2019, -5.56543, 0.670160000000001, 0, false],
    ["Land_Barricade_01_10m_F", 3.5769, 0.43457, 0.6252, 270, false],
    ["Land_BagFence_Long_F", 3.8269, 1.18457, 1.04451, 90, false],
    ["Land_BagFence_Short_F", 3.8269, -1.19043, 1.03948, 90, false],
    ["VirtualReammoBox_small_F", 2.69409, 1.58154, 0.83524, 109.3, false],
    ["Land_Ammobox_rounds_F", 1.8269, 1.43457, 0.73056, 158.9, false],
    ["Land_WoodenCrate_01_F", 2.3269, 3.18457, 0.97338, 279.7, false],
    ["Land_WoodenCrate_01_stack_x3_F", 2.30737, 6.19238, 1.33307, 258.5, false],
    ["Land_Plank_01_4m_F", 2.3269, 4.43457, 0.66891, 0, false],
    ["VirtualReammoBox_small_F", 1.84058, 2.22949, 0.83524, 89.8, false],
    ["Land_Ammobox_rounds_F", 2.2019, 3.30957, 0.73056, 327.6, false],
    ["Land_Ammobox_rounds_F", 2.2019, 2.93457, 0.73056, 177.8, false],
    ["Land_SlumWall_01_s_4m_F", 3.3269, -0.0654297, 1.00422, 270, false],
    ["Land_ChairWood_F", 0.841064, 6.65771, 0.62454, 24.6, false],
    ["Land_Plank_01_4m_F", 1.40112, -5.87793, 0.66891, 240.9, false],
    ["VirtualReammoBox_small_F", 0.174561, -6.56152, 0.83524, 75.9, false],
    ["Land_FoodContainer_01_F", 2.25073, 3.85303, 0.853, 157.1, false],
    ["Land_EmergencyBlanket_01_discarded_F", 1.36011, -5.81689, 0.67034, 231.8, false],
    ["Land_EmergencyBlanket_01_stack_F", 0.125732, -6.50049, 0.82879, 144.7, false],
    ["Land_TinContainer_F", 2.13159, 3.63232, 0.72457, 34.7, false],
    ["Land_BagFence_Long_F", -4.30981, 7.80957, 1.04451, 180, false],
    ["Land_Garbage_line_F", -0.13208, -6.05127, 0.67535, 240.3, false],
    ["Land_Pallets_stack_F", -4.79224, -4.02979, 1.05476, 0, false],
    ["CamoNet_BLUFOR_open_F", -1.17505, 0.842773, 1.79304, 89.3, false],
    ["I_HMG_01_high_F", -4.46375, -6.54639, 2.273, 215.244, true],
    ["I_GMG_01_high_F", -4.12036, 6.13232, 2.28533, 0, true],
    ["Land_BagFence_Long_F", -6.67151, -0.193848, 1.04451, 271.6, false],
    ["Box_NATO_AmmoVeh_F", -0.919189, 6.41699, 1.415, 0, false],
    ["Land_BagFence_Round_F", -5.07495, -7.72119, 1.04451, 25.2, false],
    ["I_HMG_01_high_F", -5.13623, -0.0395508, 2.28549, 272.861, true]
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
private _origin = [_centerSpawnX, _centerSpawnY, _newCenterZ];
{
    // Index 5 is the prefab convention's isWeapon; the ground pass above placed everything else.
    if !(_x select 5) then { continue; };
    _weaponList pushBack ([_x, _origin, "opfor", _zoneKey, "world"] call fnc_static_place);
} forEach _allObjectsData;

sleep 2;
// ========= 第三步：分配炮手 =========
// The weapons this composition just placed, taken from the loop that placed them. Searching for them
// again by classname and radius is what left guns frozen: the thaw below is the only thing that
// undoes the placement freeze, and a class the search did not name never reached it -- placed, stowed
// and redeployed unsimulated, unable to fall or settle, for the rest of the campaign. A radius also
// claims a neighbouring composition's guns.
private _allWeapons = _weaponList select {!isNull _x};

if (count _allWeapons > 0) then {
    private _unitTypes = [];
    for "_i" from 1 to (count _allWeapons) do { _unitTypes pushBack opfor_SOLDIER_X; };
    private _spawnPos = _centerSpawn findEmptyPosition [0, 30];
    if (count _spawnPos == 0) then { _spawnPos = _centerSpawn; };
    private _guardGroup = [_spawnPos, EAST, _unitTypes, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    _guardGroup deleteGroupWhenEmpty true;

    { ((units _guardGroup) param [_forEachIndex, objNull]) moveInGunner _x } forEach _allWeapons;

    { if (!isNull _x) then { _x enableSimulationGlobal true; }; } forEach _allWeapons;
    [_guardGroup, _centerSpawn] call bis_fnc_taskDefend;
};

// 营地灯（备用）
private _light1 = createVehicle ["Land_Camping_Light_F", [_centerSpawnX, _centerSpawnY, 0], [], 0, "NONE"];
[_light1, _zoneKey] call fnc_duws_keep;
_light1 setPosATL [_centerSpawnX, _centerSpawnY, 0];
_light1 allowdamage false;
_light1 setdamage 0;