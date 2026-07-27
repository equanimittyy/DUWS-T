// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
if (!([7, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

// ========== 增援系统变量 ==========
private _varSuffix = format ["%1_%2", round(_MissionPos select 0), round(_MissionPos select 1)];
private _initialCountVar = format ["opf_initial_%1", _varSuffix];
private _triggeredVar = format ["opf_reinforce_%1", _varSuffix];
// ====================================

_radius = 200;
_cpreward = 15;
_apreward = 15;
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_armorletsdothis";
_message1 = ([localize "STR_DUWS_T_armorend"] call fnc_cs);

_randomPos = [];
_Building = [];
_Posfound = false;
_targetpos = [];
_failSafe = 0;
_markerText = "tank";
_markerText2 = localize "STR_DUWS_T_c7";

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

_vehpos = [_targetpos, 10, 30,10,0,0.15,0,[],[[0,0],[0,0]]] call BIS_fnc_findSafePos;

_markerData = [_randomPos, _markerText, _markerText2, _radius] call fnc_missionMarkerData;
_markername = _markerData select 0;
_markername2 = _markerData select 1;

private _missionObjects = [];

[_targetpos, _radius] spawn fnc_missionPatrolswithintel;

// Damaged Tank
_vehicle_1 = opfor_MBT_TANK1_X createVehicle (_vehpos);
_vehicle_1 setDamage 0.8;
_missionObjects pushBack _vehicle_1;

_obj1 = createVehicle ["CamoNet_OPFOR_open_F", _targetpos, [], 0, "CAN_COLLIDE"];
_missionObjects pushBack _obj1;
_obj2 = createVehicle ["Land_WoodenTable_large_F", [(_targetpos select 0)+1, (_targetpos select 1)+1], [], 0, "CAN_COLLIDE"];
_missionObjects pushBack _obj2;

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

// Commander group
_group = [_targetpos, EAST, [opfor_OFFICER_X, opfor_CREW_X, opfor_OPERATOR_X, opfor_ENG_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
_target = units _group select 0;

// No hat for OPTRE, HL2 or TIOW
if !(("OPTRE" in BLUFOR_FactionFile_X)
    or ("HL2ECR" in BLUFOR_FactionFile_X)
    or ("TIOW" in BLUFOR_FactionFile_X)) then {
    removeheadgear _target;
    _target addHeadgear "H_HelmetCrew_I";
};

// Put an intel action on target
if (hardcore_mode_enable && (random 10) < (master_Intel_chance + master_Intel_boost)) then {
    _code = {[] spawn fnc_found_intel};
    [_target, "Search for Intel", "search", _code] spawn fnc_actionRotary;
};

_wp = _group addWaypoint [_vehpos, 0];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointTimeout [30, 45, 60];

_wp = _group addWaypoint [_targetpos, 0];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointTimeout [30, 45, 60];

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
// 为坦克指挥官添加机密情报
[_target] spawn {
    params ["_unit"];
    sleep 5;
    _unit addMagazineGlobal "FileTopSecret";
};
{
    [_x] call fnc_addRandomLoot;
} forEach units _buildingGroup;
{
    [_x] call fnc_addRandomLoot;
} forEach units _group;
// TASK AND NOTIFICATION
private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["targetarmor%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 8;
[west, [_VARtaskgeneratedName],
[localize "STR_DUWS_T_y7z1cx6j", _mission_name, "(getMarkerPos str(_markername))"], objNull, true] call BIS_fnc_taskCreate;

// 设置任务目标位置（军官位置）
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

// MISSION COMPLETED ?
waitUntil {sleep 2; !alive _target};

sleep 120;

[_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
deleteMarker str(_markername2);
deleteMarker str(_markername);

[_VARtaskgeneratedName, "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated,true];

sleep 1;

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