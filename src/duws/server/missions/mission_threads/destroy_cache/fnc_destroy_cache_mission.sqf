// Locality: server; the addAction bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).
#include "..\..\..\..\shared\includes\action_style.hpp"

params ["_MissionPos", "_mission_name"];
if (!([9, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};


private _missionUnits = [];

_radius = 400;
_cpreward = 30;
_apreward = 15;
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = localize "STR_DUWS_T_cacheletsdothis";

_randomPos = [];
_Building = [];
_Posfound = false;
_targetpos = [];
_failSafe = 0;
_markerText2 = localize "STR_DUWS_T_c9";

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

_cachePos = _targetpos;

_markername2 = [_randomPos, _radius] call fnc_missionMarkerData;

_centerSpawn = _cachePos;
_centerSpawnX = _centerSpawn select 0;
_centerSpawnY = _centerSpawn select 1;

_vehicle_0 = objNull;
_this = createVehicle ["Land_MultiMeter_F", [0,0,0], [], 0, "CAN_COLLIDE"];
_vehicle_0 = _this;
_this setPos _centerSpawn;
_centerSpawnZ = (getpos _vehicle_0 select 2);
deleteVehicle _vehicle_0;

// --DUWS-COMPOSITION BEGIN name="Mission: Destroy Cache" schema=C--
_staticsArray = [
    ["CamoNet_INDP_open_F",[0.942383,-0.640625,0],342.004,1,0,[],"","",true,false],
    ["Land_GarbageHeap_02_F",[-1.71191,-1.54443,3.33786e-006],93.4817,1,0,[],"","",true,false],
    ["Land_CratesWooden_F",[-1.27148,2.11084,0],0,1,0,[],"","",true,false],
    ["Land_GarbageHeap_04_F",[-2.4165,-0.706543,-0.0443211],90.9487,1,0,[],"","",true,false],
    ["Land_CratesWooden_F",[1.46631,-3.19775,0],0,1,0,[],"","",true,false],
    ["Land_HBarrier_5_F",[-6.48291,-3.77783,0],49.5237,1,0,[],"","",true,false],
    ["Land_HBarrier_5_F",[-8.11426,1.68848,0],88.8804,1,0,[],"","",true,false],
    ["Land_HBarrier_5_F",[1.946484,-8.04492,0],0.520331,1,0,[],"","",true,false],
    ["Land_HBarrier_5_F",[-0.718359,8.46387,0],183.745,1,0,[],"","",true,false],
    ["Land_HBarrier_5_F",[3.80957,6.41455,0],45.2709,1,0,[],"","",true,false],
    ["Land_HBarrier_5_F",[9.2251,-1.25684,0],269.491,1,0,[],"","",true,false],
    ["Land_BagBunker_Small_F",[-7.08691,7.32031,0],134.261,1,0,[],"","",true,false],
    ["Land_BagBunker_Small_F",[8.24512,-6.67188,0],314.617,1,0,[],"","",true,false]
];
// --DUWS-COMPOSITION END--

_vehicle = objNull;
{
    _xyz = (_x select 1);
    _posX = (_xyz select 0);
    _posY = (_xyz select 1);
    _vehicle = createVehicle [(_x select 0), [0,0,0], [], 0, "CAN_COLLIDE"];
    _vehicle setDir (_x select 2);
    _vehicle setPosATL [(_centerSpawnX)+_posX,(_centerSpawnY)+_posY,0];
    [_vehicle, "mission_destroy_cache"] call fnc_duws_keep;
} forEach _staticsArray;

_vehicle_7 = createVehicle ["Box_FIA_Ammo_F", [0,0,0], [], 0, "CAN_COLLIDE"];
[_vehicle_7, "mission_destroy_cache"] call fnc_duws_keep;
_vehicle_7 setDir 0;
_vehicle_7 setPosATL [(_centerSpawnX), (_centerSpawnY), 0];
_vehicle_7 setDamage 0.5;
_vehicle_7 setVariable ["R3F_LOG_disabled", true];
clearMagazineCargoGlobal _vehicle_7;
clearWeaponCargoGlobal _vehicle_7;
clearItemCargoGlobal _vehicle_7;
clearBackpackCargoGlobal _vehicle_7;

[_vehicle_7, {
    private _actionID = _this addAction [
        ACT_EQUIP("STR_DUWS_T_FULL_ARSENAL_ONCE"),
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
        [],
        80,
        true,
        true,
        "",
        "!(_target getVariable ['arsenalUsed', false])"
    ];
    _this setVariable ["arsenalActionID", _actionID];
}] remoteExec ["call", 0, true];
_vehicle_7 setVariable ["arsenalUsed", false, true];

_vehicle_8 = createVehicle ["Box_FIA_Ammo_F", [0,0,0], [], 0, "CAN_COLLIDE"];
[_vehicle_8, "mission_destroy_cache"] call fnc_duws_keep;
_vehicle_8 setDir 0;
_vehicle_8 setPosATL [(_centerSpawnX)+2.23633, (_centerSpawnY)-0.296875, 0];
_vehicle_8 setDamage 0.5;
_vehicle_8 setVariable ["R3F_LOG_disabled", true];
clearMagazineCargoGlobal _vehicle_8;
clearWeaponCargoGlobal _vehicle_8;
clearItemCargoGlobal _vehicle_8;
clearBackpackCargoGlobal _vehicle_8;

[_vehicle_8, {
    private _actionID = _this addAction [
        ACT_EQUIP("STR_DUWS_T_FULL_ARSENAL_ONCE"),
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
        [],
        80,
        true,
        true,
        "",
        "!(_target getVariable ['arsenalUsed', false])"
    ];
    _this setVariable ["arsenalActionID", _actionID];
}] remoteExec ["call", 0, true];
_vehicle_8 setVariable ["arsenalUsed", false, true];

_vehicle_9 = createVehicle [blufor_TURRET_HMG, [0,0,0], [], 0, "CAN_COLLIDE"];
_vehicle_9 setDir 314.218;
_vehicle_9 setPosATL [(_centerSpawnX)-5.52539, (_centerSpawnY)+5.98193, 0];
_vehicle_9 allowdamage false;
_vehicle_9 setdamage 0;
[_vehicle_9, "mission_destroy_cache"] call fnc_duws_keep;

_vehicle_10 = createVehicle [blufor_TURRET_HMG, [0,0,0], [], 0, "CAN_COLLIDE"];
_vehicle_10 setDir 136.703;
_vehicle_10 setPosATL [(_centerSpawnX)+6.7168, (_centerSpawnY)-5.49365, 0];
_vehicle_10 allowdamage false;
_vehicle_10 setdamage 0;
[_vehicle_10, "mission_destroy_cache"] call fnc_duws_keep;

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
_missionUnits pushBack _guard1;
_missionUnits pushBack _guard2;
{
    _missionUnits pushBack _x;
} forEach (units _groupBunker1);
{
    _missionUnits pushBack _x;
} forEach (units _groupBunker2);

// ========== 添加随机战利品（炮塔守卫）==========
{
    [_x] call fnc_addRandomLoot;
} forEach units _groupBunker1;
{
    [_x] call fnc_addRandomLoot;
} forEach units _groupBunker2;
// ============================================

// 建筑驻军
private _buildingSearchRadius = _radius;
private _usableBuildings = [_cachePos, 2, _buildingSearchRadius] call fnc_usableBuildings;
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

    // ========== 添加随机战利品（建筑驻军）==========
    {
        [_x] call fnc_addRandomLoot;
    } forEach units _buildingGroup;
    // ============================================

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
// ====================================

sleep 1;
[_targetpos, _radius] spawn fnc_missionPatrolswithintel;

private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["cache%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];

[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
_speaker = localize "STR_DUWS_T_actionteam";
_message = ([localize "STR_DUWS_T_cachecopy"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
[_VARtaskgeneratedName, localize "STR_DUWS_T_geryeddp", _mission_name, _randomPos, "destroy"] call fnc_missionTaskCreate;
["dakaijunhuoku", [localize "STR_DUWS_T_xnjhk", localize "STR_DUWS_T_xnjhk2"]] remoteExec ["BIS_fnc_showNotification", 0];

missionNamespace setVariable ["current_mission_target_pos", getPos _vehicle_7];
["info", [localize "STR_DUWS_T_SEARCH_CORPSE", localize "STR_DUWS_T_sidemissionloc"]] remoteExec ["BIS_fnc_showNotification", 0];

sleep 5; // 等待巡逻队生成完毕


waitUntil {
    sleep 5;
    ( (!alive _vehicle_7 || damage _vehicle_7 == 1) && (!alive _vehicle_8 || damage _vehicle_8 == 1) )
};

// Units only, and deleted rather than handed to the sweep: they are not composition, and
// the sweep spares anything with living crew -- a man's crew is himself. The mission's
// props leave through fnc_duws_release, which its own cleanup call triggers.
{ deleteVehicle _x } forEach _missionUnits;

_bomb = "grenade" createVehicle[(_cachePos select 0), (_cachePos select 1)];
sleep 0.5;
_bomb = "grenade" createVehicle[(_cachePos select 0), (_cachePos select 1)];
_bomb = "grenade" createVehicle[(_cachePos select 0), (_cachePos select 1)];
sleep 0.1;
_bomb = "grenade" createVehicle[(_cachePos select 0), (_cachePos select 1)];
sleep 0.5;
_bomb = "Bo_Mk82" createVehicle[(_cachePos select 0), (_cachePos select 1)];
sleep 0.5;
_bomb = "Bo_Mk82" createVehicle[(_cachePos select 0), (_cachePos select 1)];
sleep 0.5;
_bomb = "grenade" createVehicle[(_cachePos select 0), (_cachePos select 1)];
sleep 0.5;
_bomb = "grenade" createVehicle[(_cachePos select 0), (_cachePos select 1)];

deleteMarker str(_markername2);

[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;

[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[] spawn fnc_missionTimer;
[_targetpos, _radius, "mission_destroy_cache"] spawn fnc_mission_cleanup;

missionNamespace setVariable ["current_mission_target_pos", nil];