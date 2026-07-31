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
_markerText2 = localize "STR_DUWS_T_clearhouse_desc";

private _site = [_MissionPos, _radius, 11] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

[localize "STR_DUWS_T_c11",{hint _this}] remoteExec ["BIS_fnc_Spawn",  [0,-2] select isDedicated];

sleep 2;

// Garrisoned around the site, not around the slot centre. Every other thread builds on what
// fnc_mission_site returned and marks the same point; this one drew its ellipse at _randomPos and
// then filled houses up to 280 m away from it, so the enemy routinely sat outside the marked area.
_usableBuildings = [_randomPos, 2, 180] call fnc_usableBuildings;

_desiredBldgCount = 4;
_actualBldgCount = count _usableBuildings;

if (_actualBldgCount == 0) exitWith {
    [11, "STR_DUWS_T_mission_no_building"] call fnc_mission_abort;
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

_possibleUnitTypes = [[
    opfor_SOLDIER_X,
    opfor_AA_SOLDIER_X,
    opfor_AR_SOLDIER_X,
    opfor_AT_SOLDIER_X,
    opfor_LAT_SOLDIER_X,
    opfor_SL_SOLDIER_X
]] call fnc_opforRoles;

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

_buildingUnitsList = [_group, _selectedBuildings, _unitsPerBuilding, "AUTO"] call fnc_spreadIntoBuildings;

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

// One guaranteed carrier, reached through the player's own search action rather than an action
// of its own: a body is a body, and the flag is what tells the search this one is worth opening.
if (hardcore_mode_enable && count _allUnits > 0) then {
    [[selectRandom _allUnits], "objective"] call fnc_search_flag_group;
};

private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["clearhouse%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];

[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_speakeracteam, _messageroger] remoteExec ["fnc_duws_dialogue", 0];

_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;
[_VARtaskgeneratedName, localize "STR_DUWS_T_shentouxiaodui", _mission_name, _randomPos, "attack"] call fnc_missionTaskCreate;

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

[_speakeracteam, _message1] remoteExec ["fnc_duws_dialogue", 0];
sleep 5;
[_speakeracteam, _message2] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[_speaker, _message3] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;

sleep 1;

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[_targetpos,_radius] call fnc_mission_end;