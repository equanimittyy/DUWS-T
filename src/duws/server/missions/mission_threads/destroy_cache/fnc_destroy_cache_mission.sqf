// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;

private _build = {
    params ["_targetpos", "_randomPos", "_radius", "_Building"];
    private _cx = _targetpos select 0;
    private _cy = _targetpos select 1;

    // Rows are [class, X, Y, Z, dir, isWeapon], offsets from the site centre. One fence, per the zone-prefab
    // convention (props and guns share one key). A gun's class is a placeholder -- fnc_static_place stands
    // whatever OPFOR fields for the role (this is their cache; a BLUFOR key would defend it with the
    // player's own faction). The row's own class only decides what the Eden import draws.
    // --DUWS-COMPOSITION BEGIN name="Mission: Destroy Cache" schema=A--
    private _staticsArray = [
        ["CamoNet_INDP_open_F", 0.942383, -0.640625, 1.16854, 342.004, false],
        ["Land_GarbageHeap_02_F", -1.71191, -1.54443, 0.07052, 93.4817, false],
        ["Land_CratesWooden_F", -1.27148, 2.11084, 0.7397, 0, false],
        ["Land_GarbageHeap_04_F", -2.4165, -0.706543, 0.51297, 90.9487, false],
        ["Land_CratesWooden_F", 1.46631, -3.19775, 0.7397, 0, false],
        ["Land_HBarrier_5_F", -6.48291, -3.77783, 0.74121, 49.5237, false],
        ["Land_HBarrier_5_F", -8.11426, 1.68848, 0.74121, 88.8804, false],
        ["Land_HBarrier_5_F", 1.94653, -8.04492, 0.74121, 0.520331, false],
        ["Land_HBarrier_5_F", -0.718384, 8.46387, 0.74121, 183.745, false],
        ["Land_HBarrier_5_F", 3.80957, 6.41455, 0.74121, 45.2709, false],
        ["Land_HBarrier_5_F", 9.2251, -1.25684, 0.74121, 269.491, false],
        ["Land_BagBunker_Small_F", -7.08691, 7.32031, 0.96633, 134.261, false],
        ["Land_BagBunker_Small_F", 8.24512, -6.67188, 0.96633, 314.617, false],
        ["O_HMG_01_high_F", -6.99316, 7.51807, 1.66099, 314.218, true],
        ["O_HMG_01_high_F", 8.30847, -6.73242, 1.66099, 136.703, true]
    ];
    // --DUWS-COMPOSITION END--

    // Cover props: frozen, tilted flush and hardened by the shared placer, the way zones and hardpoints
    // build theirs. Weapon rows are skipped here and stood up in the fnc_static_place pass below.
    [_staticsArray, [_cx, _cy], "mission_destroy_cache", [0, ["Land_HBarrier_5_F","Land_Razorwire_F"], "all"]] call fnc_composition_place;

    private _vehicle_7 = createVehicle ["Box_FIA_Ammo_F", [0,0,0], [], 0, "CAN_COLLIDE"];
    [_vehicle_7, "mission_destroy_cache"] call fnc_duws_keep;
    _vehicle_7 setDir 0;
    _vehicle_7 setPosATL [_cx, _cy, 0];
    _vehicle_7 setDamage 0.5;
    _vehicle_7 setVariable ["R3F_LOG_disabled", true];
    clearMagazineCargoGlobal _vehicle_7;
    clearWeaponCargoGlobal _vehicle_7;
    clearItemCargoGlobal _vehicle_7;
    clearBackpackCargoGlobal _vehicle_7;

    private _vehicle_8 = createVehicle ["Box_FIA_Ammo_F", [0,0,0], [], 0, "CAN_COLLIDE"];
    [_vehicle_8, "mission_destroy_cache"] call fnc_duws_keep;
    _vehicle_8 setDir 0;
    _vehicle_8 setPosATL [_cx + 2.23633, _cy - 0.296875, 0];
    _vehicle_8 setDamage 0.5;
    _vehicle_8 setVariable ["R3F_LOG_disabled", true];
    clearMagazineCargoGlobal _vehicle_8;
    clearWeaponCargoGlobal _vehicle_8;
    clearItemCargoGlobal _vehicle_8;
    clearBackpackCargoGlobal _vehicle_8;

    // The guns off the same fence, in a second pass because they are placed by the resolver and
    // frozen until crewed, where the props above snap to the terrain and stay simulated.
    private _guns = [];
    {
        if !(_x select 5) then { continue; };
        // "world", not "pos": pos uses setPos (AGL, which counts a building roof), so a site over a building
        // lands the gun on the roof; world grounds it at terrain height like the hardpoints.
        private _gun = [_x, [_cx, _cy], "opfor", "mission_destroy_cache", "world"] call fnc_static_place;
        _gun allowDamage false;
        _gun setDamage 0;
        _guns pushBack _gun;
    } forEach _staticsArray;
    _guns params ["_vehicle_9", "_vehicle_10"];

    private _groupBunker1 = [_vehicle_9, _vehicle_10, _guns] call fnc_place_bunker_guns;
    // Claimed, not hand-deleted: ownership hands the gunners to the cleanup sweep, which bins them on both
    // the success and the timeout exit once the player is clear -- the same teardown the garrison gets.
    [_groupBunker1] call fnc_mission_claim;

    [[_targetpos, _radius] call fnc_garrisonBuildings] call fnc_mission_claim;

    sleep 1;
    [_targetpos, _radius] spawn fnc_missionPatrolswithintel;

    [_vehicle_7, _vehicle_8]
};

