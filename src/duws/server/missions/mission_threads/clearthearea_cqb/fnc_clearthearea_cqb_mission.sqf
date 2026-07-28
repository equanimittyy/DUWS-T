// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
if (!([11, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

_radius = 200;
_cpreward = 15;
_apreward = 15;
_speaker = localize "STR_DUWS_T_OVERLORD";
_speakeracteam = localize "STR_DUWS_T_actionteam";
_message = localize "STR_DUWS_T_cqbletsdothis";
_messageroger = ([localize "STR_DUWS_T_cqbroger"] call fnc_cs);
_message1 = localize "STR_DUWS_T_cqblookslike";
_message2 = ([localize "STR_DUWS_T_cqbend"] call fnc_cs);
_message3 = localize "STR_DUWS_T_cqboverlordcopy";
_markerText = "Clear houses";
_markerText2 = localize "STR_DUWS_T_clearhouse_desc";

_randomPos = [];          
_Building = [];           
_Posfound = false;        
_targetpos = [];          
_failSafe = 0;            

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

[localize "STR_DUWS_T_c11",{hint _this}] remoteExec ["BIS_fnc_Spawn",  0];

sleep 2;

_usableBuildings = [_MissionPos, 2, 180] call fnc_usableBuildings;

_desiredBldgCount = 4;
_actualBldgCount = count _usableBuildings;

if (_actualBldgCount == 0) exitWith {
    Mission_available = true; 
    publicVariable "Mission_available"; 
    [{hint"No suitable buildings found in the area. Mission cancelled."}] remoteExec ["BIS_fnc_Spawn", 0];
};

_maxBuildingsToUse = (_actualBldgCount min _desiredBldgCount);

_selectedBuildings = [];
if (_actualBldgCount == _maxBuildingsToUse) then {
    _selectedBuildings = _usableBuildings;
} else {
    _tempArray = +_usableBuildings;
    for "_i" from 1 to _maxBuildingsToUse do {
        _index = floor (random (count _tempArray));
        _selectedBuildings pushBack (_tempArray select _index);
        _tempArray deleteAt _index;
    };
};

_buildingMarkers = [];
_markerCount = 0;
{
    _markerCount = _markerCount + 1;
    _buildingPos = getPos _x;
    _markerNamebldg = format ["building_marker_%1_%2", round(time), _markerCount];
    _marker = createMarker [_markerNamebldg, _buildingPos];
    _marker setMarkerShape "ICON";
    _marker setMarkerType "o_unknown";
    _marker setMarkerColor "ColorRed";
    _marker setMarkerSize [0.2, 0.2];
    _marker setMarkerText format ["Enemy%1", _markerCount];
    _buildingMarkers pushBack _markerNamebldg;
} forEach _selectedBuildings;

_unitsPerBuilding = 6;
_totalUnitsToSpawn = _maxBuildingsToUse * _unitsPerBuilding;

_possibleUnitTypes = [];
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

_bldgUnits = [];
for "_i" from 1 to _totalUnitsToSpawn do {
    _unitType = selectRandom _possibleUnitTypes;
    _bldgUnits pushBack _unitType;
};
_group = [[0,0], east, _bldgUnits,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;

// ========== 添加随机战利品 ==========
{
    [_x] call fnc_addRandomLoot;
} forEach units _group;
// =================================

_buildingUnitsList = [];

{
    if (_forEachIndex >= _maxBuildingsToUse) exitWith {};
    
    _building = _x;
    _positions = [_building] call BIS_fnc_buildingPositions;
    
    _buildingUnits = [];
    for "_j" from 0 to (_unitsPerBuilding - 1) do {
        _unitIndex = _forEachIndex * _unitsPerBuilding + _j;
        if (_unitIndex >= count (units _group)) exitWith {};
        
        _unit = units _group select _unitIndex;
        _buildingUnits pushBack _unit;
        if (count _positions > 0) then {
            _randPosIndex = floor (random (count _positions));
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
    _buildingUnitsList pushBack _buildingUnits;
} forEach _selectedBuildings;

// ========== 监控每个房屋，清理后广播并删除标记 ==========
{
    _buildingIndex = _forEachIndex + 1;
    _markerName = _buildingMarkers select _forEachIndex;
    [_x, _buildingIndex, _markerName] spawn {
        params ["_units", "_idx", "_mrk"];
        private _speaker = localize "STR_DUWS_T_actionteam";
        waitUntil {
            sleep 2;
            ({alive _x} count _units) == 0
        };
        private _msg = format [localize "STR_DUWS_T_HOUSE_CLEARED", _idx];
        [_speaker, _msg] remoteExec ["fnc_duws_dialogue", 0];
        deleteMarker _mrk;
    };
} forEach _buildingUnitsList;

_allUnits = units _group;

if (hardcore_mode_enable && count _allUnits > 0) then {
    _intelSoldier = selectRandom _allUnits;
    _code = {[] remoteExec ["fnc_intel_payout", 2]};
    [_intelSoldier, "Search for Intel", "search", _code] spawn fnc_actionRotary;
};

private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["clearhouse%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];

[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_speakeracteam, _messageroger] remoteExec ["fnc_duws_dialogue", 0];

_markerData = [_randomPos, _markerText, _markerText2, _radius] call fnc_missionMarkerData;
_markername = _markerData select 0;
_markername2 = _markerData select 1;
[west, [_VARtaskgeneratedName], 
[localize "STR_DUWS_T_shentouxiaodui", _mission_name, "(getMarkerPos str(_markername))"], objNull, true] call BIS_fnc_taskCreate;

waitUntil {
    sleep 3;
    _allDead = true;
    {
        if (alive _x) then {
            _allDead = false;
        };
    } forEach units _group;
    (_allDead && count _bldgUnits > 0)
};

deleteMarker str(_markername2);
deleteMarker str(_markername);

[_speakeracteam, _message1] remoteExec ["fnc_duws_dialogue", 0];
sleep 5;
[_speakeracteam, _message2] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[_speaker, _message3] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[_VARtaskgeneratedName, "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated,true];

sleep 1;

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[] spawn fnc_missionTimer;
[_targetpos,_radius] spawn fnc_mission_cleanup;