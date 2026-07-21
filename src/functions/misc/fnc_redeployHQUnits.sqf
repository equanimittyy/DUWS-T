if (!isServer) exitWith {};

if (commandpointsblu1 < 2) exitWith {
    [localize "STR_DUWS_T_REDEPLOY_COST_TITLE", format [localize "STR_DUWS_T_REDEPLOY_COST", 2]] remoteExec ["BIS_fnc_showNotification", 0];
};

commandpointsblu1 = commandpointsblu1 - 2;
publicVariable "commandpointsblu1";

// ---------- 清理旧对象 ----------
// 武器
private _oldWeaponList = missionNamespace getVariable ["HQ_redeploy_weaponList", []];
{ if (!isNull _x) then { deleteVehicle _x; }; } forEach _oldWeaponList;

// 人员组
private _groupsToDelete = [
    "HQ_redeploy_weaponGroup",
    "HQ_redeploy_hqGuardsGroup0",
    "HQ_redeploy_hqGuardsGroup1",
    "HQ_redeploy_medGuardsGroup0",
    "HQ_redeploy_medGuardsGroup1",
    "HQ_redeploy_guardBoxGroup",
    "HQ_redeploy_patrolGroup"
];
{
    private _grp = missionNamespace getVariable [_x, grpNull];
    if (!isNull _grp) then {
        { deleteVehicle _x; } forEach (units _grp);
        deleteGroup _grp;
    };
} forEach _groupsToDelete;

// 塔卫
private _towerGuards = missionNamespace getVariable ["HQ_redeploy_towerGuards", []];
{
    if (!isNull _x) then {
        { deleteVehicle _x; } forEach (units _x);
        deleteGroup _x;
    };
} forEach _towerGuards;

// ---------- 重新生成 ----------
private _guardTypes = missionNamespace getVariable ["HQ_redeploy_guardTypes", [blufor_SOLDIER_X]];

// 1. 武器与炮手
private _mgAnchor = missionNamespace getVariable ["HQ_redeploy_mgAnchor", objNull];
private _aaData = missionNamespace getVariable ["HQ_redeploy_aaData", []];
private _newWeaponList = [];

if (!isNull _mgAnchor) then {
    private _xyWorld = _mgAnchor modelToWorld [-0.3172, -2.36523, 0];
    private _worldPos = [
        _xyWorld select 0,
        _xyWorld select 1,
        (getPosWorld _mgAnchor select 2) + 1.21321
    ];
    private _obj = createVehicle ["I_HMG_02_high_F", _worldPos, [], 0, "CAN_COLLIDE"];
    _obj enableSimulation false;
    _obj setPosWorld _worldPos;
    _obj setDir ([_worldPos, getPosWorld _mgAnchor] call BIS_fnc_dirTo);
    _newWeaponList pushBack _obj;
};

{
    _x params ["_class", "_xyModel", "_hOffset"];
    private _hqObj = bluHQ_object;
    private _xyWorld = _hqObj modelToWorld [_xyModel select 0, _xyModel select 1, 0];
    private _worldPos = [
        _xyWorld select 0,
        _xyWorld select 1,
        (getPosWorld _hqObj select 2) + _hOffset
    ];
    private _obj = createVehicle [_class, _worldPos, [], 0, "CAN_COLLIDE"];
    _obj enableSimulation false;
    _obj setPosWorld _worldPos;
    _obj setDir (getDir _hqObj);
    _newWeaponList pushBack _obj;
} forEach _aaData;

if (count _newWeaponList > 0) then {
    private _unitTypes = [];
    for "_i" from 1 to (count _newWeaponList) do { _unitTypes pushBack blufor_SOLDIER_X };
    private _spawnPos = PosOfBLUHQ findEmptyPosition [0, 50];
    if (count _spawnPos == 0) then { _spawnPos = PosOfBLUHQ; };
    private _group = [_spawnPos, WEST, _unitTypes, [], [], [0.4,0.6]] call BIS_fnc_spawnGroup;
    _group deleteGroupWhenEmpty true;
    { (units _group select _forEachIndex) moveInGunner _x; } forEach _newWeaponList;
    { _x enableSimulation true; } forEach _newWeaponList;
    missionNamespace setVariable ["HQ_redeploy_weaponGroup", _group, true];
    missionNamespace setVariable ["HQ_redeploy_weaponList", _newWeaponList, true];
};

