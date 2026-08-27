// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
if (!([10, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};


_radius = 400;
_cpreward = DUWS_curReward select 0;
_apreward = DUWS_curReward select 1;
_deadline = DUWS_curDeadlineAt;
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_radarletsdothis";
_message1 = ([localize "STR_DUWS_T_radarend"] call fnc_cs);

_markerText2 = localize "STR_DUWS_T_c10";

private _site = [_MissionPos, _radius, 10] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// Marked before anything is built. The ellipse and the task are the only things telling the
// player where the objective is, and the spawn-up below runs for tens of seconds.
_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;
private _VARtaskgeneratedName = format ["cache%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[_VARtaskgeneratedName, localize "STR_DUWS_T_n4uc7t2x", _mission_name, _randomPos, "destroy"] call fnc_missionTaskCreate;

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn",  [0,-2] select isDedicated];

_radarPos = _targetpos;


_centerSpawn = _radarPos;
_centerSpawnX = _centerSpawn select 0;
_centerSpawnY = _centerSpawn select 1;

// Rows are [class, X, Y, Z, dir, isWeapon], offsets from the site centre. One fence, the zone
// prefabs' convention: the props and the guns stand up in the same breath and are torn down under
// the same key, so a second fence would only mean two entries in the composition tool for one site.
// The flag is hand-carried back after a round trip -- the Eden export emits five columns and stops.
//
// A gun's class is a placeholder: fnc_static_place stands whatever OPFOR fields for the role, this
// being their radar, and the row's own class only decides what the Eden import draws.
// --DUWS-COMPOSITION BEGIN name="Mission: Destroy Radar" schema=A--
_staticsArray = [
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
[_staticsArray, [_centerSpawnX, _centerSpawnY], "mission_destroy_radar", [0, ["Land_HBarrier_5_F","Land_Razorwire_F"], "all"]] call fnc_composition_place;

_vehicle_7 = objNull;
_vehicle_7 = createVehicle ["I_E_Radar_System_01_F", [0,0,0], [], 0, "CAN_COLLIDE"];
_vehicle_7 setDir 0;
_vehicle_7 setPosATL [(_centerSpawnX), (_centerSpawnY), 0];
_vehicle_7 setDamage 0.5;
clearMagazineCargoGlobal _vehicle_7;
clearWeaponCargoGlobal _vehicle_7;
clearItemCargoGlobal _vehicle_7;
clearBackpackCargoGlobal _vehicle_7;
[_vehicle_7, "mission_destroy_radar"] call fnc_duws_keep;

// The guns off the same fence, in a second pass because they are placed by the resolver and
// frozen until crewed, where the props above snap to the terrain and stay simulated.
private _guns = [];
{
    if !(_x select 5) then { continue; };
    private _gun = [_x, [_centerSpawnX, _centerSpawnY], "opfor", "mission_destroy_radar", "pos"] call fnc_static_place;
    // Invulnerable by design: the objective is the radar, and a launcher the player can shoot off
    // from a ridge is one the mission never asks them to close with.
    _gun allowDamage false;
    _gun setDamage 0;
    _guns pushBack _gun;
} forEach _staticsArray;
_guns params ["_vehicle_9", "_vehicle_10"];

private _groupBunker1 = [_vehicle_9, _vehicle_10, _guns] call fnc_place_bunker_guns;
_groupBunker1 addVehicle _vehicle_7;

sleep 1;

[[_targetpos, _radius] call fnc_garrisonBuildings] call fnc_mission_claim;
sleep 1;
[_targetpos, _radius] spawn fnc_missionPatrolswithintel;


[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
_speaker = localize "STR_DUWS_T_actionteam";
_message = ([localize "STR_DUWS_T_radarcopy"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];


sleep 5;


waitUntil {sleep 5; !alive _vehicle_7 || (damage _vehicle_7) == 1 || time > _deadline};

if (time > _deadline && alive _vehicle_7 && (damage _vehicle_7) < 1) exitWith {
    // TODO: give this mission a bespoke Overlord timeout-fail line; fnc_mission_deadline_fail emits the generic.
    [_VARtaskgeneratedName, _markername2, "mission_destroy_radar", _targetpos, _radius] call fnc_mission_deadline_fail;
};

// Overlord's line, not the player's: _speaker was reassigned to the player callsign above
// for the intervening exchange, which left this congratulation attributed to Alpha 1-1.
[localize "STR_DUWS_T_OVERLORD", _message1] remoteExec ["fnc_duws_dialogue", 0];
[_markername2] call fnc_missionMarkerClear;

[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[_targetpos,_radius, "mission_destroy_radar"] call fnc_mission_end;
