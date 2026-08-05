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
    ["Land_PortableLight_double_F", -0.133667, 12.2012, 1.08401, 228.3, false],
    ["Land_ToiletBox_F", 3.0636, 9.7251, 1.22026, 359.2, false],
    ["Land_Cargo_Patrol_V3_F", 10.5656, -11.48, 4.905196, 314, false],
    ["Land_HBarrier_5_F", 5.31946, 12.1602, 0.74071, 180.6, false],
    ["Land_HBarrier_5_F", 0.659302, 14.1528, 0.74071, 230.8, false],
    ["Land_HBarrier_5_F", 16.7042, 1.99072, 0.74071, 240.9, false],
    ["Land_HBarrier_5_F", 16.8722, -3.16748, 0.74071, 109.9, false],
    ["Land_HBarrier_5_F", -6.86414, -16.875, 0.74071, 21.7, false],
    ["Land_HBarrier_5_F", 17.1827, -11.521, 0.74071, 93.7, false],
    ["Land_HBarrier_5_F", 15.087, -16.1929, 0.74071, 133.9, false],
    ["Land_HBarrier_5_F", -13.4188, -2.86279, 0.74071, 88.7, false],
    ["Land_HBarrier_5_F", -15.3759, 2.41797, 0.74071, 50.8, false],
    ["Land_HBarrier_5_F", -17.368, 6.85547, 0.74071, 88.1, false],
    ["Land_HBarrier_5_F", -16.7489, 12.4028, 0.74071, 108.4, false],
    ["Land_HBarrier_5_F", -2.18835, -16.1597, 0.74071, 324.9, false],
    ["Land_HBarrier_5_F", 7.38, 8.59033, 0.74071, 271.4, false],
    ["Land_HBarrier_5_F", -3.70007, 16.3809, 0.74071, 177.7, false],
    ["Land_HBarrier_5_F", -9.14148, 16.0942, 0.74071, 177.7, false],
    ["Land_HBarrier_5_F", -11.2137, -15.3125, 0.74071, 48.1, false],
    ["Land_HBarrier_5_F", 2.98157, -15.1089, 0.74071, 23.9, false],
    ["Land_HBarrier_5_F", 7.12415, 2.96143, 0.74071, 273.5, false],
    ["Land_PortableLight_double_F", -5.57312, 14.0278, 1.08401, 357, false],
    ["Land_PortableLight_double_F", 14.0031, -14.8691, 1.08401, 311.6, false],
    ["Land_WaterTank_F", 1.08118, 9.07617, 0.68511, 270.4, false],
    ["Land_HBarrier_5_F", 15.6788, 7.23291, 0.74071, 270.6, false],
    ["Land_PaperBox_closed_F", 4.52649, -13.5835, 0.64339, 246.7, false],
    ["Land_Tyres_F", 6.01477, -0.740234, 0.27254, 202.6, false],
    ["Land_ToiletBox_F", 5.58313, 9.74609, 1.22026, 359.2, false],
    ["Land_HBarrier_5_F", -11.3173, -6.84326, 0.74071, 36.6, false],
    ["Land_PortableLight_double_F", -13.7723, 7.04688, 1.08401, 88.6, false],
    ["Land_PaperBox_open_empty_F", 6.6554, -14.1714, 0.60723, 33.2, false],
    ["Land_HBarrier_3_F", -14.2762, -13.4839, 0.79854, 180.6, false],
    ["Land_GarbageBags_F", -2.62585, 13.7583, 0.43383, 158.2, false],
    ["Land_HBarrier_5_F", -13.7782, 15.1094, 0.74071, 153.5, false],
    ["Land_HelipadCircle_F", -6.20593, 3.3501, 0.000199999999999978, 0, false],
    ["Land_RepairDepot_01_green_F", -10.7743, 11.5708, 2.41819, 247.6, false],
    ["FlexibleTank_01_forest_F", -14.0497, 5.4751, 0.51309, 0, false],
    ["FlexibleTank_01_forest_F", -13.8993, 4.33398, 0.51309, 0, false],
    ["I_HMG_02_high_F", 10.3846, -13.3867, 6.08531, 130.6, true],
    ["Land_HBarrier_3_F", 15.7394, -7.44287, 0.79854, 56.7, false],
    ["Land_HBarrier_3_F", 10.9054, -18.2461, 0.79854, 0, false],
    ["Land_HBarrier_3_F", 7.48157, -17.1035, 0.79854, 213.2, false],
    ["I_HMG_02_high_F", -17.3478, -5.70703, 1.67994, 263.456, true],
    ["Land_HBarrier_5_F", -15.8882, -3.57764, 0.74071, 173.368, false],
    ["Land_BagFence_Round_F", -18.4589, -6.03467, 0.41951, 74.6585, false],
    ["I_HMG_02_high_F", 5.57922, 17.4019, 1.67994, 2.18996, true],
    ["Land_HBarrier_5_F", 7.46228, 15.6357, 0.74071, 272.102, false],
    ["Land_BagFence_Round_F", 5.42407, 18.5498, 0.41951, 173.393, false],
    ["CamoNet_BLUFOR_open_F", 2.17114, 14.1138, 1.16804, 178.969, false]
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
private _origin = [_centerSpawnX, _centerSpawnY, _newCenterZ];
{
    // Index 5 is the prefab convention's isWeapon; the ground pass above placed everything else.
    if !(_x select 5) then { continue; };
    _weaponList pushBack ([_x, _origin, "opfor", _zoneKey, "world"] call fnc_static_place);
} forEach _allObjectsData;

sleep 2;
// ─────────── 第三步：分配炮手 ───────────
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