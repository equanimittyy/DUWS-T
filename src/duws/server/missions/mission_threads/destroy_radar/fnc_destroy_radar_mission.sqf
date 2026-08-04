// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
if (!([10, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};


_radius = 400;
_cpreward = 25;
_apreward = 20;
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

// --DUWS-COMPOSITION BEGIN name="Mission: Destroy Radar" schema=A--
_staticsArray = [
    ["Box_FIA_Ammo_F", 3.23633, -0.296875, 0, 0],
    ["Land_CratesWooden_F", 3.46631, -3.19775, 1, 0],
    ["Land_HBarrier_5_F", -6.48291, -3.77783, 0, 49.5237],
    ["Land_HBarrier_5_F", -8.11426, 1.68848, 0, 88.8804],
    ["Land_HBarrier_5_F", 1.946484, -8.04492, 0, 0.520331],
    ["Land_HBarrier_5_F", -0.718359, 8.46387, 0, 183.745],
    ["Land_HBarrier_5_F", 3.80957, 6.41455, 0, 45.2709],
    ["Land_HBarrier_5_F", 9.2251, -1.25684, 0, 269.491]
];
// --DUWS-COMPOSITION END--

_vehicle = objNull;
{
    _x params ["_class", "_posX", "_posY", "_posZ", "_dir"];
    _vehicle = createVehicle [_class, [0,0,0], [], 0, "CAN_COLLIDE"];
    _vehicle setDir _dir;
    _vehicle setPosATL [(_centerSpawnX)+_posX,(_centerSpawnY)+_posY,0];
    [_vehicle, "mission_destroy_radar"] call fnc_duws_keep;
} forEach _staticsArray;

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

// The radar's air cover, fenced like the barriers above so a rearrange in the 3D editor reaches it.
// The classes are placeholders resolved against OPFOR: this is an enemy site, and it stood NATO
// launchers over an enemy radar until it went through fnc_static_place.
// --DUWS-COMPOSITION BEGIN name="Mission: Destroy Radar guns" schema=A--
_gunArray = [
    ["B_static_AA_F", -5.52539,  5.98193, 0, 314.218],
    ["B_static_AA_F",  6.7168,  -5.49365, 0, 136.703]
];
// --DUWS-COMPOSITION END--

// Invulnerable by design: the objective is the radar, and a launcher the player can shoot off from
// a ridge is one the mission never asks them to close with.
private _guns = _gunArray apply {
    private _gun = [_x, [_centerSpawnX, _centerSpawnY], "opfor", "mission_destroy_radar", "pos"] call fnc_static_place;
    _gun allowDamage false;
    _gun setDamage 0;
    _gun
};
_guns params ["_vehicle_9", "_vehicle_10"];

_groupBunker1 = [getpos _vehicle_9, EAST, [opfor_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_groupBunker1 deleteGroupWhenEmpty true;
_groupBunker2 = [getpos _vehicle_10, EAST, [opfor_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_groupBunker2 deleteGroupWhenEmpty true;
[[_groupBunker1, _groupBunker2]] call fnc_mission_claim;
_guard1 = units _groupBunker1 select 0;
_guard2 = units _groupBunker2 select 0;
_guard1 moveinGunner _vehicle_9;
_guard2 moveinGunner _vehicle_10;
// The thaw for fnc_static_place's placement freeze.
{ _x enableSimulationGlobal true } forEach _guns;

[_guard2] joinSilent _groupBunker1;
_groupBunker1 addVehicle _vehicle_7;

sleep 1;

[[_targetpos, _radius] call fnc_garrisonBuildings] call fnc_mission_claim;
// ========== 添加死亡情报动作 ==========
{
    if (!isNull _x) then {
        [_x, "mission"] call fnc_search_flag_group;
    };
} forEach [_groupBunker1, _groupBunker2];
{
    [_x] call fnc_addRandomLoot;
} forEach units _groupBunker1;
{
    [_x] call fnc_addRandomLoot;
} forEach units _groupBunker2;
sleep 1;
[_targetpos, _radius] spawn fnc_missionPatrolswithintel;


[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
_speaker = localize "STR_DUWS_T_actionteam";
_message = ([localize "STR_DUWS_T_radarcopy"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];


sleep 5; // 等待巡逻队生成完毕


waitUntil {sleep 5; !alive _vehicle_7 || (damage _vehicle_7) == 1};

// Overlord's line, not the player's: _speaker was reassigned to the player callsign above
// for the intervening exchange, which left this congratulation attributed to Alpha 1-1.
[localize "STR_DUWS_T_OVERLORD", _message1] remoteExec ["fnc_duws_dialogue", 0];
[_markername2] call fnc_missionMarkerClear;

[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[_targetpos,_radius, "mission_destroy_radar"] call fnc_mission_end;
