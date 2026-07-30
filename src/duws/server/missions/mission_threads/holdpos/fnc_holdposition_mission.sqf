// Locality: server; the trigger bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).
params ["_MissionPos", "_mission_name"];
if (!([12, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

_radius = 300;
_cpreward = 30;
_apreward = 35;

_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_ENEMY_APPROACHING";
_speaker1 = localize "STR_DUWS_T_Express";
_speaker2 = localize "STR_DUWS_T_Scout";
_speaker3 = localize "STR_DUWS_T_Rein";
_message1 = localize "STR_DUWS_T_ENEMY_APPROACHING1";
_message2 = localize "STR_DUWS_T_ENEMY_APPROACHING2";
_message3 = localize "STR_DUWS_T_ENEMY_APPROACHING3";
_message4 = localize "STR_DUWS_T_ENEMY_APPROACHING4";
_message5 = localize "STR_DUWS_T_ENEMY_APPROACHING5";

_countdownDuration = 550;

_markerText2 = localize "STR_DUWS_T_c12";

private _site = [_MissionPos, _radius, 12] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

[_markerText2, {hint _this}] remoteExec ["BIS_fnc_Spawn", 0];

_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;

_centerSpawn = _targetpos;
_centerSpawnX = _centerSpawn select 0;
_centerSpawnY = _centerSpawn select 1;

_centerSpawnZ = 0;
_intersections = lineIntersectsSurfaces [
    [_centerSpawnX, _centerSpawnY, 1000],
    [_centerSpawnX, _centerSpawnY, 0],
    objNull, objNull, true, 1, "GEOM"
];
if (count _intersections > 0) then {
    _intersection = _intersections select 0;
    _centerSpawnZ = (_intersection select 0) select 2;
} else {
    _centerSpawnZ = getTerrainHeightASL _centerSpawn;
};

// ========== 初始化数组记录任务生成的物体 ==========
_missionUnits = [];

_samSystem = createVehicle ["B_SAM_System_03_F", [0,0,0], [], 0, "CAN_COLLIDE"];
_samSystem setDir 0;
_samSystem setPosATL [(_centerSpawnX)-3.23633, (_centerSpawnY)+1.296875, 0];
_samSystem setVariable ["R3F_LOG_disabled", true];
[_samSystem, "mission_holdpos"] call fnc_duws_keep;

_radarSystem = createVehicle ["B_Radar_System_01_F", [0,0,0], [], 0, "CAN_COLLIDE"];
_radarSystem setDir 0;
_radarSystem setPosATL [(_centerSpawnX)+3.23633, (_centerSpawnY)-1.296875, 0];
_radarSystem setVariable ["R3F_LOG_disabled", true];
[_radarSystem, "mission_holdpos"] call fnc_duws_keep;

_samGroup = createGroup WEST;
_samOperator = _samGroup createUnit ["B_UAV_AI", [0,0,0], [], 0, "CAN_COLLIDE"];
_samOperator moveInGunner _samSystem;
_samGroup deleteGroupWhenEmpty true;
_missionUnits pushBack _samOperator;

_radarGroup = createGroup WEST;
_radarOperator = _radarGroup createUnit ["B_UAV_AI", [0,0,0], [], 0, "CAN_COLLIDE"];
_radarOperator moveInGunner _radarSystem;
_radarGroup deleteGroupWhenEmpty true;
_missionUnits pushBack _radarOperator;

_samOperator setBehaviour "AWARE";
_samOperator setCombatMode "RED";
_radarOperator setBehaviour "AWARE";
_radarOperator setCombatMode "RED";

_samOperator disableAI "PATH";
_samOperator disableAI "TARGET";
_samOperator disableAI "AUTOTARGET";
_samOperator disableAI "AUTOCOMBAT";
_samOperator disableAI "WEAPONAIM";
_radarOperator disableAI "PATH";
_radarOperator disableAI "TARGET";
_radarOperator disableAI "AUTOTARGET";
_radarOperator disableAI "AUTOCOMBAT";
_radarOperator disableAI "WEAPONAIM";

_samOperator setVariable ["BIS_fnc_setUnitInsignia_class", "StayInVehicle", true];
_radarOperator setVariable ["BIS_fnc_setUnitInsignia_class", "StayInVehicle", true];

// --DUWS-COMPOSITION BEGIN name="Mission: Hold Position" schema=C--
_staticsArray = [
	["Land_HBarrier_5_F",[-6.48291,-3.77783,0],49.5237,1,0,[],"","",true,false], 
	["Land_HBarrier_5_F",[-8.11426,1.68848,0],88.8804,1,0,[],"","",true,false], 
	["Land_HBarrier_5_F",[1.946484,-8.04492,0],0.520331,1,0,[],"","",true,false], 
	["Land_HBarrier_5_F",[-0.718359,8.46387,0],183.745,1,0,[],"","",true,false], 
	["Land_HBarrier_5_F",[3.80957,6.41455,0],45.2709,1,0,[],"","",true,false], 
	["Land_HBarrier_5_F",[9.2251,-1.25684,0],269.491,1,0,[],"","",true,false], 
	["Land_BagBunker_Small_F",[-7.08691,7.32031,0],134.261,1,0,[],"","",true,false], 
	["Land_BagBunker_Small_F",[8.24512,-6.67188,0],314.617,1,0,[],"","",true,false]
];
// --DUWS-COMPOSITION END--

_vehicle = objNull;
{
	_xyz = (_x select 1);
	_posX = (_xyz select 0);
	_posY = (_xyz select 1);
	_posZ = (_xyz select 2);
	_vehicle = createVehicle [(_x select 0), [0,0,0], [], 0, "CAN_COLLIDE"];
	_vehicle setDir (_x select 2);
	_vehicle setPosATL [(_centerSpawnX)+_posX,(_centerSpawnY)+_posY,0];
	[_vehicle, "mission_holdpos"] call fnc_duws_keep;
} forEach _staticsArray;

_vehicle_9 = objNull;
_vehicle_9 = createVehicle ["I_HMG_02_high_F", [0,0,0], [], 0, "CAN_COLLIDE"];
[_vehicle_9, "mission_holdpos"] call fnc_duws_keep;
_vehicle_9 setDir 314.218;
_vehicle_9 setPosATL [(_centerSpawnX)-5.52539, (_centerSpawnY)+5.98193, 0];
_vehicle_9 setdamage 0;

_vehicle_10 = objNull;
_vehicle_10 = createVehicle ["I_HMG_02_high_F", [0,0,0], [], 0, "CAN_COLLIDE"];
[_vehicle_10, "mission_holdpos"] call fnc_duws_keep;
_vehicle_10 setDir 136.703;
_vehicle_10 setPosATL [(_centerSpawnX)+6.7168, (_centerSpawnY)-5.49365, 0];
_vehicle_10 setdamage 0;

_vehicle_11 = objNull;
_vehicle_11 = createVehicle ["B_Mortar_01_F", [0,0,0], [], 0, "CAN_COLLIDE"];
[_vehicle_11, "mission_holdpos"] call fnc_duws_keep;
_vehicle_11 setDir 136.703;
_vehicle_11 setPosATL [(_centerSpawnX)+0.01, (_centerSpawnY)-4.49365, 0];
_vehicle_11 setdamage 0;
_vehicle_11 setVehicleAmmo 0.3;

_groupBunker1 = [getpos _vehicle_9, WEST, [blufor_SOLDIER_X],[],[],blufor_ai_skill] call BIS_fnc_spawnGroup;
_groupBunker1 deleteGroupWhenEmpty true;
_groupBunker2 = [getpos _vehicle_10, WEST, [blufor_SOLDIER_X],[],[],blufor_ai_skill] call BIS_fnc_spawnGroup;
_groupBunker2 deleteGroupWhenEmpty true;
_guard1 = units _groupBunker1 select 0;
_guard2 = units _groupBunker2 select 0;
_guard1 moveinGunner _vehicle_9;
_guard2 moveinGunner _vehicle_10;
_vehicle_9 setDir( [_centerSpawnX,_centerSpawnY] getDir getPosWorld _vehicle_9);
_vehicle_10 setDir( [_centerSpawnX,_centerSpawnY] getDir getPosWorld _vehicle_10);
_missionUnits pushBack _guard1;
_missionUnits pushBack _guard2;

[_guard2] joinSilent _groupBunker1;

["HOLD POSITION",{hint _this}] remoteExec ["BIS_fnc_Spawn",  player1];

sleep 2;

private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["HOLDPOSITION%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];

[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 10;

[_VARtaskgeneratedName, localize "STR_DUWS_T_jianshouzhendi2", _mission_name, _randomPos, "defend"] call fnc_missionTaskCreate; 

_friendlyUnits = [];
_friendlyGroup = [(_targetpos getPos [8, random 360]), WEST, [
    blufor_SOLDIER_GL_X,
    blufor_SOLDIER_AR_X,
    blufor_SOLDIER_AR_X,
    blufor_SOLDIER_SL_X,
    blufor_SOLDIER_TL_X,
    blufor_MARKSMAN_X,
    blufor_SOLDIER_LAT_X
]] call BIS_fnc_spawnGroup;

_friendlyUnits = units _friendlyGroup;

{
    _unitPos = [
        _centerSpawnX + (random 16) - 8,
        _centerSpawnY + (random 16) - 8,
        0
    ];
    _x setPosATL _unitPos;
    _x setDir random 360;
    _x disableAI "PATH";
    _missionUnits pushBack _x;   // 记录友军单位
} forEach _friendlyUnits;

_friendlyGroup setFormation "DIAMOND";
_friendlyGroup setBehaviour "COMBAT";
_friendlyGroup setCombatMode "RED";
_friendlyGroup deleteGroupWhenEmpty true;

// ========== 创建触发器，等待任意玩家进入任务区域 ==========
_startTrigger = createTrigger ["EmptyDetector", _targetpos];
_startTrigger setTriggerArea [_radius, _radius, 0, false];
_startTrigger setTriggerActivation ["ANYPLAYER", "PRESENT", false];
_startTrigger setTriggerStatements ["this", "", ""]; // 空语句，在线程中等待

missionNamespace setVariable [format ["%1_started", _VARtaskgeneratedName], false];
publicVariable format ["%1_started", _VARtaskgeneratedName];

// 等待线程
[_startTrigger, _VARtaskgeneratedName] spawn {
    params ["_trg", "_taskName"];
    waitUntil { sleep 1; triggerActivated _trg };
    missionNamespace setVariable [format ["%1_startTime", _taskName], time];
    missionNamespace setVariable [format ["%1_started", _taskName], true];
    deleteVehicle _trg;
};

// ================ 任务完成条件检查线程 ================
Mission_Active = true;
publicVariable "Mission_Active";

_conditionCheckThread = [_samSystem, _radarSystem, _countdownDuration, _markername2, _VARtaskgeneratedName, _cpreward, _apreward, _mission_name, _targetpos, _radius, _missionUnits] spawn {
    params ["_samSystem", "_radarSystem", "_countdownDuration", "_markername2", "_VARtaskgeneratedName", "_cpreward", "_apreward", "_mission_name", "_targetpos", "_radius", "_missionUnits"];

    waitUntil { sleep 1; missionNamespace getVariable [format ["%1_started", _VARtaskgeneratedName], false] };
    private _missionStartTime = missionNamespace getVariable [format ["%1_startTime", _VARtaskgeneratedName], time];

    while {true} do {
        sleep 5;
        if ((!alive _samSystem || !alive _radarSystem) && ((time - _missionStartTime) < _countdownDuration)) exitWith {
            deleteMarker str(_markername2);
            [_VARtaskgeneratedName, "FAILED"] call fnc_missionTaskEnd;
            [_targetpos,_radius, "mission_holdpos", true] call fnc_mission_end;
            Mission_Active = false;
            publicVariable "Mission_Active";
            // 延迟 300 秒删除所有任务物体和单位
            // Handed to the map cleanup instead of deleted on a private timer: the same wait, but
            // the sweep holds anything a player is still standing near, so a finished objective does
            // not dissolve in front of whoever is looting it.
            { deleteVehicle _x } forEach _missionUnits;
        };
        if ((time - _missionStartTime) >= _countdownDuration) exitWith {
            deleteMarker str(_markername2);
            [_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;
            sleep 1;
            [_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
            [_targetpos,_radius, "mission_holdpos", true] call fnc_mission_end;
            Mission_Active = false;
            publicVariable "Mission_Active";
            // 延迟 300 秒删除所有任务物体和单位
            // Handed to the map cleanup instead of deleted on a private timer: the same wait, but
            // the sweep holds anything a player is still standing near, so a finished objective does
            // not dissolve in front of whoever is looting it.
            { deleteVehicle _x } forEach _missionUnits;
        };
    };
};

// ================ 部队生成线程（等待玩家进入后开始） ================
[_targetpos, _radius, _speaker1, _speaker2, _speaker3, _message1, _message2, _message3, _message4, _message5, _VARtaskgeneratedName] spawn {
    params ["_targetpos", "_radius", "_speaker1", "_speaker2", "_speaker3", "_message1", "_message2", "_message3", "_message4", "_message5", "_taskName"];

    waitUntil { sleep 1; missionNamespace getVariable [format ["%1_started", _taskName], false] };

    _fn_waterproofOpforGroup = {
        params ["_targetpos", "_spawnDistance"];
        private ["_spawnPos", "_attempts", "_validPos"];
        _attempts = 0;
        _validPos = false;
        while {_attempts < 30 && !_validPos} do {
            _randomAngle = random 360;
            _spawnPos = _targetpos getPos [_spawnDistance, _randomAngle];
            if (!surfaceIsWater _spawnPos) then { _validPos = true; };
            _attempts = _attempts + 1;
            sleep 1;
        };
        if (!_validPos) then {
            _randomAngle = random 360;
            _spawnPos = _targetpos getPos [_spawnDistance, _randomAngle];
        };
        _groundPos = _spawnPos;
        _groundPos set [2, 0];
        _opforGroup = [_groundPos, EAST, [
            opfor_SOLDIER_X, opfor_SOLDIER_X,           
            opfor_AR_SOLDIER_X, opfor_AA_SOLDIER_X,     
            opfor_LAT_SOLDIER_X, opfor_AR_SOLDIER_X,    
            opfor_GL_SOLDIER_X, opfor_AR_SOLDIER_X      
        ]] call BIS_fnc_spawnGroup;
        {
        [_x] call fnc_addRandomLoot;
        } forEach units _opforGroup;
        {
            _x allowFleeing 0;
            _x disableAI "AUTOCOMBAT";
            _x setBehaviour "AWARE";
            _x setCombatMode "RED";
        } forEach units _opforGroup;
        _opforGroup deleteGroupWhenEmpty true;
        _wp = _opforGroup addWaypoint [_targetpos, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointBehaviour "AWARE";
        _wp setWaypointCombatMode "RED";
        _wp setWaypointSpeed "FULL";
        _wp setWaypointFormation "LINE";
        _opforGroup
    };

    _fn_waterproofBluforGroup = {
        params ["_targetpos", "_spawnDistance"];
        private ["_spawnPos", "_attempts", "_validPos"];
        _attempts = 0;
        _validPos = false;
        while {_attempts < 30 && !_validPos} do {
            _randomAngle = random 360;
            _spawnPos = _targetpos getPos [_spawnDistance, _randomAngle];
            if (!surfaceIsWater _spawnPos) then { _validPos = true; };
            _attempts = _attempts + 1;
            sleep 1;
        };
        if (!_validPos) then {
            _randomAngle = random 360;
            _spawnPos = _targetpos getPos [_spawnDistance, _randomAngle];
        };
        _groundPos = _spawnPos;
        _groundPos set [2, 0];
        _bluforGroup = [_groundPos, WEST, [
            blufor_SOLDIER_AR_X, blufor_SOLDIER_AR_X,
            blufor_SOLDIER_AR_X, blufor_SOLDIER_AR_X,
            blufor_SOLDIER_LAT_X, blufor_SOLDIER_LAT_X,
            blufor_SOLDIER_GL_X, blufor_SOLDIER_GL_X
        ]] call BIS_fnc_spawnGroup;
        {
            _x allowFleeing 0;
            _x disableAI "AUTOCOMBAT";
            _x setBehaviour "AWARE";
            _x setCombatMode "RED";
        } forEach units _bluforGroup;
        _bluforGroup deleteGroupWhenEmpty true;
        _wp = _bluforGroup addWaypoint [_targetpos, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointBehaviour "AWARE";
        _wp setWaypointCombatMode "RED";
        _wp setWaypointSpeed "FULL";
        _wp setWaypointFormation "LINE";
        _bluforGroup
    };

    [_speaker1, _message1] remoteExec ["fnc_duws_dialogue", 0];
    sleep 10;
    [localize "STR_DUWS_T_Express", localize "STR_DUWS_T_ENEMY_APPROACHINGcm"] remoteExec ["fnc_duws_dialogue", 0];
    sleep 10;
    if (!Mission_Active) exitWith {};
    [_speaker2, _message2] remoteExec ["fnc_duws_dialogue", 0];
    sleep 30;
    for "_i" from 1 to 3 do {
        if (!Mission_Active) exitWith {};
        [_targetpos, 300] call _fn_waterproofOpforGroup;
        sleep 1;
    };
    sleep 20;
    [_speaker1, localize "STR_DUWS_T_ENEMY_APPROACHING1p1"] remoteExec ["fnc_duws_dialogue", 0];
    sleep 50;
    if (!Mission_Active) exitWith {};
    sleep 70;
    if (!Mission_Active) exitWith {};
    for "_i" from 1 to 2 do {
        if (!Mission_Active) exitWith {};
        [_targetpos, 300] call _fn_waterproofOpforGroup;
        sleep 1;
    };
    sleep 30;
    if (!Mission_Active) exitWith {};
    [_speaker1, _message3] remoteExec ["fnc_duws_dialogue", 0];
    sleep 70;
    if (!Mission_Active) exitWith {};
    for "_i" from 1 to 2 do {
        if (!Mission_Active) exitWith {};
        [_targetpos, 300] call _fn_waterproofOpforGroup;
        sleep 1;
    };
    sleep 80;
    if (!Mission_Active) exitWith {};
    for "_i" from 1 to 2 do {
        if (!Mission_Active) exitWith {};
        [_targetpos, 300] call _fn_waterproofOpforGroup;
        sleep 1;
    };
    if (!Mission_Active) exitWith {};
    [_speaker3, _message4] remoteExec ["fnc_duws_dialogue", 0];
    sleep 30;
    if (!Mission_Active) exitWith {};
    for "_i" from 1 to 3 do {
        if (!Mission_Active) exitWith {};
        [_targetpos, 300] call _fn_waterproofBluforGroup;
        sleep 2;
    };
    [_speaker3, _message5] remoteExec ["fnc_duws_dialogue", 0];
};