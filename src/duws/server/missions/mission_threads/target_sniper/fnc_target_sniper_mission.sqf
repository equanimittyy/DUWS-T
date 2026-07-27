// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
if (!([5, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

// ========== 增援系统变量 ==========
private _varSuffix = format ["%1_%2", round(_MissionPos select 0), round(_MissionPos select 1)];
private _initialCountVar = format ["opf_initial_%1", _varSuffix];
private _triggeredVar = format ["opf_reinforce_%1", _varSuffix];
// ====================================

_radius = 400;
_cpreward = 30;
_apreward = 30;
_speaker = localize "STR_DUWS_T_Viper";
_message = localize "STR_DUWS_T_sniperletsdothis";
_message1 = ([localize "STR_DUWS_T_sniperend"] call fnc_cs);

_randomPos = [];
_Building = [];
_Posfound = false;
_targetpos = [];
_failSafe = 0;
_markerText = "sniper";
_markerText2 = localize "STR_DUWS_T_c5";

_POSdata = [_MissionPos, _radius, _Posfound, _targetpos, _failSafe] call fnc_missionTargetPos;

_randomPos = _POSdata select 0;
_Building = _POSdata select 1;
_Posfound = _POSdata select 2;
_targetpos = _POSdata select 3;
_failSafe = _POSdata select 4;

if (_failsafe > 10 && _Posfound == false) exitWith {
	Mission_available = true; 
	publicVariable "Mission_available"; 
	[{hint"No suitable location found.  Please try again."}] remoteExec ["BIS_fnc_Spawn", 0];
};

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn",  player1];

_markerData = [_randomPos, _markerText, _markerText2, _radius] call fnc_missionMarkerData;
_markername = _markerData select 0;
_markername2 = _markerData select 1;

// 建筑驻军
private _buildingSearchRadius = _radius;
private _usableBuildings = [_targetpos, 2, _buildingSearchRadius] call fnc_usableBuildings;
private _desiredBldgCount = 6;
private _actualBldgCount = count _usableBuildings;

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
    private _buildingGroup = [[0,0], EAST, _bldgUnits,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
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

// CREATE PATROLS, NO VEHICLES
sleep 1;
[_missionpos, 15, false] spawn fnc_createoppatrol2;
sleep 1;
[_randompos, _radius, false] spawn fnc_createoppatrol2;
sleep 1;
[_randompos, _radius, false] spawn fnc_createopteam2;
sleep 1;
[_randompos, _radius, false] spawn fnc_createopteam2;

_group = [_targetpos, east, [opfor_SL_SOLDIER_X, opfor_SNIPER_SOLDIER_X, opfor_SNIPER_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup; 
_group deleteGroupWhenEmpty true;
_target1 = units _group select 1;
_target2 = units _group select 2;

// 为狙击手添加吉利服
[_target1] spawn {
    params ["_unit"];
    sleep 5;
    _unit forceAddUniform "U_B_FullGhillie_sard";
};
[_target2] spawn {
    params ["_unit"];
    sleep 5;
    _unit forceAddUniform "U_B_FullGhillie_sard";
};
// 为狙击手添加机密情报
[_target1] spawn {
    params ["_unit"];
    sleep 5;
    _unit addMagazineGlobal "FileTopSecret";
};
// 为狙击手添加机密情报
[_target2] spawn {
    params ["_unit"];
    sleep 5;
    _unit addMagazineGlobal "FileTopSecret";
};
// Put an intel action on leader
if (hardcore_mode_enable && (random 10) < (master_Intel_chance + master_Intel_boost)) then {
	_leader = units _group select 0;
	_code = {[] spawn fnc_found_intel};
	[_leader, "Search for Intel", "search", _code] spawn fnc_actionRotary;
};

if (VERSION_X == "MODERN") then {
	if !(("OPTRE" in BLUFOR_FactionFile_X) 
		or ("HL2ECR" in BLUFOR_FactionFile_X)
		or ("TIOW" in BLUFOR_FactionFile_X)) then {
		removeheadgear _target1;
		removeheadgear _target2;
		_target1 addHeadgear "H_Shemag_khk";
		_target2 addHeadgear "H_Shemag_khk";
	};
};

[_group, _targetpos, _radius] call bis_fnc_taskPatrol;
{
    [_x] call fnc_addRandomLoot;
} forEach units _group;

// TASK AND NOTIFICATION
private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["sniperhunt%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 8;
[west, [_VARtaskgeneratedName], 
[localize "STR_DUWS_T_16dh939j", _mission_name, "(getMarkerPos str(_markername))"], objNull, true] call BIS_fnc_taskCreate; 

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

waitUntil {sleep 2; (!alive _target1 && !alive _target2)};

sleep 120;
[_speaker, _message1] remoteExec ["fnc_duws_dialogue", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
deleteMarker str(_markername2);
deleteMarker str(_markername);

[_VARtaskgeneratedName, "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated,true];

sleep 1;

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[] spawn fnc_missionTimer;
missionNamespace setVariable [_triggeredVar, true, true];
[_targetpos,_radius] spawn fnc_mission_cleanup;