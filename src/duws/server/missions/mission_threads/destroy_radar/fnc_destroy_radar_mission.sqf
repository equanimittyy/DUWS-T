// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;

private _build = {
    params ["_targetpos", "_randomPos", "_radius"];
    private _cx = _targetpos select 0;
    private _cy = _targetpos select 1;

    // One composition, per the zone-prefab convention (props and guns share one key). A gun's class is a
    // placeholder -- fnc_static_place stands whatever OPFOR fields for the role (this is their radar). The class
    // only decides what Eden draws.
    private _staticsArray = ["duws_mission_destroy_radar"] call fnc_composition_rows;

    // Cover props: frozen, tilted flush and hardened by the shared placer, the way zones and hardpoints
    // build theirs. Weapon rows are skipped here and stood up in the fnc_static_place pass below.
    [_staticsArray, [_cx, _cy], "mission_destroy_radar", [0, ["Land_HBarrier_5_F","Land_Razorwire_F"], "all"]] call fnc_composition_place;

    private _radar = createVehicle ["I_E_Radar_System_01_F", [0,0,0], [], 0, "CAN_COLLIDE"];
    _radar setDir 0;
    _radar setPosATL [_cx, _cy, 0];
    _radar setDamage 0.5;
    clearMagazineCargoGlobal _radar;
    clearWeaponCargoGlobal _radar;
    clearItemCargoGlobal _radar;
    clearBackpackCargoGlobal _radar;
    [_radar, "mission_destroy_radar"] call fnc_duws_keep;

    // The guns off the same composition, in a second pass because they are placed by the resolver and
    // frozen until crewed, where the props above snap to the terrain and stay simulated.
    private _guns = [];
    {
        if !(_x select 5) then { continue; };
        // "world", not "pos": pos uses setPos (AGL, which counts a building roof), so a site over a building
        // lands the gun on the roof; world grounds it at terrain height like the hardpoints.
        private _gun = [_x, [_cx, _cy], "opfor", "mission_destroy_radar", "world"] call fnc_static_place;
        // Invulnerable by design: the objective is the radar, and a launcher the player can shoot off
        // from a ridge is one the mission never asks them to close with.
        _gun allowDamage false;
        _gun setDamage 0;
        _guns pushBack _gun;
    } forEach _staticsArray;
    _guns params ["_vehicle_9", "_vehicle_10"];

    private _groupBunker1 = [_vehicle_9, _vehicle_10, _guns] call fnc_place_bunker_guns;
    _groupBunker1 addVehicle _radar;
    // Claimed so the cleanup sweep bins the gunners on both the success and the timeout exit, once the
    // player is clear -- the same teardown the garrison and patrols get. The radar hull and the guns are
    // composition, released by fnc_mission_end's compKey; this covers only the men.
    [_groupBunker1] call fnc_mission_claim;

    // Open ground: no buildings to garrison, so field a close guard on the radar instead.
    sleep 1;
    private _guard = ["team", _targetpos, 100, "closepatrol"] call fnc_spawn_team;
    if (!isNull _guard) then { [_guard] call fnc_mission_claim };
    sleep 1;
    [_targetpos, _radius, 3] spawn fnc_missionPatrols;

    _radar
};

private _done = { !alive _this || (damage _this) == 1 };

if (!([10, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

private _radius = 400;
// Trust the offer: the terrain gate vetted this dot as level ground for the composition.
private _randomPos = _MissionPos;
private _targetpos = _MissionPos;

private _taskId = format ["cache%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;
private _handles = [_targetpos, _randomPos, _radius] call _build;
if (isNil "_handles") then { _handles = [] };

private _marker = [_randomPos, _radius, _taskId, localize "STR_DUWS_T_n4uc7t2x", _mission_name, "destroy",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_radarletsdothis", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_radarcopy", 0]]
] call fnc_mission_present;

[_handles, _done, _mission_name, _taskId, _targetpos, _radius, [_marker],
    ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_radarend"], "mission_destroy_radar"] call fnc_mission_watch;
