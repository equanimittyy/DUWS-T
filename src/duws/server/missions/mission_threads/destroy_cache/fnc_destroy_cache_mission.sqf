// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;

private _build = {
    params ["_targetpos", "_randomPos", "_radius"];
    private _cx = _targetpos select 0;
    private _cy = _targetpos select 1;

    // One composition, per the zone-prefab convention (props and guns share one key). A gun's class is a
    // placeholder -- fnc_static_place stands whatever OPFOR fields for the role (this is their cache; a
    // BLUFOR key would defend it with the player's own faction). The class only decides what Eden draws.
    private _staticsArray = ["duws_mission_destroy_cache"] call fnc_composition_rows;

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

    // The guns off the same composition, in a second pass because they are placed by the resolver and
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

    // Open ground: no buildings to garrison, so field a close guard on the cache instead.
    private _guard = ["team", _targetpos, 100, "closepatrol"] call fnc_spawn_team;
    if (!isNull _guard) then { [_guard] call fnc_mission_claim };

    sleep 1;
    [_targetpos, _radius, 3] spawn fnc_missionPatrols;

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
// Trust the offer: the terrain gate vetted this dot as level ground for the composition.
private _randomPos = _MissionPos;
private _targetpos = _MissionPos;

private _taskId = format ["cache%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;
private _handles = [_targetpos, _randomPos, _radius] call _build;
if (isNil "_handles") then { _handles = [] };

private _marker = [_randomPos, _radius, _taskId, localize "STR_DUWS_T_geryeddp", _mission_name, "destroy",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_cacheletsdothis", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_cachecopy", 0]]
] call fnc_mission_present;

[_handles, _done, _mission_name, _taskId, _targetpos, _radius, [_marker],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_cacheend"], "mission_destroy_cache", [false, false, _onWin, _handles]] call fnc_mission_watch;
