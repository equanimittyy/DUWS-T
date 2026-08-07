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

// Objects that must keep simulation: vehicles or interactables.
private _keepSimulation = [
    "B_Slingload_01_Medevac_F",
    "Land_Medevac_house_V1_F",
    "Land_Medevac_HQ_V1_F"
];

// Each row: [class, offsetX, offsetY, offsetZ, dir, isWeapon].
// --DUWS-COMPOSITION BEGIN name="Field Hospital" schema=A--
private _allObjectsData = [
    ["Land_HBarrier_5_F", 5.42151, -18.4834, 0.74071, 185.415, false],
    ["Land_HBarrier_5_F", -8.49133, 12.4927, 0.74071, 187.515, false],
    ["Land_HBarrier_5_F", -14.8719, 8.81201, 0.74071, 132.715, false],
    ["Land_HBarrier_5_F", 10.9641, -19.0186, 0.74071, 185.415, false],
    ["Land_HBarrier_5_F", 13.3574, 9.89795, 0.74071, 187.515, false],
    ["Land_HBarrier_5_F", -4.78235, 14.0137, 0.74071, 96.0151, false],
    ["Land_HBarrier_5_F", -4.15295, 19.6396, 0.74071, 96.0151, false],
    ["Land_HBarrier_5_F", 10.2412, 12.311, 0.74071, 96.0151, false],
    ["Land_HBarrier_5_F", 10.8137, 17.9365, 0.74071, 96.0151, false],
    ["Land_HBarrier_5_F", -0.205078, -17.9028, 0.74071, 185.415, false],
    ["Land_HBarrier_5_F", -16.807, 4.37695, 0.74071, 95.2151, false],
    ["Land_HBarrier_5_F", 17.2859, -5.07227, 0.74071, 95.2151, false],
    ["Land_HBarrier_5_F", 16.9868, -10.8149, 0.74071, 95.2151, false],
    ["Land_HBarrier_5_F", -1.45239, -8.71436, 0.74071, 95.2151, false],
    ["Land_HBarrier_5_F", -1.93823, -14.2324, 0.74071, 95.2151, false],
    ["Land_HBarrier_3_F", -11.9026, 11.8965, 0.79854, 315.415, false],
    ["Land_HBarrier_5_F", 17.0967, 6.10938, 0.74071, 64.2151, false],
    ["Land_HBarrier_5_F", 15.3799, -16.3994, 0.74071, 131.215, false],
    ["Land_HBarrier_5_F", -0.40564, 21.2964, 0.74071, 187.515, false],
    ["Land_HBarrier_5_F", -1.62292, 11.5181, 0.74071, 187.515, false],
    ["Land_HBarrier_5_F", 0.0476074, 7.69971, 0.74071, 95.5151, false],
    ["Land_HBarrier_5_F", 17.8287, 0.363281, 0.74071, 95.2151, false],
    ["Land_GarbageBags_F", -3.16443, 8.80176, 0.43383, 127.015, false],
    ["Land_HBarrier_3_F", 1.32361, 18.625, 0.79854, 277.915, false],
    ["Land_HBarrier_5_F", -17.8578, -6.70801, 0.74071, 95.2151, false],
    ["Land_HBarrier_5_F", -18.3912, -12.2529, 0.74071, 95.2151, false],
    ["Land_HBarrier_5_F", -17.3154, -1.27588, 0.74071, 95.2151, false],
    ["Land_HBarrier_5_F", -11.2411, -16.6353, 0.74071, 6.11509, false],
    ["Land_HBarrier_5_F", -5.72571, -17.2915, 0.74071, 6.11509, false],
    ["Land_HBarrier_5_F", -16.64, -15.9917, 0.74071, 6.11509, false],
    ["Land_JunkPile_F", 14.048, 3.0415, 0.27488, 96.2151, false],
    ["Land_Pallets_stack_F", 12.4047, 1.5752, 0.42976, 230.015, false],
    ["Land_GarbageBarrel_01_F", 5.3418, -1.95459, 0.61404, 97.2151, false],
    ["Land_Garbage_square5_F", 0.949829, 14.4175, 0.0396299999999998, 97.2151, false],
    ["Land_CratesShabby_F", 12.4712, 0.0522461, 0.76003, 347.315, false],
    ["Land_Loudspeakers_F", -0.198364, -5.94189, 3.503381, 97.2151, false],
    ["Land_GarbageHeap_03_F", -16.531, -10.3032, 0.52727, 94.9151, false],
    ["MedicalGarbage_01_5x5_v1_F", -15.6232, -7.34961, 0.0347399999999998, 185.415, false],
    ["MedicalGarbage_01_5x5_v1_F", -6.58545, -8.28711, 0.0347399999999998, 185.415, false],
    ["MedicalGarbage_01_5x5_v1_F", -13.1969, 1.38867, 0.0347399999999998, 285.515, false],
    ["MedicalGarbage_01_5x5_v1_F", 0.642944, 4.84814, 0.0347399999999998, 358.915, false],
    ["MedicalGarbage_01_5x5_v1_F", 9.72766, -2.15527, 0.0347399999999998, 185.415, false],
    ["MedicalGarbage_01_5x5_v1_F", 6.43054, -0.677734, 0.0347399999999998, 358.915, false],
    ["B_Slingload_01_Medevac_F", -14.9169, -1.36768, 1.35934, 185.415, false],
    ["Land_PortableCabinet_01_medical_F", -2.59143, -6.41406, 0.41814, 12.9151, false],
    ["Land_Medevac_house_V1_F", -6.70959, -11.4502, 0.7002, 185.415, false],
    ["Land_Medevac_HQ_V1_F", 8.97131, -7.91992, 3.869528, 95.7151, false],
    ["I_HMG_02_high_F", 5.1958, -6.05859, 4.806458, 273.547, true],
    ["I_HMG_02_high_F", 13.6233, -14.209, 4.774981, 185.412, true],
    ["Land_HelipadRescue_F", -6.82239, 0.424316, 0.000199999999999978, 185.415, false],
    ["Land_BagFence_Round_F", 1.5304, 24.9351, 0.41951, 185.415, false],
    ["I_HMG_02_high_F", 1.66321, 23.4595, 1.67994, 1.7151, true],
    ["I_static_AA_F", 9.73108, -10.8828, 4.109946, 6.83446, true]
];
// --DUWS-COMPOSITION END--

private _tiltTypes = [
    "Land_HBarrierBig_F","Land_HBarrier_5_F","Land_HBarrier_3_F","Land_HBarrier_1_F",
    "Land_BagBunker_Large_F","Land_BagFence_Round_F","Land_BagFence_Short_F",
    "Land_BagFence_Long_F","Land_BagFence_Corner_F","Land_BagFence_End_F",
    "Land_SandbagBarricade_01_hole_F","Land_Razorwire_F"
];

{
    _x params ["_class","_offsetX","_offsetY","_offsetZ","_dir","_isWeapon"];
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
    if (_class in ["Land_Pallets_stack_F","Land_GarbageBarrel_01_F","Land_CratesShabby_F","Land_PortableCabinet_01_medical_F"]) then {
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