// Cook off the levelled cache once it is down: cosmetic secondary explosions on the wreck, run after
// the task ticks over. The boxes are already destroyed by the win predicate.
private _onWin = {
    params ["_v7", "_v8"];
    private _p = getPosATL _v7;
    private _px = _p select 0;
    private _py = _p select 1;
    "grenade" createVehicle [_px, _py];
    sleep 0.5;
    "grenade" createVehicle [_px, _py];
    "grenade" createVehicle [_px, _py];
    sleep 0.1;
    "grenade" createVehicle [_px, _py];
    sleep 0.5;
    "Bo_Mk82" createVehicle [_px, _py];
    sleep 0.5;
    "Bo_Mk82" createVehicle [_px, _py];
    sleep 0.5;
    "grenade" createVehicle [_px, _py];
    sleep 0.5;
    "grenade" createVehicle [_px, _py];
};

// Win when both ammo boxes are destroyed.
private _done = { ((!alive (_this select 0)) || (damage (_this select 0)) == 1) && ((!alive (_this select 1)) || (damage (_this select 1)) == 1) };

if (!([9, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

private _radius = 400;
private _site = [_MissionPos, _radius, 9, _requester] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

private _taskId = format ["cache%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;
private _handles = [_targetpos, _randomPos, _radius, _Building] call _build;
if (isNil "_handles") then { _handles = [] };

private _marker = [_randomPos, _radius, _taskId, localize "STR_DUWS_T_geryeddp", _mission_name, "destroy",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_cacheletsdothis", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_cachecopy", 0]]
] call fnc_mission_present;

sleep 5; // let the guard force finish arriving before the win poll starts

private _deadline = DUWS_curDeadlineAt;
waitUntil { sleep 2; (_handles call _done) || time > _deadline };

if (!(_handles call _done) && time > _deadline) exitWith {
    [_mission_name, _taskId, "FAILED", _targetpos, _radius, [_marker], [], false, "mission_destroy_cache"] call fnc_mission_finish;
};

[_mission_name, _taskId, "SUCCEEDED", _targetpos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_cacheend"], true, "mission_destroy_cache", false, false, _onWin, _handles] call fnc_mission_finish;
