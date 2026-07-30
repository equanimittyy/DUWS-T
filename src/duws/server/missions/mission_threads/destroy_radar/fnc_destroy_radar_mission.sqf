// Locality: server -- callers remoteExec to target 2.
params ["_MissionPos", "_mission_name"];
if (!([10, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};


_radius = 400;
_cpreward = 25;
_apreward = 20;
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_radarletsdothis";
_message1 = ([localize "STR_DUWS_T_radarend"] call fnc_cs);

_markerText2 = localize "STR_DUWS_T_c10";

private _site = [_MissionPos, _radius, 10] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

[_markerText2,{hint _this}] remoteExec ["BIS_fnc_Spawn",  player1];

_radarPos = _targetpos;

_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;

_centerSpawn = _radarPos;
_centerSpawnX = _centerSpawn select 0;
_centerSpawnY = _centerSpawn select 1;

_vehicle_0 = objNull;
_this = createVehicle ["Land_MultiMeter_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
_vehicle_0 = _this;
_this setPos _centerSpawn;
_centerSpawnZ = (getpos _vehicle_0 select 2);
deleteVehicle _vehicle_0;

// --DUWS-COMPOSITION BEGIN name="Mission: Destroy Radar" schema=C--
_staticsArray = [
    ["Box_FIA_Ammo_F",[3.23633,-0.296875,0],0,1,0,[],"","",true,false],
    ["Land_CratesWooden_F",[3.46631,-3.19775,1],0,1,0,[],"","",true,false],
    ["Land_HBarrier_5_F",[-6.48291,-3.77783,0],49.5237,1,0,[],"","",true,false],
    ["Land_HBarrier_5_F",[-8.11426,1.68848,0],88.8804,1,0,[],"","",true,false],
    ["Land_HBarrier_5_F",[1.946484,-8.04492,0],0.520331,1,0,[],"","",true,false],
    ["Land_HBarrier_5_F",[-0.718359,8.46387,0],183.745,1,0,[],"","",true,false],
    ["Land_HBarrier_5_F",[3.80957,6.41455,0],45.2709,1,0,[],"","",true,false],
    ["Land_HBarrier_5_F",[9.2251,-1.25684,0],269.491,1,0,[],"","",true,false]
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
    [_vehicle, "mission_destroy_radar"] call fnc_duws_keep;
} forEach _staticsArray;

_vehicle_7 = objNull;
_vehicle_7 = createVehicle ["I_E_Radar_System_01_F", [0,0,0], [], 0, "CAN_COLLIDE"];
_vehicle_7 setDir 0;
_vehicle_7 setPosATL [(_centerSpawnX), (_centerSpawnY), 0];
_vehicle_7 setDamage 0.5;
clearMagazineCargoGlobal _vehicle_7;
clearWeaponCargoGlobal _vehicle_7;
clearItemCargoGlobal _vehicle_7;
clearBackpackCargoGlobal _vehicle_7;
[_vehicle_7, "mission_destroy_radar"] call fnc_duws_keep;

_vehicle_9 = objNull;
_vehicle_9 = createVehicle ["B_static_AA_F", [0,0,0], [], 0, "CAN_COLLIDE"];
[_vehicle_9, "mission_destroy_radar"] call fnc_duws_keep;
_vehicle_9 setDir 314.218;
_vehicle_9 setPosATL [(_centerSpawnX)-5.52539, (_centerSpawnY)+5.98193, 0];
_vehicle_9 allowdamage false;
_vehicle_9 setdamage 0;

_vehicle_10 = objNull;
_vehicle_10 = createVehicle ["B_static_AA_F", [0,0,0], [], 0, "CAN_COLLIDE"];
[_vehicle_10, "mission_destroy_radar"] call fnc_duws_keep;
_vehicle_10 setDir 136.703;
_vehicle_10 setPosATL [(_centerSpawnX)+6.7168, (_centerSpawnY)-5.49365, 0];
_vehicle_10 allowdamage false;
_vehicle_10 setdamage 0;

_groupBunker1 = [getpos _vehicle_9, EAST, [opfor_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_groupBunker1 deleteGroupWhenEmpty true;
_groupBunker2 = [getpos _vehicle_10, EAST, [opfor_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_groupBunker2 deleteGroupWhenEmpty true;
_guard1 = units _groupBunker1 select 0;
_guard2 = units _groupBunker2 select 0;
_guard1 moveinGunner _vehicle_9;
_guard2 moveinGunner _vehicle_10;
_vehicle_9 setDir( [_centerSpawnX,_centerSpawnY] getDir getPosWorld _vehicle_9);
_vehicle_10 setDir( [_centerSpawnX,_centerSpawnY] getDir getPosWorld _vehicle_10);

[_guard2] joinSilent _groupBunker1;
_groupBunker1 addVehicle _vehicle_7;

sleep 1;

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
} forEach [_groupBunker1, _groupBunker2, _buildingGroup];
{
    [_x] call fnc_addRandomLoot;
} forEach units _buildingGroup;
{
    [_x] call fnc_addRandomLoot;
} forEach units _groupBunker1;
{
    [_x] call fnc_addRandomLoot;
} forEach units _groupBunker2;
sleep 1;
[_targetpos, _radius] spawn fnc_missionPatrolswithintel;

private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["cache%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];

[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[_VARtaskgeneratedName, localize "STR_DUWS_T_n4uc7t2x", _mission_name, _randomPos, "destroy"] call fnc_missionTaskCreate;
_speaker = localize "STR_DUWS_T_actionteam";
_message = ([localize "STR_DUWS_T_radarcopy"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

missionNamespace setVariable ["current_mission_target_pos", getPos _vehicle_7];
["info", [localize "STR_DUWS_T_SEARCH_CORPSE", localize "STR_DUWS_T_sidemissionloc"]] remoteExec ["BIS_fnc_showNotification", 0];

sleep 5; // 等待巡逻队生成完毕


waitUntil {sleep 5; !alive _vehicle_7 || (damage _vehicle_7) == 1};


sleep 120;

// Overlord's line, not the player's: _speaker was reassigned to the player callsign above
// for the intervening exchange, which left this congratulation attributed to Alpha 1-1.
[localize "STR_DUWS_T_OVERLORD", _message1] remoteExec ["fnc_duws_dialogue", 0];
deleteMarker str(_markername2);

[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[] spawn fnc_missionTimer;
[_targetpos,_radius, "mission_destroy_radar"] spawn fnc_mission_cleanup;

missionNamespace setVariable ["current_mission_target_pos", nil];