// Locality: server; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).
#include "..\..\..\..\shared\includes\action_style.hpp"

params ["_MissionPos", "_mission_name"];
if (!([9, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};


private _missionUnits = [];

_radius = 400;
_cpreward = DUWS_curReward select 0;
_apreward = DUWS_curReward select 1;
_deadline = DUWS_curDeadlineAt;
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_cacheletsdothis";

_markerText2 = localize "STR_DUWS_T_c9";

private _site = [_MissionPos, _radius, 9] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// Marked before anything is built. The ellipse and the task are the only things telling the
// player where the objective is, and the spawn-up below runs for tens of seconds.
_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;
private _VARtaskgeneratedName = format ["cache%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[_VARtaskgeneratedName, localize "STR_DUWS_T_geryeddp", _mission_name, _randomPos, "destroy"] call fnc_missionTaskCreate;

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];

_cachePos = _targetpos;


_centerSpawn = _cachePos;
_centerSpawnX = _centerSpawn select 0;
_centerSpawnY = _centerSpawn select 1;

// Rows are [class, X, Y, Z, dir, isWeapon], offsets from the site centre. One fence, the zone
// prefabs' convention: the props and the guns stand up in the same breath and are torn down under
// the same key, so a second fence would only mean two entries in the composition tool for one site.
// The flag is hand-carried back after a round trip -- the Eden export emits five columns and stops.
//
// A gun's class is a placeholder: fnc_static_place stands whatever OPFOR fields for the role, this
// being their cache. A BLUFOR key here would have the player's own faction defending the enemy's
// supplies. The row's own class only decides what the Eden import draws.
// --DUWS-COMPOSITION BEGIN name="Mission: Destroy Cache" schema=A--
_staticsArray = [
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

_vehicle = objNull;
{
    _x params ["_class", "_posX", "_posY", "_posZ", "_dir", "_isWeapon"];
    if (_isWeapon) then { continue; };
    _vehicle = createVehicle [_class, [0,0,0], [], 0, "CAN_COLLIDE"];
    _vehicle setDir _dir;
    _vehicle setPosATL [(_centerSpawnX)+_posX,(_centerSpawnY)+_posY,0];
    [_vehicle, "mission_destroy_cache"] call fnc_duws_keep;
} forEach _staticsArray;

_vehicle_7 = createVehicle ["Box_FIA_Ammo_F", [0,0,0], [], 0, "CAN_COLLIDE"];
[_vehicle_7, "mission_destroy_cache"] call fnc_duws_keep;
_vehicle_7 setDir 0;
_vehicle_7 setPosATL [(_centerSpawnX), (_centerSpawnY), 0];
_vehicle_7 setDamage 0.5;
_vehicle_7 setVariable ["R3F_LOG_disabled", true];
clearMagazineCargoGlobal _vehicle_7;
clearWeaponCargoGlobal _vehicle_7;
clearItemCargoGlobal _vehicle_7;
clearBackpackCargoGlobal _vehicle_7;

[_vehicle_7, {
    private _actionID = _this addAction [
        ACT_EQUIP("STR_DUWS_T_CACHE_SEIZE"),
        {
            params ["_target", "_caller", "_actionId"];
            if (!(_target getVariable ["arsenalUsed", false])) then {
                _target setVariable ["arsenalUsed", true, true];
                _target removeAction _actionId;
                [_target] remoteExec ["fnc_removeArsenalAction", 0];
                ["arsenal", [localize "STR_DUWS_T_CACHE_SEIZED_TITLE", localize "STR_DUWS_T_CACHE_SEIZED_DESC"]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
                [] remoteExec ["fnc_captured_pool_cache_deposit", 2];
            };
        },
        [],
        80,
        true,
        true,
        "",
        "!(_target getVariable ['arsenalUsed', false])"
    ];
    _this setVariable ["arsenalActionID", _actionID];
}] remoteExec ["call", 0, true];
_vehicle_7 setVariable ["arsenalUsed", false, true];

_vehicle_8 = createVehicle ["Box_FIA_Ammo_F", [0,0,0], [], 0, "CAN_COLLIDE"];
[_vehicle_8, "mission_destroy_cache"] call fnc_duws_keep;
_vehicle_8 setDir 0;
_vehicle_8 setPosATL [(_centerSpawnX)+2.23633, (_centerSpawnY)-0.296875, 0];
_vehicle_8 setDamage 0.5;
_vehicle_8 setVariable ["R3F_LOG_disabled", true];
clearMagazineCargoGlobal _vehicle_8;
clearWeaponCargoGlobal _vehicle_8;
clearItemCargoGlobal _vehicle_8;
clearBackpackCargoGlobal _vehicle_8;

[_vehicle_8, {
    private _actionID = _this addAction [
        ACT_EQUIP("STR_DUWS_T_CACHE_SEIZE"),
        {
            params ["_target", "_caller", "_actionId"];
            if (!(_target getVariable ["arsenalUsed", false])) then {
                _target setVariable ["arsenalUsed", true, true];
                _target removeAction _actionId;
                [_target] remoteExec ["fnc_removeArsenalAction", 0];
                ["arsenal", [localize "STR_DUWS_T_CACHE_SEIZED_TITLE", localize "STR_DUWS_T_CACHE_SEIZED_DESC"]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];
                [] remoteExec ["fnc_captured_pool_cache_deposit", 2];
            };
        },
        [],
        80,
        true,
        true,
        "",
        "!(_target getVariable ['arsenalUsed', false])"
    ];
    _this setVariable ["arsenalActionID", _actionID];
}] remoteExec ["call", 0, true];
_vehicle_8 setVariable ["arsenalUsed", false, true];

// The guns off the same fence, in a second pass because they are placed by the resolver and
// frozen until crewed, where the props above snap to the terrain and stay simulated.
private _guns = [];
{
    if !(_x select 5) then { continue; };
    private _gun = [_x, [_centerSpawnX, _centerSpawnY], "opfor", "mission_destroy_cache", "pos"] call fnc_static_place;
    _gun allowDamage false;
    _gun setDamage 0;
    _guns pushBack _gun;
} forEach _staticsArray;
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
_missionUnits pushBack _guard1;
_missionUnits pushBack _guard2;
{
    _missionUnits pushBack _x;
} forEach (units _groupBunker1);
{
    _missionUnits pushBack _x;
} forEach (units _groupBunker2);

{
    [_x] call fnc_addRandomLoot;
} forEach units _groupBunker1;
{
    [_x] call fnc_addRandomLoot;
} forEach units _groupBunker2;

[[_cachePos, _radius] call fnc_garrisonBuildings] call fnc_mission_claim;

sleep 1;
[_targetpos, _radius] spawn fnc_missionPatrolswithintel;


[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
_speaker = localize "STR_DUWS_T_actionteam";
_message = ([localize "STR_DUWS_T_cachecopy"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
["arsenal", [localize "STR_DUWS_T_arsenalfound", localize "STR_DUWS_T_arsenalfound2"]] remoteExec ["BIS_fnc_showNotification", [0,-2] select isDedicated];


sleep 5;


waitUntil {
    sleep 5;
    ( (!alive _vehicle_7 || damage _vehicle_7 == 1) && (!alive _vehicle_8 || damage _vehicle_8 == 1) ) || time > _deadline
};

if (time > _deadline && !((!alive _vehicle_7 || damage _vehicle_7 == 1) && (!alive _vehicle_8 || damage _vehicle_8 == 1))) exitWith {
    // TODO: give this mission a bespoke Overlord timeout-fail line; fnc_mission_deadline_fail emits the generic.
    [_VARtaskgeneratedName, _markername2, "mission_destroy_cache", _targetpos, _radius] call fnc_mission_deadline_fail;
};

// Units only, and deleted rather than handed to the sweep: they are not composition, and
// the sweep spares anything with living crew -- a man's crew is himself. The mission's
// props leave through fnc_duws_release, which its own cleanup call triggers.
{ deleteVehicle _x } forEach _missionUnits;

"grenade" createVehicle[(_cachePos select 0), (_cachePos select 1)];
sleep 0.5;
"grenade" createVehicle[(_cachePos select 0), (_cachePos select 1)];
"grenade" createVehicle[(_cachePos select 0), (_cachePos select 1)];
sleep 0.1;
"grenade" createVehicle[(_cachePos select 0), (_cachePos select 1)];
sleep 0.5;
"Bo_Mk82" createVehicle[(_cachePos select 0), (_cachePos select 1)];
sleep 0.5;
"Bo_Mk82" createVehicle[(_cachePos select 0), (_cachePos select 1)];
sleep 0.5;
"grenade" createVehicle[(_cachePos select 0), (_cachePos select 1)];
sleep 0.5;
"grenade" createVehicle[(_cachePos select 0), (_cachePos select 1)];

[_markername2] call fnc_missionMarkerClear;

[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[_targetpos, _radius, "mission_destroy_cache"] call fnc_mission_end;
