// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
if (!([3, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};


_radius = 400;
_cpreward = 20;
_apreward = 25;
_speaker = localize "STR_DUWS_T_OVERLORD";
_speaker1 = localize "STR_DUWS_T_Cobra";
_message = localize "STR_DUWS_T_towerletsdothis";
_message1 = localize "STR_DUWS_T_towersignallost";
_message2 = localize "STR_DUWS_T_toweroverlord";

_taskTimeout_tower = 900;
_missionStartTime = time;
_hasShown2MinHint = false;

_markerText2 = localize "STR_DUWS_T_c3";

private _site = [_MissionPos, _radius, 3] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// Marked before anything is built. The ellipse and the task are the only things telling the
// player where the objective is, and the spawn-up below runs for tens of seconds.
_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;
private _VARtaskgeneratedName = format ["tower%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[_VARtaskgeneratedName, localize "STR_DUWS_T_dgpqenyw", _mission_name, _randomPos, "destroy"] call fnc_missionTaskCreate;

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn",[0,-2] select isDedicated];

_towerPos = _targetpos;


_centerSpawnX = _towerPos select 0;
_centerSpawnY = _towerPos select 1;

// --DUWS-COMPOSITION BEGIN name="Mission: Destroy Tower" schema=A--
_staticsArray = [];
switch (VERSION_X) do {
    case "MODERN": {
        _staticsArray = [
            ["Land_CratesWooden_F", -3.56738, -6.65527, 0, 269.589],
            ["CargoNet_01_barrels_F", 3.37939, -7.32568, 0, 0],
            ["Land_CratesWooden_F", -5.61475, -6.56982, 0, 269.589],
            ["CargoNet_01_barrels_F", 5.3335, -7.30029, 0, 0],
            ["Land_HBarrier_5_F", -3.70996, 8.57227, 0, 1.64537],
            ["Land_HBarrier_5_F", 2.06396, 8.42969, 0, 1.64537],
            ["Land_HBarrier_5_F", 10.0508, 1.10498, 0, 271.593],
            ["Land_HBarrier_5_F", -4.1333, -9.50635, 0, 179.745],
            ["Land_HBarrier_5_F", 9.91553, -4.47949, 0, 271.593],
            ["Land_HBarrier_5_F", 4.69043, -9.56396, 0, 179.745],
            ["Land_HBarrier_5_F", -10.3931, 2.490234, 0, 271.593],
            ["Land_HBarrier_5_F", -10.5269, -3.28467, 0, 271.593],
            ["Land_TBox_F", -0.117676, -14.9492, 0, 182.221]
        ];
// --DUWS-COMPOSITION END--
    };
};

_vehicle = objNull;
{
    _x params ["_class", "_posX", "_posY", "_posZ", "_dir"];
    _vehicle = createVehicle [_class, [0,0,0], [], 0, "CAN_COLLIDE"];
    _vehicle setDir _dir;
    _vehicle setPosATL [(_centerSpawnX)+_posX,(_centerSpawnY)+_posY,0];
    [_vehicle, "mission_destroy_tower"] call fnc_duws_keep;
} forEach _staticsArray;

_vehicle_7 = objNull;
switch (VERSION_X) do {
    case "MODERN": {
        _vehicle_7 = createVehicle ["Land_TTowerBig_2_F", [0,0,0], [], 0, "CAN_COLLIDE"];
        _vehicle_7 setDir 0;
        _vehicle_7 setPosATL [(_centerSpawnX), (_centerSpawnY), 0];
        _vehicle_7 setDamage 0.8;
        _vehicle_7 setVectorUp [0,0,1];
        [_vehicle_7, "mission_destroy_tower"] call fnc_duws_keep;
    };
};

[[_targetpos, _radius] call fnc_garrisonBuildings] call fnc_mission_claim;
sleep 1;
[_targetpos, _radius] spawn fnc_missionPatrolswithintel;


[_speaker1, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 12;
["", _message1] remoteExec ["fnc_duws_dialogue", 0];
sleep 12;
[_speaker, _message2] remoteExec ["fnc_duws_dialogue", 0];

sleep 5; // 等待巡逻队生成完毕


waitUntil {
    sleep 5;
    if ((time - _missionStartTime) >= (_taskTimeout_tower - 120) && !_hasShown2MinHint) then {
        [{hint localize "STR_DUWS_T_towerdecrypt"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
        _hasShown2MinHint = true;
    };
    !alive _vehicle_7 || (damage _vehicle_7) == 1 || (time - _missionStartTime) > _taskTimeout_tower
};


if ((alive _vehicle_7 && (damage _vehicle_7) < 1) && (time - _missionStartTime) > _taskTimeout_tower) exitWith {
    [{hint localize "STR_DUWS_T_xhtbpyl1"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [_VARtaskgeneratedName, "FAILED"] call fnc_missionTaskEnd;
    _speaker = localize "STR_DUWS_T_OVERLORD";
    _message = ([localize "STR_DUWS_T_towerfail"] call fnc_cs);
    [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
    [_markername2] call fnc_missionMarkerClear;
    [_targetpos,_radius, "mission_destroy_tower"] call fnc_mission_end;
};

[_markername2] call fnc_missionMarkerClear;

[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[_targetpos,_radius, "mission_destroy_tower"] call fnc_mission_end;
