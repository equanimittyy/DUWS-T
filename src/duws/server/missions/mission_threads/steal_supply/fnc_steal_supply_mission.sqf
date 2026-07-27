// Locality: server; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).
params ["_MissionPos", "_mission_name"];
if (!([1, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

// ========== 增援系统变量 ==========
private _varSuffix = format ["%1_%2", round(_MissionPos select 0), round(_MissionPos select 1)];
private _initialCountVar = format ["opf_initial_%1", _varSuffix];
private _triggeredVar = format ["opf_reinforce_%1", _varSuffix];
// ====================================

_radius = 600;
_cpreward = 35;
_apreward = 25;
_speaker = localize "STR_DUWS_T_Signal2";
_message = localize "STR_DUWS_T_supplytruckletsdothis";
_speaker1 = localize "STR_DUWS_T_OVERLORD";
_message1 = ([localize "STR_DUWS_T_supplytruckoverlord"] call fnc_cs);
_message2 = ([localize "STR_DUWS_T_supplytruckfail"] call fnc_cs);

_taskTimeLimit = 1200;
_taskStartTime = time;

_randomPos = [];
_Building = [];
_Posfound = false;
_targetpos = [];
_failSafe = 0;
_markerText = "supply";
_markerText2 = localize "STR_DUWS_T_c1";

_POSdata = [_MissionPos, _radius, _Posfound, _targetpos, _failSafe] call fnc_missionTargetPos;

_randomPos = _POSdata select 0;
_Building = _POSdata select 1;
_Posfound = _POSdata select 2;
_targetpos = _POSdata select 3;
_failSafe = _POSdata select 4;

if (_failSafe > 10 && !_Posfound) exitWith {
    Mission_available = true;
    publicVariable "Mission_available";
    [{hint localize "STR_DUWS_T_crtzxs0j"}] remoteExec ["BIS_fnc_Spawn", 0];
};

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn", player1];

_vehPos = _targetpos;

_markerData = [_randomPos, _markerText, _markerText2, _radius] call fnc_missionMarkerData;
_markername = _markerData select 0;
_markername2 = _markerData select 1;

private _missionObjects = [];

// 创建卡车
// The objective itself: kept for the mission's duration so the abandoned-vehicle clause
// cannot collect it. A player who disables it and takes half an hour would otherwise find
// the thing they were sent for gone, with no way left to finish.
_truck1 = opfor_TRANS_TRUCK_X createVehicle _vehPos;
[_truck1, "mission_steal_supply"] call fnc_duws_keep;
clearMagazineCargoGlobal _truck1;
clearWeaponCargoGlobal _truck1;
clearItemCargoGlobal _truck1;
clearBackpackCargoGlobal _truck1;
_missionObjects pushBack _truck1;

[_truck1, {
    private _actionID = _this addAction [
        format ["<t color='#00ff00'>%1</t>", localize "STR_DUWS_T_FULL_ARSENAL_ONCE"],
        {
            params ["_target", "_caller", "_actionId"];
            if (!(_target getVariable ["arsenalUsed", false])) then {
                _target setVariable ["arsenalUsed", true, true];
                _target removeAction _actionId;
                [_target] remoteExec ["fnc_removeArsenalAction", 0];
                ["dakaijunhuoku", [localize "STR_DUWS_T_dakaijunhuoku", localize "STR_DUWS_T_dakaijunhuoku2"]] remoteExec ["BIS_fnc_showNotification", 0];
                ["Open", true] call BIS_fnc_arsenal;
            };
        },
        nil,
        6,
        true,
        true,
        "!(_target getVariable ['arsenalUsed', false])"
    ];
    _this setVariable ["arsenalActionID", _actionID];
}] remoteExec ["call", 0, true];
_truck1 setVariable ["arsenalUsed", false, true];

private _truckGetInEH = _truck1 addEventHandler ["GetIn", {
    params ["_vehicle", "_role", "_unit", "_turret"];
    if (isPlayer _unit) then {
        [{hint localize "STR_DUWS_T_fxkczy00"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated, false];
    };
}];

_box1 = "";
_box2 = "";
_static1 = "";
_static2 = "";
switch (VERSION_X) do {
    case "MODERN": {
        _box1 = "O_supplyCrate_F" createVehicle _vehPos;
        _box2 = "O_supplyCrate_F" createVehicle _vehPos;
        { [_x, "mission_steal_supply"] call fnc_duws_keep; } forEach [_box1, _box2];
        _box1 attachTo [_truck1, [0, -0.5, 0]];
        _box1 setDir 90;
        _box2 attachTo [_truck1, [0, -2.2, 0]];
        _box2 setDir 75;
        _static1 = "CargoNet_01_barrels_F";
        _static2 = "CamoNet_INDP_open_F";
    };
};

clearMagazineCargoGlobal _box1;
clearWeaponCargoGlobal _box1;
clearItemCargoGlobal _box1;
clearBackpackCargoGlobal _box1;
clearMagazineCargoGlobal _box2;
clearWeaponCargoGlobal _box2;
clearItemCargoGlobal _box2;
clearBackpackCargoGlobal _box2;

_obj1 = createVehicle [_static1, [(_vehPos select 0)-12, (_vehPos select 1)-10], [], 0, "CAN_COLLIDE"];
_missionObjects pushBack _obj1;
sleep 1;
_obj2 = createVehicle [_static1, [(_vehPos select 0)-10, (_vehPos select 1)-10], [], 0, "CAN_COLLIDE"];
_missionObjects pushBack _obj2;
sleep 1;
_obj3 = createVehicle [_static1, [(_vehPos select 0)-8, (_vehPos select 1)-10], [], 0, "CAN_COLLIDE"];
_missionObjects pushBack _obj3;
sleep 1;
_obj4 = createVehicle [_static2, [(_vehPos select 0)-10, (_vehPos select 1)-10], [], 0, "CAN_COLLIDE"];
_missionObjects pushBack _obj4;
sleep 1;

// 守卫
_group = [_vehPos, EAST, [opfor_SL_SOLDIER_X, opfor_LAT_SOLDIER_X, opfor_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;

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
sleep 1;
[_targetpos, _radius] spawn fnc_missionPatrolswithintel;

private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["rescue%1%2", round(_MissionPos select 0), round(_MissionPos select 1)];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_speaker1, _message1] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[west, [_VARtaskgeneratedName],
[localize "STR_DUWS_T_p7qawzl4", _mission_name, "(getMarkerPos str(_markername))"], objNull, true] call BIS_fnc_taskCreate;
["dakaijunhuoku", [localize "STR_DUWS_T_xnjhk", localize "STR_DUWS_T_xnjhk2"]] remoteExec ["BIS_fnc_showNotification", 0];

// 设置任务目标位置
missionNamespace setVariable ["current_mission_target_pos", getPos _truck1];
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

waitUntil {
    sleep 1;
    (!alive _truck1) ||
    (_truck1 distance PosOfBLUHQ < 100) ||
    (time - _taskStartTime > _taskTimeLimit)
};

deleteMarker str(_markername2);
deleteMarker str(_markername);

if (!alive _truck1 || (time - _taskStartTime > _taskTimeLimit)) exitWith {
    _truck1 removeEventHandler ["GetIn", _truckGetInEH];
    _truck1 setDamage 1;
    [{hint localize "STR_DUWS_T_jsg7ys0w"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated, false];
    [_speaker1, _message2] remoteExec ["fnc_duws_dialogue", 0];
    [_VARtaskgeneratedName, "FAILED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated, true];
    [] spawn fnc_missionTimer;
    missionNamespace setVariable [_triggeredVar, true, true];
    [_targetpos, _radius, "mission_steal_supply"] spawn fnc_mission_cleanup;
    missionNamespace setVariable ["current_mission_target_pos", nil];
};

_truck1 removeEventHandler ["GetIn", _truckGetInEH];
[_VARtaskgeneratedName, "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated, true];

[{hint localize "STR_DUWS_T_po7fmmoa"}] remoteExec ["BIS_fnc_Spawn", player1];
sleep 2;
deleteVehicle _box2;
sleep 2;
deleteVehicle _box1;
[{hint localize "STR_DUWS_T_3jmpthvi"}] remoteExec ["BIS_fnc_Spawn", player1];

// Handed to the map cleanup instead of deleted on a private timer: the same wait, but
// the sweep holds anything a player is still standing near, so a finished objective does
// not dissolve in front of whoever is looting it.
{ [_x, 360] call fnc_duws_disposeAfter } forEach _missionObjects;

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[] spawn fnc_missionTimer;
missionNamespace setVariable [_triggeredVar, true, true];
[_targetpos, _radius, "mission_steal_supply"] spawn fnc_mission_cleanup;

missionNamespace setVariable ["current_mission_target_pos", nil];