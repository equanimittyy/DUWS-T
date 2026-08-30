// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;

private _build = {
    params ["_targetpos", "_randomPos", "_radius", "_Building"];
    private _cx = _targetpos select 0;
    private _cy = _targetpos select 1;

    // Rows are [class, X, Y, Z, dir, isWeapon], offsets from the site centre. One fence, per the zone-prefab
    // convention (props and guns share one key). A gun's class is a placeholder -- fnc_static_place stands
    // whatever OPFOR fields for the role (this is their radar); the row's own class only decides what the
    // Eden import draws.
    // --DUWS-COMPOSITION BEGIN name="Mission: Destroy Radar" schema=A--
    private _staticsArray = [
        ["Land_HBarrier_5_F", -12.7821, 1.67578, 0.74121, 357.084, false],
        ["Land_HBarrier_5_F", -10.8344, 5.30371, 0.74121, 88.8804, false],
        ["Land_HBarrier_5_F", -3.10889, 7.66797, 0.74121, 359.366, false],
        ["Land_HBarrier_5_F", 2.46887, 7.64404, 0.74121, 0.734881, false],
        ["Land_HBarrier_5_F", -12.6466, -8.27295, 0.74121, 178.561, false],
        ["Land_HBarrier_5_F", 9.88489, -5.79297, 0.74121, 268.867, false],
        ["Land_HBarrier_5_F", -2.87354, -8.02246, 0.74121, 359.366, false],
        ["Land_HBarrier_5_F", 2.70422, -8.04639, 0.74121, 0.734881, false],
        ["Land_Cargo_Patrol_V1_F", 8.20508, -8.42627, 4.9057, 0.141103, false],
        ["Land_Cargo_Patrol_V1_F", -9.10828, 7.94092, 4.9057, 178.143, false],
        ["I_HMG_02_high_F", -7.69751, 9.33301, 6.02448, 0, true],
        ["I_HMG_02_high_F", 6.47229, -9.54004, 6.02449, 182.315, true],
        ["Land_BagBunker_Small_F", 7.04077, 8.77393, 0.966326, 178.659, false],
        ["Land_BagBunker_Small_F", -7.74792, -8.97998, 0.966326, 358.991, false],
        ["Land_Razorwire_F", -0.140747, 9.9541, 0.755762, 0.741684, false],
        ["Land_Razorwire_F", -0.729736, -9.95898, 0.755762, 181.375, false],
        ["I_static_AA_F", -11.2568, -3.27197, 0.983929, 263.115, true],
        ["Land_HBarrier_5_F", -16.4458, -0.746582, 0.74121, 269.288, false],
        ["Land_HBarrier_5_F", -16.385, -6.33154, 0.74121, 269.4, false],
        ["Land_HBarrier_5_F", 11.8722, -2.11377, 0.74121, 177.395, false],
        ["Land_HBarrier_5_F", 15.549, 0.288574, 0.74121, 89.5983, false],
        ["Land_HBarrier_5_F", 15.5184, 5.87402, 0.74121, 89.7102, false],
        ["Land_HBarrier_5_F", 11.7906, 7.83545, 0.74121, 358.872, false],
        ["I_static_AA_F", 10.0642, 2.63379, 0.983929, 83.9409, true]
    ];
    // --DUWS-COMPOSITION END--

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

    // The guns off the same fence, in a second pass because they are placed by the resolver and
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

    sleep 1;
    [[_targetpos, _radius] call fnc_garrisonBuildings] call fnc_mission_claim;
    sleep 1;
    [_targetpos, _radius, 3] spawn fnc_missionPatrols;

    _radar
};

private _done = { !alive _this || (damage _this) == 1 };

if (!([10, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

private _radius = 400;
private _site = [_MissionPos, _radius, 10, _requester] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

private _taskId = format ["cache%1%2", round (_MissionPos select 0), round (_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;
private _handles = [_targetpos, _randomPos, _radius, _Building] call _build;
if (isNil "_handles") then { _handles = [] };

private _marker = [_randomPos, _radius, _taskId, localize "STR_DUWS_T_n4uc7t2x", _mission_name, "destroy",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_radarletsdothis", 8], ["STR_DUWS_T_actionteam", "STR_DUWS_T_radarcopy", 0]]
] call fnc_mission_present;

sleep 5; // let the guard force finish arriving before the win poll starts

private _deadline = DUWS_curDeadlineAt;
waitUntil { sleep 2; (_handles call _done) || time > _deadline };

if (!(_handles call _done) && time > _deadline) exitWith {
    [_mission_name, _taskId, "FAILED", _targetpos, _radius, [_marker], [], false, "mission_destroy_radar"] call fnc_mission_finish;
};

[_mission_name, _taskId, "SUCCEEDED", _targetpos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_radarend"], true, "mission_destroy_radar"] call fnc_mission_finish;
