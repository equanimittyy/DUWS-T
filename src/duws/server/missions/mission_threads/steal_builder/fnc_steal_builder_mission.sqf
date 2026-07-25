// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];

// Ahead of fnc_mission_begin: a builder still standing means the last one was never
// collected, and refusing after the launcher would stamp a full hour of cooldown for a
// mission that never started.
if (!isNil "BLD1" && {alive BLD1}) exitWith {
    [{hint localize "STR_DUWS_T_mfxb090t"}] remoteExec ["BIS_fnc_Spawn", 0];
    ["INFO", "MISSION", "steal_builder refused: previous builder still alive"] call fnc_log;
};

if (!([6, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

_cpreward = 15;
_apreward = 15;

// ========== 增援系统变量 ==========
private _varSuffix = format ["%1_%2", round(_MissionPos select 0), round(_MissionPos select 1)];
private _initialCountVar = format ["opf_initial_%1", _varSuffix];
private _triggeredVar = format ["opf_reinforce_%1", _varSuffix];
// ====================================

_radius = 500;

_randomPos = [];
_Building = [];
_Posfound = false;
_targetpos = [];
_failSafe = 0;
_markerText = "recov";
_markerText2 = localize "STR_DUWS_T_c6";

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

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn", 0];

_vehpos = _targetpos;

_markerData = [_randomPos, _markerText, _markerText2, _radius] call fnc_missionMarkerData;
_markername = _markerData select 0;
_markername2 = _markerData select 1;

// CREATE Mobile builder vehicle
_bld1 = opfor_REPAIR_TRUCK_X createVehicle (_vehPos);
_Varname = "BLD1";
_bld1 SetVehicleVarName _VarName;
_bld1 Call Compile Format ["%1=_This ; PublicVariable ""%1""",_VarName];

private _missionObjects = [];

_static1 = "";
_static2 = "";
switch (VERSION_X) do {
    case "MODERN": {
        _static1 = "CargoNet_01_barrels_F";
        _static2 = "CamoNet_INDP_open_F";
    };
};

_obj1 = createVehicle [_static1, [(_vehpos select 0)-12, (_vehpos select 1)], [], 0, "CAN_COLLIDE"];
_missionObjects pushBack _obj1;
sleep 1;
_obj2 = createVehicle [_static1, [(_vehpos select 0)-10, (_vehpos select 1)], [], 0, "CAN_COLLIDE"];
_missionObjects pushBack _obj2;
sleep 1;
_obj3 = createVehicle [_static1, [(_vehpos select 0)-8, (_vehpos select 1)], [], 0, "CAN_COLLIDE"];
_missionObjects pushBack _obj3;
sleep 1;
_obj4 = createVehicle [_static2, [(_vehpos select 0)-10, (_vehpos select 1)], [], 0, "CAN_COLLIDE"];
_missionObjects pushBack _obj4;
sleep 1;

// Vehicle Guards
_group = [_vehPos, EAST, [opfor_SL_SOLDIER_X, opfor_LAT_SOLDIER_X, opfor_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
{
    [_x] call fnc_addRandomLoot;
} forEach units _group;
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
} forEach [_group, _buildingGroup];
{
    [_x] call fnc_addRandomLoot;
} forEach units _buildingGroup;
sleep 1;
[_targetpos, _radius] spawn fnc_missionPatrolswithintel;

private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["rescue%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];

[west, [_VARtaskgeneratedName],
[localize "STR_DUWS_T_czpvn5z1", _mission_name, "(getMarkerPos str(_markername))"], objNull, true] call BIS_fnc_taskCreate;

// 设置任务目标位置
missionNamespace setVariable ["current_mission_target_pos", getPos _bld1];
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

waitUntil {sleep 2; ((getdammage BLD1)>0.95 || (BLD1 distance PosOfBLUHQ)<50)};

deleteMarker str(_markername2);
deleteMarker str(_markername);

if (getdammage BLD1>0.95) exitWith {
    [{hint localize "STR_DUWS_T_obc4591x"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [_VARtaskgeneratedName, "FAILED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated,true];
    [] spawn fnc_missionTimer;
    missionNamespace setVariable [_triggeredVar, true, true];
    [_targetpos,_radius] spawn fnc_mission_cleanup;
    missionNamespace setVariable ["current_mission_target_pos", nil];
};

[_VARtaskgeneratedName, "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated,true];
[[{hint localize "STR_DUWS_T_125f39s4"}],"BIS_fnc_Spawn",true] call BIS_fnc_MP;
sleep 2;

_init_code = {
    waitUntil {!isNil "BLD1"};
    [BLD1, -1, west, "LIGHT"] execVM "modules\R3F_LOG\USER_FUNCT\init_creation_factory.sqf";
    [BLD1, "mil_triangle", "ColorBlue", "2", "2", "BLD-1"] call kndr_assignMarker;
};
[[[], _init_code], "BIS_fnc_spawn", true, true] spawn BIS_fnc_MP;

sleep 5;
[{hint localize "STR_DUWS_T_rw65exr8"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[] spawn fnc_missionTimer;

[_missionObjects] spawn {
    params ["_objects"];
    sleep 360;
    {
        if (!isNull _x) then {
            deleteVehicle _x;
        };
    } forEach _objects;
};
missionNamespace setVariable [_triggeredVar, true, true];
[_targetpos,_radius] spawn fnc_mission_cleanup;

missionNamespace setVariable ["current_mission_target_pos", nil];