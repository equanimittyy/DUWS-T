// Locality: server -- inherited from server/init_zones/fnc_createzone.sqf.
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

// Objects that must keep simulation: interactable or destructible.
private _keepSimulation = [
    "Land_RepairDepot_01_green_F",
    "FlexibleTank_01_forest_F"
];

// Each row: [class, offsetX, offsetY, offsetZ, dir, isWeapon].
// --DUWS-COMPOSITION BEGIN name="Vehicle Refit Station" schema=A--
private _allObjectsData = [
    ["Land_PortableLight_double_F", -0.133667, 12.2012, 1.08451, 228.3, false],
    ["Land_ToiletBox_F", 3.0636, 9.7251, 1.22076, 359.2, false],
    ["Land_Cargo_Patrol_V3_F", 10.5656, -11.48, 4.9057, 314, false],
    ["Land_HBarrier_5_F", 5.31946, 12.1602, 0.74121, 180.6, false],
    ["Land_HBarrier_5_F", 0.659302, 14.1528, 0.74121, 230.8, false],
    ["Land_HBarrier_5_F", 16.7042, 1.99072, 0.74121, 240.9, false],
    ["Land_HBarrier_5_F", 16.8722, -3.16748, 0.74121, 109.9, false],
    ["Land_HBarrier_5_F", -6.86414, -16.875, 0.74121, 21.7, false],
    ["Land_HBarrier_5_F", 16.7524, -11.2852, 0.74121, 93.7, false],
    ["Land_HBarrier_5_F", 14.5134, -15.855, 0.74121, 133.9, false],
    ["Land_HBarrier_5_F", -13.4188, -2.86279, 0.74121, 88.7, false],
    ["Land_HBarrier_5_F", -15.3759, 2.41797, 0.74121, 50.8, false],
    ["Land_HBarrier_5_F", -17.368, 6.85547, 0.74121, 88.1, false],
    ["Land_HBarrier_5_F", -16.9014, 12.3296, 0.74121, 101.467, false],
    ["Land_HBarrier_5_F", -2.18835, -16.1597, 0.74121, 324.9, false],
    ["Land_HBarrier_5_F", 7.38, 8.59033, 0.74121, 271.4, false],
    ["Land_HBarrier_5_F", -3.70007, 16.3809, 0.74121, 177.7, false],
    ["Land_HBarrier_5_F", -9.14148, 16.0942, 0.74121, 177.7, false],
    ["Land_HBarrier_5_F", -11.9832, -14.8037, 0.74121, 22.4568, false],
    ["Land_HBarrier_5_F", 2.98157, -15.1089, 0.74121, 23.9, false],
    ["Land_HBarrier_5_F", 7.12415, 2.96143, 0.74121, 273.5, false],
    ["Land_PortableLight_double_F", -5.57312, 14.0278, 1.08451, 357, false],
    ["Land_PortableLight_double_F", 13.7593, -14.5269, 1.08451, 311.6, false],
    ["Land_WaterTank_F", 1.08118, 9.07617, 0.685612, 270.4, false],
    ["Land_HBarrier_5_F", 15.6788, 7.23291, 0.74121, 270.6, false],
    ["Land_PaperBox_closed_F", 4.52649, -13.5835, 0.643893, 246.7, false],
    ["Land_Tyres_F", 6.01477, -0.740234, 0.27304, 202.6, false],
    ["Land_ToiletBox_F", 5.58313, 9.74609, 1.22076, 359.2, false],
    ["Land_HBarrier_5_F", -11.3173, -6.84326, 0.74121, 36.6, false],
    ["Land_PortableLight_double_F", -13.7723, 7.04688, 1.08451, 88.6, false],
    ["Land_PaperBox_open_empty_F", 6.6554, -14.1714, 0.60773, 33.2, false],
    ["Land_HBarrier_3_F", -16.2322, -13.7461, 0.799037, 180.6, false],
    ["Land_GarbageBags_F", -2.62585, 13.7583, 0.434333, 158.2, false],
    ["Land_HBarrier_5_F", -13.9342, 15.4092, 0.74121, 342.878, false],
    ["Land_HelipadCircle_F", -6.20593, 3.3501, 0.000695229, 0, false],
    ["Land_RepairDepot_01_green_F", -10.7743, 11.5708, 2.41869, 247.6, false],
    ["FlexibleTank_01_forest_F", -14.0497, 5.4751, 0.513587, 0, false],
    ["FlexibleTank_01_forest_F", -13.8993, 4.33398, 0.513587, 0, false],
    ["I_HMG_02_high_F", 10.3846, -13.3867, 6.08601, 130.6, true],
    ["Land_HBarrier_3_F", 16.3483, -7.14795, 0.799037, 56.7, false],
    ["Land_HBarrier_3_F", 10.5699, -17.7231, 0.799037, 0, false],
    ["Land_HBarrier_3_F", 7.15771, -17.0146, 0.799037, 22.9933, false],
    ["I_HMG_02_high_F", -17.3478, -5.70703, 1.68063, 263.456, true],
    ["Land_HBarrier_5_F", -15.8882, -3.57764, 0.74121, 173.368, false],
    ["Land_BagFence_Round_F", -18.4589, -6.03467, 0.420007, 74.6585, false],
    ["I_HMG_02_high_F", 5.57922, 17.4019, 1.68063, 2.18996, true],
    ["Land_HBarrier_5_F", 7.46228, 15.6357, 0.74121, 272.102, false],
    ["Land_BagFence_Round_F", 5.42407, 18.5498, 0.420007, 173.393, false],
    ["CamoNet_BLUFOR_open_F", 2.17114, 14.1138, 1.16854, 178.969, false]
];
// --DUWS-COMPOSITION END--

private _tiltTypes = [
    "Land_HBarrierBig_F","Land_HBarrier_5_F","Land_HBarrier_3_F","Land_BagBunker_Large_F",
    "Land_BagFence_Round_F","Land_BagFence_Short_F","Land_BagFence_Long_F",
    "Land_BagFence_Corner_F","Land_BagFence_End_F","Land_SandbagBarricade_01_hole_F",
    "Land_Razorwire_F"
];

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

    if !(_class in _keepSimulation) then {
        _obj enableSimulationGlobal false;
    };

    // Fragile props kept indestructible.
    if (_class in ["Land_WaterTank_F","Land_PaperBox_closed_F","Land_PaperBox_open_empty_F","Land_GarbageBags_F"]) then {
        _obj allowDamage false;
    };
} forEach _allObjectsData;

sleep 2;

private _weaponList = [];
private _origin = [_centerSpawnX, _centerSpawnY, _newCenterZ];
{
    // Index 5 is the prefab convention's isWeapon; the ground pass above placed everything else.
    if !(_x select 5) then { continue; };
    _weaponList pushBack ([_x, _origin, "opfor", _zoneKey, "world"] call fnc_static_place);
} forEach _allObjectsData;

sleep 2;
// Pass the guns this composition placed, not a class+radius search: one a search missed stayed
// frozen for the campaign, and a radius also claims a neighbouring composition's guns.
[_weaponList, _centerSpawn] call DUWS_fnc_crewCompositionStatics;

// Backup camp light.
private _light1 = createVehicle ["Land_Camping_Light_F", [_centerSpawnX, _centerSpawnY, 0], [], 0, "NONE"];
[_light1, _zoneKey] call fnc_duws_keep;
_light1 setPosATL [_centerSpawnX, _centerSpawnY, 0];
_light1 allowdamage false;
_light1 setdamage 0;