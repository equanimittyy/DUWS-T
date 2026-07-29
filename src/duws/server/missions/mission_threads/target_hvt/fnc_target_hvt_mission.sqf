// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
if (!([2, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

// ========== 增援系统变量 ==========
private _varSuffix = format ["%1_%2", round(_MissionPos select 0), round(_MissionPos select 1)];
private _initialCountVar = format ["opf_initial_%1", _varSuffix];
private _triggeredVar = format ["opf_reinforce_%1", _varSuffix];
// ====================================
_radius = 600;
_cpreward = 35;
_apreward = 35;
_speaker = localize "STR_DUWS_T_OVERLORD";
_speaker1 = localize "STR_DUWS_T_Viper";
_message = localize "STR_DUWS_T_hvtletsdothis";
_message0 = localize "STR_DUWS_T_hvtseen";
_message1 = ([localize "STR_DUWS_T_hvtend"] call fnc_cs);

_taskTimeout = 480;
_missionStartTime = time;

_randomPos = [];
_Building = [];
_Posfound = false;
_targetpos = [];
_failSafe = 0;
_markerText2 = localize "STR_DUWS_T_c2";

_POSdata = [_MissionPos, _radius, _Posfound, _targetpos, _failSafe] call fnc_missionTargetPos;

_randomPos = _POSdata select 0;
_Building = _POSdata select 1;
_Posfound = _POSdata select 2;
_targetpos = _POSdata select 3;
_failSafe = _POSdata select 4;

if (_failsafe > 5 && _Posfound == false) exitWith {
    Mission_available = true;
    publicVariable "Mission_available";
    [{hint localize "STR_DUWS_T_crtzxs0j"}] remoteExec ["BIS_fnc_Spawn", 0];
};

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn",  player1];

_vehpos = [_targetpos, 10, 30,10,0,0.1,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;

_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;

sleep 1;
[_targetpos, _radius] spawn fnc_missionPatrolswithintel;

// Create Statics
// The objective itself: kept for the mission's duration so the abandoned-vehicle clause
// cannot collect it. A player who disables it and takes half an hour would otherwise find
// the thing they were sent for gone, with no way left to finish.
_apc = opfor_APC1_X createVehicle (_vehpos);
[_apc, "mission_target_hvt"] call fnc_duws_keep;

_static1 = "";
_static2 = "";
_static3 = "";
switch (VERSION_X) do {
    case "MODERN": {
        _static1 = "VirtualReammoBox_camonet_F";
        _static2 = "CargoNet_01_barrels_F";
        _static3 = "CamoNet_INDP_open_F";
    };
};
_obj1 = createVehicle [_static1, [(_targetpos select 0)+1, (_targetpos select 1)+1], [], 0, "CAN_COLLIDE"];
[_obj1, "mission_target_hvt"] call fnc_duws_keep;
sleep 1;
_obj2 = createVehicle [_static2, [(_targetpos select 0)-2, (_targetpos select 1)-2], [], 0, "CAN_COLLIDE"];
[_obj2, "mission_target_hvt"] call fnc_duws_keep;
sleep 1;
_obj3 = createVehicle [_static3, _targetpos, [], 0, "CAN_COLLIDE"];
[_obj3, "mission_target_hvt"] call fnc_duws_keep;
sleep 1;

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

// TASK AND NOTIFICATION
private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["rescue%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_VARtaskgeneratedName, localize "STR_DUWS_T_19ajhe1d", _mission_name, _randomPos, "kill"] call fnc_missionTaskCreate;
 [_speaker1, _message0] remoteExec ["fnc_duws_dialogue", 0];

// CREATE THE HVT GROUP
_group = [_targetpos, EAST, [opfor_OFFICER_X, opfor_OPERATOR_X, opfor_MARK_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
_target = units _group select 0;

// 为军官添加黑贝雷帽
[_target] spawn {
    params ["_unit"];
    sleep 5;
    _unit addHeadgear "H_Beret_blk";
};
// 为军官添加机密情报
[_target] spawn {
    params ["_unit"];
    sleep 5;
    _unit addMagazineGlobal "FileTopSecret";
};
_wp = _group addWaypoint [_vehpos, 0];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointTimeout [30, 45, 60];

_wp = _group addWaypoint [_targetpos, 0];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointTimeout [30, 45, 60];

// 检查 _Building 是否为对象，如果是数组则跳过此路点
if (_Building isEqualType objNull) then {
    _posBuilding = getpos _Building;
    _wp = _group addWaypoint [_posBuilding, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointBehaviour "SAFE";
    _wp setWaypointTimeout [30, 45, 60];
} else {
    ["WARN", "MISSION", "_Building is not an object, skipping waypoint."] call fnc_log;
};

_wp2 = _group addWaypoint [[(_targetpos select 0)+10, (_targetpos select 1)+10], 0];
_wp2 setWaypointType "CYCLE";
_wp2 setWaypointBehaviour "SAFE";
_wp2 setWaypointTimeout [30, 45, 60];

// ========== 添加死亡情报动作 ==========
{
    if (!isNull _x) then {
        [_x] call fnc_add_intel_to_group;
    };
} forEach [_group, _buildingGroup];
// ====================================

{
    [_x] call fnc_addRandomLoot;
} forEach units _group;

{
    [_x] call fnc_addRandomLoot;
} forEach units _buildingGroup;

// 设置任务目标位置（HVT 位置）
missionNamespace setVariable ["current_mission_target_pos", getPos _target];
["info", [localize "STR_DUWS_T_SEARCH_CORPSE", localize "STR_DUWS_T_sidemissionloc"]] remoteExec ["BIS_fnc_showNotification", 0];

// ========== 统计初始敌军数量 ==========
sleep 5; // 等待巡逻队生成完毕
private _nearbyEnemies = _targetpos nearEntities [["CAManBase", "LandVehicle", "Air"], _radius * 1.5] select { side _x == EAST };
private _initialEnemyCount = count _nearbyEnemies;
missionNamespace setVariable [_initialCountVar, _initialEnemyCount, true];
missionNamespace setVariable [_triggeredVar, false, true];
["INFO", "ZONES", format ["%1: Initial enemy count = %2", _mission_name, _initialEnemyCount]] call fnc_log;

// ========== 启动直升机增援监控 ==========
[_targetpos, _radius, _initialCountVar, _triggeredVar, _VARtaskgeneratedName] spawn fnc_opf_heli_reinforce;
// ======================================

waitUntil {sleep 0.5; !alive _target || (time - _missionStartTime) > _taskTimeout};

if (alive _target && (time - _missionStartTime) > _taskTimeout) exitWith {
    [{hint localize "STR_DUWS_T_abc1abc2"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [_VARtaskgeneratedName, "FAILED"] call fnc_missionTaskEnd;
    [] spawn fnc_missionTimer;
    deleteMarker str(_markername2);
    missionNamespace setVariable [_triggeredVar, true, true];
    [_targetpos,_radius, "mission_target_hvt"] spawn fnc_mission_cleanup;
    missionNamespace setVariable ["current_mission_target_pos", nil];
};

sleep 120;

[_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
deleteMarker str(_markername2);

[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;

sleep 1;

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[] spawn fnc_missionTimer;

// 清理其他任务物体（APC 不在其中）

missionNamespace setVariable [_triggeredVar, true, true];
[_targetpos,_radius, "mission_target_hvt"] spawn fnc_mission_cleanup;

missionNamespace setVariable ["current_mission_target_pos", nil];