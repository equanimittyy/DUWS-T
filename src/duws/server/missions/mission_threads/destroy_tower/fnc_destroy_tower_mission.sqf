// Locality: server -- callers remoteExec to target 2.
// 任务冷却检查
private _missionType = 3;
private _cooldownVar = missionNamespace getVariable [format ["mission_cooldown_%1", _missionType], 0];
if (_cooldownVar > diag_tickTime) then {
    private _remaining = _cooldownVar - diag_tickTime;
    private _minutes = floor (_remaining / 60);
    private _seconds = _remaining % 60;
    hint format [localize "STR_DUWS_T_MISSION_COOLDOWN", _minutes, _seconds];
    if (isNil "fnc_scriptName") then {
        breakOut "main";
    } else {
        if (true) exitWith {};
    };
};
mission_cooldown_3 = diag_tickTime + 3600;
publicVariable format ["mission_cooldown_3", _missionType];
params ["_MissionPos", "_mission_name"];

// ========== 增援系统变量 ==========
private _varSuffix = format ["%1_%2", round(_MissionPos select 0), round(_MissionPos select 1)];
private _initialCountVar = format ["opf_initial_%1", _varSuffix];
private _triggeredVar = format ["opf_reinforce_%1", _varSuffix];
// ====================================

Mission_available = false;
publicVariable "Mission_available";

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

_randomPos = [];
_Building = [];
_Posfound = false;
_targetpos = [];
_failSafe = 0;
_markerText = "tower";
_markerText2 = localize "STR_DUWS_T_c3";

_POSdata = [_MissionPos, _radius, _Posfound, _targetpos, _failSafe] call fnc_missionTargetPos;

_randomPos = _POSdata select 0;
_Building = _POSdata select 1;
_Posfound = _POSdata select 2;
_targetpos = _POSdata select 3;
_failSafe = _POSdata select 4;

if (_failsafe > 10 && _Posfound == false) exitWith {
    Mission_available = true;
    publicVariable "Mission_available";
    [{hint localize "STR_DUWS_T_crtzxs0j"}] remoteExec ["BIS_fnc_Spawn", 0];
};

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn",player1];

_towerPos = _targetpos;

_markerData = [_randomPos, _markerText, _markerText2, _radius] call fnc_missionMarkerData;
_markername = _markerData select 0;
_markername2 = _markerData select 1;

_centerSpawn = _towerPos;
_centerSpawnX = _towerPos select 0;
_centerSpawnY = _towerPos select 1;