// 2. HQ门口双人组
private _hqGuardsData = missionNamespace getVariable ["HQ_redeploy_hqGuardsData", []];
private _hqGuardsGroups = [];
{
    _x params ["_xyModel", "_hOffset", "_dir", "_anim"];
    private _hqObj = bluHQ_object;
    private _xyWorld = _hqObj modelToWorld [_xyModel select 0, _xyModel select 1, 0];
    private _worldPos = [
        _xyWorld select 0,
        _xyWorld select 1,
        (getPosWorld _hqObj select 2) + _hOffset
    ];
    private _type = selectRandom _guardTypes;
    private _grp = [_worldPos, WEST, [_type], [], [], [0.4,0.6]] call BIS_fnc_spawnGroup;
    private _unit = (units _grp) select 0;
    _unit allowDamage true;
    _unit enableSimulation false;
    _unit setPosWorld _worldPos;
    _unit setUnitPos "UP";
    _unit disableAI "PATH";
    _unit setDir _dir;
    [_unit, _anim, "FULL"] call BIS_fnc_ambientAnimCombat;
    _hqGuardsGroups pushBack _grp;
    [_unit] spawn {
        params ["_u"];
        sleep 0.5;
        if (!isNull _u && alive _u) then { _u enableSimulation true; };
    };
} forEach _hqGuardsData;
missionNamespace setVariable ["HQ_redeploy_hqGuardsGroup0", _hqGuardsGroups select 0, true];
missionNamespace setVariable ["HQ_redeploy_hqGuardsGroup1", _hqGuardsGroups select 1, true];

// 3. 医疗帐篷双人组
private _medGuardsData = missionNamespace getVariable ["HQ_redeploy_medGuardsData", []];
private _medTent = objectFromNetId (missionNamespace getVariable ["HQ_medTent_netId", ""]);
private _medGuardsGroups = [];
{
    _x params ["_xyModel", "_hOffset", "_anim"];
    private _xyWorld = _medTent modelToWorld [_xyModel select 0, _xyModel select 1, 0];
    private _worldPos = [
        _xyWorld select 0,
        _xyWorld select 1,
        (getPosWorld _medTent select 2) + _hOffset
    ];
    private _type = selectRandom _guardTypes;
    private _grp = [_worldPos, WEST, [_type], [], [], [0.4,0.6]] call BIS_fnc_spawnGroup;
    private _unit = (units _grp) select 0;
    _unit allowDamage true;
    _unit enableSimulation false;
    _unit setPosWorld _worldPos;
    _unit setUnitPos "UP";
    _unit disableAI "PATH";
    _unit setDir ((getDir _medTent) + 180);
    [_unit, _anim, "FULL"] call BIS_fnc_ambientAnimCombat;
    _medGuardsGroups pushBack _grp;
    [_unit] spawn {
        params ["_u"];
        sleep 0.5;
        if (!isNull _u && alive _u) then { _u enableSimulation true; };
    };
} forEach _medGuardsData;
missionNamespace setVariable ["HQ_redeploy_medGuardsGroup0", _medGuardsGroups select 0, true];
missionNamespace setVariable ["HQ_redeploy_medGuardsGroup1", _medGuardsGroups select 1, true];

