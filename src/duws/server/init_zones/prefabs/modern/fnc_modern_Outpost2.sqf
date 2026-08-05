// Locality: server -- inherited from server/init_zones/fnc_createzone.sqf.
// 原始 Composition 中心: [1523.1245, 4.9986, 2312.0906] (x, z, y)
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

// 所有物体: [类名, 中心X偏移, 中心Y偏移, 原Z海拔, 方向(度), 是否武器]
// --DUWS-COMPOSITION BEGIN name="Outpost 2" schema=A--
private _allObjectsData = [
    // === 武器 (外层) ===
    ["I_HMG_02_high_F", 2.99536, 3.16797, 19.5704, 38.3, true],
    ["I_HMG_02_high_F", -5.22302, -5.83496, 19.5704, 221.6, true],
    ["I_HMG_02_high_F", -12.655, -17.2539, 1.68094, 232, true],
    ["I_HMG_02_high_F", 15.0422, -15.1953, 1.68094, 145.9, true],
    ["I_HMG_02_high_F", 19.9758, 8.87109, 1.68094, 67.5, true],
    ["I_HMG_02_high_F", -19.3191, 8.2207, 1.68094, 310.3, true],
    ["I_HMG_02_high_F", 0.887939, 21.3711, 1.68094, 8.1, true],
    ["Land_SandbagBarricade_01_hole_F", -14.1472, -19.0254, 1.28942, 221.7, false],
    ["Land_BagFence_Short_F", -15.0359, -16.8301, 0.41548, 92.9, false],
    ["Land_BagFence_Short_F", -11.7449, -19.9863, 0.41548, 168.6, false],
    ["Land_SandbagBarricade_01_hole_F", 16.7102, -16.8027, 1.28942, 135.5, false],
    ["Land_BagFence_Short_F", 14.4602, -17.543, 0.41548, 6.7, false],
    ["Land_BagFence_Short_F", 17.8293, -14.4707, 0.41548, 82.4, false],
    ["Land_SandbagBarricade_01_hole_F", 21.886, 10.1719, 1.28942, 57.2, false],
    ["Land_BagFence_Short_F", 22.1555, 7.81836, 0.41548, 288.4, false],
    ["Land_BagFence_Short_F", 19.8274, 11.7402, 0.41548, 4.1, false],
    ["Land_SandbagBarricade_01_hole_F", -21.3582, 9.32031, 1.28942, 299.9, false],
    ["Land_BagFence_Short_F", -19.3894, 10.6367, 0.41548, 171.2, false],
    ["Land_BagFence_Short_F", -21.8093, 6.77344, 0.41548, 246.9, false],
    ["Land_SandbagBarricade_01_hole_F", 0.731689, 23.6738, 1.28942, 357.8, false],
    ["Land_BagFence_Short_F", 2.8938, 22.707, 0.41548, 229.1, false],
    ["Land_BagFence_Short_F", -1.66675, 22.7031, 0.41548, 304.8, false],
    ["Land_Cargo_Tower_V1_F", -0.151123, -1.32617, 12.8874, 268.9, false],
    ["Land_HBarrierBig_F", -4.39917, -20.707, 1.2112, 182, false],
    ["Land_HBarrierBig_F", 4.41211, -20.6343, 1.2112, 178.7, false],
    ["Land_HBarrierBig_F", 7.97778, 22.4082, 1.2112, 227, false],
    ["Land_HBarrierBig_F", 14.9133, 17.3203, 1.2112, 209, false],
    ["Land_HBarrierBig_F", -13.4382, 16.377, 1.2112, 158.8, false],
    ["Land_HBarrierBig_F", -6.31323, 21.2949, 1.2112, 136, false],
    ["Land_HBarrierBig_F", -21.0457, -1.96289, 1.2112, 246.8, false],
    ["Land_HBarrierBig_F", -8.34448, 2.61328, 1.2112, 90, false],
    ["Land_HBarrierBig_F", -7.9519, -5.71289, 1.2112, 89.2, false],
    ["Land_HBarrierBig_F", 7.0481, 3.0918, 1.2112, 91, false],
    ["Land_HBarrierBig_F", 7.27271, -5.34375, 1.2112, 91, false],
    ["Land_HBarrierBig_F", 23.6321, 1.76367, 1.2112, 292.3, false],
    ["Land_HBarrierBig_F", 21.9329, -6.67188, 1.2112, 274.4, false],
    ["Land_HBarrierBig_F", -18.28, -10.1191, 1.2112, 260.9, false],
    ["Land_PortableLight_double_F", -3.88159, -5.37891, 1.08501, 89, false],
    ["Land_PortableLight_double_F", -1.17065, 2.89844, 1.08501, 271.1, false],
    ["Land_Razorwire_F", 20.4504, -20.4336, 0.75626, 138.5, false],
    ["Land_Razorwire_F", 26.9778, 12.6758, 0.75626, 63.3, false],
    ["Land_Razorwire_F", 0.325439, 29.0039, 0.75626, 354, false],
    ["Land_Razorwire_F", -25.6843, 10.7168, 0.75626, 298.8, false],
    ["Land_Razorwire_F", -17.2996, -22.4121, 0.75626, 222.6, false],
    ["Land_Razorwire_F", -3.76636, -26.7402, 0.75626, 177.9, false],
    ["Land_Razorwire_F", 5.84106, -25.4219, 0.75626, 175.7, false],
    ["Land_Razorwire_F", -25.2625, -8.22852, 0.75626, 251.5, false],
    ["Land_Razorwire_F", -13.9597, 23.8633, 0.75626, 142.9, false],
    ["Land_Razorwire_F", 16.1125, 26.0684, 0.75626, 214.4, false],
    ["Land_Razorwire_F", 30.429, -3.2207, 0.75626, 279.5, false],
    ["Land_Pallets_stack_F", -10.0671, -4.6543, 0.43076, 263.8, false],
    ["Land_PaperBox_closed_F", -8.16089, -12.9941, 0.64439, 270, false],
    ["Land_WaterTank_F", 9.78247, 0.537109, 0.68611, 52.9, false],
    ["Land_WaterTank_F", 9.84106, -1.48242, 0.68611, 359.5, false],
    ["Land_PaperBox_closed_F", -9.74487, -11.4609, 0.64439, 300.4, false],
    ["Land_Pallets_stack_F", -10.8542, -0.966797, 0.43076, 225, false],
    ["Land_ToiletBox_F", -10.8835, 8.90625, 1.22126, 120.4, false],
    ["Land_HBarrier_5_F", 5.08325, 8.40625, 0.74171, 179.1, false],
    ["Land_HBarrier_5_F", -6.64917, 7.82031, 0.74171, 178.5, false],
    ["Land_HBarrier_5_F", 5.56763, -10.4727, 0.74171, 178.3, false],
    ["Land_HBarrier_5_F", -5.84253, -10.8711, 0.74171, 178.9, false],
    ["I_HMG_02_high_F", -3.87378, 3.22119, 19.5704, 308.44, true],
    ["I_HMG_02_high_F", 4.98267, -5.82471, 19.4729, 112.057, true],
    ["Land_Cargo_Patrol_V1_F", -1.53857, -19.4585, 4.906196, 358.78, false],
    ["I_GMG_01_high_F", 0.40271, -20.7666, 6.00537, 176.444, true]
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
    private _spawnPos = _centerSpawn findEmptyPosition [0, 30, "I_HMG_02_high_F"];
    if (count _spawnPos == 0) then { _spawnPos = _centerSpawn; };
    private _guardGroup = [_spawnPos, EAST, _unitTypes, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    _guardGroup deleteGroupWhenEmpty true;

    { ((units _guardGroup) param [_forEachIndex, objNull]) moveInGunner _x } forEach _allWeapons;

    { if (!isNull _x) then { _x enableSimulationGlobal true; }; } forEach _allWeapons;
    [_guardGroup, _centerSpawn] call bis_fnc_taskDefend;
};

// 营地灯
private _light1 = createVehicle ["Land_Camping_Light_F", [_centerSpawnX, _centerSpawnY, 0], [], 0, "NONE"];
[_light1, _zoneKey] call fnc_duws_keep;
_light1 setPosATL [_centerSpawnX, _centerSpawnY, 0];
_light1 allowdamage false;
_light1 setdamage 0;