_vehicle_0 = objNull;
_this = createVehicle ["Land_MultiMeter_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
_vehicle_0 = _this;
_this setPos _centerSpawn;
_centerSpawnZ = (getpos _vehicle_0 select 2);
deleteVehicle _vehicle_0;

private _missionObjects = [];

// --DUWS-COMPOSITION BEGIN name="Mission: Destroy Tower" schema=C--
_staticsArray = [];
switch (VERSION_X) do {
    case "MODERN": {
        _staticsArray = [
            ["Land_CratesWooden_F",[-3.56738,-6.65527,0],269.589,1,0,[],"","",true,false],
            ["CargoNet_01_barrels_F",[3.37939,-7.32568,0],0,1,0,[],"","",true,false],
            ["Land_CratesWooden_F",[-5.61475,-6.56982,0],269.589,1,0,[],"","",true,false],
            ["CargoNet_01_barrels_F",[5.3335,-7.30029,0],0,1,0,[],"","",true,false],
            ["Land_HBarrier_5_F",[-3.70996,8.57227,0],1.64537,1,0,[],"","",true,false],
            ["Land_HBarrier_5_F",[2.06396,8.42969,0],1.64537,1,0,[],"","",true,false],
            ["Land_HBarrier_5_F",[10.0508,1.10498,0],271.593,1,0,[],"","",true,false],
            ["Land_HBarrier_5_F",[-4.1333,-9.50635,0],179.745,1,0,[],"","",true,false],
            ["Land_HBarrier_5_F",[9.91553,-4.47949,0],271.593,1,0,[],"","",true,false],
            ["Land_HBarrier_5_F",[4.69043,-9.56396,0],179.745,1,0,[],"","",true,false],
            ["Land_HBarrier_5_F",[-10.3931,2.490234,0],271.593,1,0,[],"","",true,false],
            ["Land_HBarrier_5_F",[-10.5269,-3.28467,0],271.593,1,0,[],"","",true,false],
            ["Land_TBox_F",[-0.117676,-14.9492,0],182.221,1,0,[],"","",true,false]
        ];
// --DUWS-COMPOSITION END--
    };
};

_vehicle = objNull;
{
    _xyz = (_x select 1);
    _posX = (_xyz select 0);
    _posY = (_xyz select 1);
    _posZ = (_xyz select 2);
    _vehicle = createVehicle [(_x select 0), [0,0,0], [], 0, "CAN_COLLIDE"];
    _vehicle setDir (_x select 2);
    _vehicle setPosATL [(_centerSpawnX)+_posX,(_centerSpawnY)+_posY,0];
    _missionObjects pushBack _vehicle;
} forEach _staticsArray;

_vehicle_7 = objNull;
switch (VERSION_X) do {
    case "MODERN": {
        _vehicle_7 = createVehicle ["Land_TTowerBig_2_F", [0,0,0], [], 0, "CAN_COLLIDE"];
        _vehicle_7 setDir 0;
        _vehicle_7 setPosATL [(_centerSpawnX), (_centerSpawnY), 0];
        _vehicle_7 setDamage 0.8;
        _vehicle_7 setVectorUp [0,0,1];
        _missionObjects pushBack _vehicle_7;
    };
};

// 建筑驻军
private _buildingSearchRadius = _radius;
private _usableBuildings = [_targetpos, 2, _buildingSearchRadius] call fnc_usableBuildings;
private _desiredBldgCount = 6;
private _actualBldgCount = count _usableBuildings;
private _buildingGroup = grpNull;

if (_actualBldgCount > 0) then {
    private _maxBuildingsToUse = (_actualBldgCount min _desiredBldgCount);
    private _selectedBuildings = [];
    if (_actualBldgCount == _maxBuildingsToUse) then {
        _selectedBuildings = _usableBuildings;
    } else {
        private _tempArray = +_usableBuildings;
        for "_i" from 1 to _maxBuildingsToUse do {
            private _index = floor (random (count _tempArray));
            _selectedBuildings pushBack (_tempArray select _index);
            _tempArray deleteAt _index;
        };
    };

    private _unitsPerBuilding = 4;
    private _totalUnitsToSpawn = _maxBuildingsToUse * _unitsPerBuilding;

    private _possibleUnitTypes = [];
    {
        if (!isNil "_x" && {_x != ""}) then {
            _possibleUnitTypes pushBack _x;
        };
    } forEach [
        opfor_SOLDIER_X,
        opfor_AA_SOLDIER_X,
        opfor_AR_SOLDIER_X,
        opfor_AT_SOLDIER_X,
        opfor_LAT_SOLDIER_X,
        opfor_SL_SOLDIER_X
    ];
    if (count _possibleUnitTypes == 0) then {
        _possibleUnitTypes = [opfor_SOLDIER_X];
    };

    private _bldgUnits = [];
    for "_i" from 1 to _totalUnitsToSpawn do {
        _bldgUnits pushBack (selectRandom _possibleUnitTypes);
    };
    _buildingGroup = [[0,0], EAST, _bldgUnits,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
    _buildingGroup deleteGroupWhenEmpty true;

    {
        if (_forEachIndex >= _maxBuildingsToUse) exitWith {};
        private _building = _x;
        private _positions = [_building] call BIS_fnc_buildingPositions;
        for "_j" from 0 to (_unitsPerBuilding - 1) do {
            private _unitIndex = _forEachIndex * _unitsPerBuilding + _j;
            if (_unitIndex >= count (units _buildingGroup)) exitWith {};
            private _unit = units _buildingGroup select _unitIndex;
            if (count _positions > 0) then {
                private _randPosIndex = floor (random (count _positions));
                _unit setPosATL (_building buildingPos _randPosIndex);
                _unit setUnitPos "AUTO";
                _unit setBehaviour "AWARE";
                [_unit, _building, _positions] spawn {
                    params ["_unit", "_building", "_positions"];
                    sleep 2 + random 5;
                    private _buildingPos = getPosATL _building;
                    while {alive _unit} do {
                        if (_unit distance _buildingPos > 15 && count _positions > 0) then {
                            private _returnPos = selectRandom _positions;
                            _unit doMove _returnPos;
                        };
                        if (count _positions > 0) then {
                            private _targetPosIndex = floor (random (count _positions));
                            private _targetPos = _building buildingPos _targetPosIndex;
                            _unit doMove _targetPos;
                            _unit setUnitPos "AUTO";
                            private _timeout = time + 30;
                            waitUntil {
                                sleep 5;
                                (unitReady _unit) ||
                                (!alive _unit) ||
                                (_unit distance _targetPos < 2) ||
                                (time > _timeout)
                            };
                            sleep 5 + random 5;
                        } else {
                            sleep 5 + random 5;
                        };
                    };
                };
            };
        };
    } forEach _selectedBuildings;
};

{
    if (!isNull _x) then {
        [_x] call fnc_add_intel_to_group;
    };
} forEach [_buildingGroup];
{
    [_x] call fnc_addRandomLoot;
} forEach units _buildingGroup;
sleep 1;
[_targetpos, _radius] spawn fnc_missionPatrolswithintel;

private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["tower%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];

[_speaker1, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 12;
["", _message1] remoteExec ["BIS_fnc_showSubtitle", 0];
sleep 12;
[_speaker, _message2] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
[west, [_VARtaskgeneratedName],
[localize "STR_DUWS_T_dgpqenyw", _mission_name, "(getMarkerPos str(_markername))"], objNull, true] call BIS_fnc_taskCreate;

missionNamespace setVariable ["current_mission_target_pos", getPos _vehicle_7];
["info", [localize "STR_DUWS_T_SEARCH_CORPSE", localize "STR_DUWS_T_sidemissionloc"]] remoteExec ["BIS_fnc_showNotification", 0];

// ========== 统计初始敌军数量 ==========
sleep 5; // 等待巡逻队生成完毕
private _nearbyEnemies = _targetpos nearEntities [["CAManBase", "LandVehicle", "Air"], _radius * 1.5] select { side _x == EAST };
private _initialEnemyCount = count _nearbyEnemies;
missionNamespace setVariable [_initialCountVar, _initialEnemyCount, true];
missionNamespace setVariable [_triggeredVar, false, true];
diag_log format ["[Reinforce] %1: Initial enemy count = %2", _mission_name, _initialEnemyCount];

// ========== 启动直升机增援监控 ==========
[_targetpos, _radius, _initialCountVar, _triggeredVar, _VARtaskgeneratedName] spawn fnc_opf_heli_reinforce;
// ======================================

waitUntil {
    sleep 5;
    if ((time - _missionStartTime) >= (_taskTimeout_tower - 120) && !_hasShown2MinHint) then {
        [{hint localize "STR_DUWS_T_xinhaopy"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
        _hasShown2MinHint = true;
    };
    !alive _vehicle_7 || (damage _vehicle_7) == 1 || (time - _missionStartTime) > _taskTimeout_tower
};

[_missionObjects] spawn {
    params ["_objects"];
    sleep 360;
    {
        if (!isNull _x) then {
            deleteVehicle _x;
        };
    } forEach _objects;
};

if ((alive _vehicle_7 && (damage _vehicle_7) < 1) && (time - _missionStartTime) > _taskTimeout_tower) exitWith {
    [{hint localize "STR_DUWS_T_xhtbpyl1"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [_VARtaskgeneratedName, "FAILED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated,true];
    _speaker = localize "STR_DUWS_T_OVERLORD";
    _message = ([localize "STR_DUWS_T_towerfail"] call fnc_cs);
    [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
    deleteMarker str(_markername2);
    deleteMarker str(_markername);
    [] spawn fnc_missionTimer;
    missionNamespace setVariable [_triggeredVar, true, true];
    [_targetpos,_radius] spawn fnc_mission_cleanup;
    missionNamespace setVariable ["current_mission_target_pos", nil];
};

deleteMarker str(_markername2);
deleteMarker str(_markername);

[_VARtaskgeneratedName, "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated,true];

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[] spawn fnc_missionTimer;
missionNamespace setVariable [_triggeredVar, true, true];
[_targetpos,_radius] spawn fnc_mission_cleanup;

missionNamespace setVariable ["current_mission_target_pos", nil];