// 4. 警卫室士兵
private _guardBoxObj = objectFromNetId (missionNamespace getVariable ["HQ_guardBox_netId", ""]);
if (!isNull _guardBoxObj) then {
    private _bestPos = [0,0,0];
    private _idx = 0;
    while {true} do {
        private _pos = _guardBoxObj buildingPos _idx;
        if (_pos isEqualTo [0,0,0]) exitWith {};
        if ((_pos select 2) > (_bestPos select 2)) then { _bestPos = _pos };
        _idx = _idx + 1;
    };
    if (_bestPos isEqualTo [0,0,0]) then {
        _bestPos = getPosATL _guardBoxObj;
        _bestPos set [2, (_bestPos select 2) + 0.5];
    };
    private _type = selectRandom _guardTypes;
    private _grp = [_bestPos, WEST, [_type], [], [], [0.4,0.6]] call BIS_fnc_spawnGroup;
    private _unit = (units _grp) select 0;
    _unit allowDamage true;
    _unit enableSimulation false;
    _unit setPosWorld _bestPos;
    _unit setUnitPos "UP";
    _unit disableAI "PATH";
    _unit setDir ((getDir _guardBoxObj) + 180);
    [_unit, "STAND", "FULL"] call BIS_fnc_ambientAnimCombat;
    [_unit] spawn {
        params ["_u"];
        sleep 0.5;
        if (!isNull _u && alive _u) then { _u enableSimulation true; };
    };
    missionNamespace setVariable ["HQ_redeploy_guardBoxGroup", _grp, true];
};

// 5. 塔卫（关键修复）
private _allTowersList = missionNamespace getVariable ["HQ_redeploy_towers", []];
private _newTowerGuards = [];
{
    private _tower = _x;
    private _towerPos = getPosWorld _tower;
    private _xyWorld = _tower modelToWorld [0.05, 1.47, 0];
    private _worldPos = [
        _xyWorld select 0,
        _xyWorld select 1,
        (_towerPos select 2) + 1.6369
    ];
    private _grp = [_worldPos, WEST, [blufor_SOLDIER_X], [], [], [0.4,0.6]] call BIS_fnc_spawnGroup;
    private _unit = (units _grp) select 0;
    _unit allowDamage true;
    _unit enableSimulation false;
    _unit setPosWorld _worldPos;
    _unit setUnitPos "UP";
    _unit disableAI "PATH";
    _unit setDir (getDir _tower);
    [_unit, selectRandom ["STAND_IA","STAND"], "FULL"] call BIS_fnc_ambientAnimCombat;
    _newTowerGuards pushBack _grp;
    [_unit] spawn {
        params ["_u"];
        sleep 2.5;
        if (!isNull _u && alive _u) then { _u enableSimulation true; };
    };
} forEach _allTowersList;
missionNamespace setVariable ["HQ_redeploy_towerGuards", _newTowerGuards, true];

// 6. 巡逻队
private _patrolSpawnPos = missionNamespace getVariable ["HQ_redeploy_patrolSpawnPos", []];
private _patrolUnits = missionNamespace getVariable ["HQ_redeploy_patrolUnits", []];
if (count _patrolSpawnPos > 0 && count _patrolUnits > 0) then {
    private _patrolGroup = [_patrolSpawnPos, WEST, _patrolUnits, [], [], [0.4,0.6]] call BIS_fnc_spawnGroup;
    _patrolGroup deleteGroupWhenEmpty true;
    {
        _x allowDamage false;
        _x enableSimulation false;
        _x setPosWorld _patrolSpawnPos;
    } forEach (units _patrolGroup);
    while {count (waypoints _patrolGroup) > 0} do { deleteWaypoint ((waypoints _patrolGroup) select 0); };
    {
        private _tower = _x;
        private _dir = getDir _tower;
        private _wpPos = _tower getPos [15, _dir];
        private _wp = _patrolGroup addWaypoint [_wpPos, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "LIMITED";
        _wp setWaypointBehaviour "SAFE";
    } forEach _allTowersList;
    private _firstTower = _allTowersList select 0;
    private _cyclePos = _firstTower getPos [8, getDir _firstTower];
    private _wpCycle = _patrolGroup addWaypoint [_cyclePos, 0];
    _wpCycle setWaypointType "CYCLE";
    _wpCycle setWaypointSpeed "LIMITED";
    _wpCycle setWaypointBehaviour "SAFE";
    [_patrolGroup] spawn {
        params ["_grp"];
        sleep 1.5;
        {
            if (!isNull _x && alive _x) then {
                _x enableSimulation true;
                _x allowDamage true;
            };
        } forEach (units _grp);
    };
    missionNamespace setVariable ["HQ_redeploy_patrolGroup", _patrolGroup, true];
};

[localize "STR_DUWS_T_REDEPLOY_SUCCESS"] remoteExec ["hint", 0];