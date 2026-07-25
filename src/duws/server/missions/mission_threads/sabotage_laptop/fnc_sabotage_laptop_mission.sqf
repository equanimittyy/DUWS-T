// Locality: server; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).
params ["_MissionPos", "_mission_name"];
if (!([8, _MissionPos, _mission_name] call fnc_mission_begin)) exitWith {};

// ========== 增援系统变量 ==========
private _varSuffix = format ["%1_%2", round(_MissionPos select 0), round(_MissionPos select 1)];
private _initialCountVar = format ["opf_initial_%1", _varSuffix];
private _triggeredVar = format ["opf_reinforce_%1", _varSuffix];
// ====================================

_radius = 200;

_randomPos = [];
_Building = [];
_Posfound = false;
_targetpos = [];
_failSafe = 0;
_markerText = "sabot";
_markerText2 = "";
switch (VERSION_X) do {
    case "MODERN": {
        _markerText2 = localize "STR_DUWS_T_c8";
    };
};
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_laptopletsdothis";

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

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn",  player1];

_tableLoc = _targetpos;

_markerData = [_randomPos, _markerText, _markerText2, _radius] call fnc_missionMarkerData;
_markername = _markerData select 0;
_markername2 = _markerData select 1;

private _missionObjects = [];

_laptop = "";
switch (VERSION_X) do {
    case "MODERN": {
        _table = createVehicle ["Land_WoodenTable_large_F", _tableLoc, [], 0, "CAN_COLLIDE"];
        _table setDir 0;
        _missionObjects pushBack _table;
        sleep 1;
        _pallet = createVehicle ["VirtualReammoBox_camonet_F", [(_tableLoc select 0)+3, (_tableLoc select 1)+3], [], 0, "CAN_COLLIDE"];
        _missionObjects pushBack _pallet;
        sleep 1;
        _laptop = createVehicle ["Land_Laptop_unfolded_F", _tableLoc, [], 0, "CAN_COLLIDE"];
        _laptop setpos [(_tableLoc select 0),(_tableLoc select 1),1.0];
        _laptop setDir 270;
        _missionObjects pushBack _laptop;
        sleep 1;
        _camonet = createVehicle ["CamoNet_INDP_open_F", _tableLoc, [], 0, "CAN_COLLIDE"];
        _camonet setDir 0;
        _missionObjects pushBack _camonet;
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
// CREATE OPFOR PATROLS
sleep 1;
[_targetpos, _radius] spawn fnc_missionPatrolswithintel;

// TASK AND NOTIFICATION
private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["sabotage%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];

[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 8;
switch (VERSION_X) do {
    case "MODERN": {
        [west, [_VARtaskgeneratedName],
        [localize "STR_DUWS_T_j97ecrsh", _mission_name, "aoMarker"], objNull, true] call BIS_fnc_taskCreate;
    };
};

// ADD SABOTAGE ACTION TO LAPTOP
[_laptop,[localize "STR_DUWS_T_p3200mf5", fnc_sabotage_laptop_success, [_MissionPos,_targetpos,_mission_name,_markername,_markername2,_radius], 0, true, true, "", "_this == player"]] remoteExec ["addAction", [0,-2] select isDedicated,true];

// Put an intel action on LAPTOP
if (hardcore_mode_enable && (random 10) < 11) then {
    _code = {[] spawn fnc_found_intel};
    [_laptop, localize "STR_DUWS_T_7yec9ifj", "search", _code] spawn fnc_actionRotary;
};
["info", [localize "STR_DUWS_T_SEARCH_CORPSE", localize "STR_DUWS_T_sidemissionloc"]] remoteExec ["BIS_fnc_showNotification", 0];
// 设置任务目标位置
missionNamespace setVariable ["current_mission_target_pos", getPos _laptop];

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