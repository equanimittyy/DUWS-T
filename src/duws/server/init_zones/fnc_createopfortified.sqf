// Locality: server -- inherited from server/init_zones/fnc_createzone.sqf.
// fnc_createopfortified.sqf
// Spawn guards around prefab and random units in buildings
_position = _this select 0;
_group = [];
// minimum positions to allow for building spawns
_positions_needed = 5;
// Radius to spawn troops in buildings
_radius = 250;

_spawn = [(_position select 0)+20,(_position select 1)];

//original group without leaders
_initGroup = [opfor_AR_SOLDIER_X,opfor_AT_SOLDIER_X,opfor_GL_SOLDIER_X, opfor_SPECOPS_MEDIC_X];
_multipliedGroup = [];
if (enemyunitMultiplier < 0) then {enemyunitMultiplier = 1};

for "_i" from 0 to (enemyunitMultiplier) step 1 do
    {
        _multipliedGroup = _multipliedGroup + _initGroup;
    };
// let's add squad leader now
_multipliedGroup = [_multipliedGroup, [opfor_SL_SOLDIER_X], 0] call BIS_fnc_arrayInsert;
_group = [_spawn, EAST, _multipliedGroup,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;

// ========== 添加随机战利品 ==========
{
    [_x] call fnc_addRandomLoot;
} forEach units _group;
// =================================

[_group, _position] call bis_fnc_taskDefend;

// Put an intel action on leader
if (hardcore_mode_enable && (random 10) < (master_Intel_chance + master_Intel_boost)) then {
	_leader = units _group select 0;
	_code = {[] spawn fnc_found_intel};
	[_leader, "Search for Intel", "search", _code] spawn fnc_actionRotary;
};

// Add a mortar team anyway
		_group = [_spawn, EAST, [opfor_SOLDIER_X,opfor_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
		(units _group select 0) addbackpack "O_Mortar_01_support_F";
		(units _group select 1) addbackpack "O_Mortar_01_weapon_F";
		[_group, _position] call BIS_fnc_taskDefend;
		// ========== 添加随机战利品 ==========
		{
		    [_x] call fnc_addRandomLoot;
		} forEach units _group;
		// =================================

_usableBuildings = [_position, _positions_needed, _radius] call fnc_usableBuildings;

_desiredBldgCount = 8;
_actualBldgCount = count _usableBuildings;
if (_actualBldgCount == 0) exitWith {};

_maxBuildingsToUse = (_actualBldgCount min _desiredBldgCount);
_unitsPerBuilding = 3;
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
_group = [[0,0], EAST, _bldgUnits,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;

// ========== 添加随机战利品 ==========
{
    [_x] call fnc_addRandomLoot;
} forEach units _group;
// =================================

{
    if (_forEachIndex >= _maxBuildingsToUse) exitWith {};
    _building = _x;
    _positions = [_building] call BIS_fnc_buildingPositions;
    for "_j" from 0 to (_unitsPerBuilding - 1) do {
        _unitIndex = _forEachIndex * _unitsPerBuilding + _j;
        if (_unitIndex >= count (units _group)) exitWith {};
        _unit = units _group select _unitIndex;
        if (count _positions > 0) then {
            _randPosIndex = floor (random (count _positions));
            _unit setPosATL (_building buildingPos _randPosIndex);
            _unit setUnitPos "UP";
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
                        _unit setUnitPos "UP";
                        private _timeout = time + 30;
                        waitUntil {
                            sleep 5;
                            (unitReady _unit) || 
                            (!alive _unit) || 
                            (_unit distance _targetPos < 2) || 
                            (time > _timeout)
                        };
                        sleep 5 + random 15;
                    } else {
                        sleep 10 + random 20;
                    };
                };
            };
        };
    };
} forEach _usableBuildings;

// ========== 为特定工事建筑添加驻军（改用 BIS_fnc_spawnGroup） ==========
private _fortificationClasses = [
    "Land_GuardTower_02_F",
    "Land_Cargo_Tower_V2_F",
    "Land_Cargo_Patrol_V2_F",
    "Land_BagBunker_Tower_F",
    "Land_Bunker_01_tall_F"
];
private _searchRadius = 300; // 在战区中心周围 300 米内搜索
private _foundBuildings = [];
{
    _foundBuildings append (nearestObjects [_position, [_x], _searchRadius]);
} forEach _fortificationClasses;

// 去重
private _uniqueBuildings = [];
{ if (!(_x in _uniqueBuildings)) then { _uniqueBuildings pushBack _x }; } forEach _foundBuildings;

private _fortPossibleUnitTypes = [
    opfor_SOLDIER_X,
    opfor_AR_SOLDIER_X,
    opfor_GL_SOLDIER_X,
    opfor_LAT_SOLDIER_X,
    opfor_MARK_SOLDIER_X
];

{
    private _building = _x;
    private _positions = [_building] call BIS_fnc_buildingPositions;
    if (count _positions == 0) then { continue };
    private _unitCount = 2 + floor random 3; // 2-4 名
    
    // 构建单位类型数组
    private _unitTypes = [];
    for "_j" from 1 to _unitCount do {
        _unitTypes pushBack (selectRandom _fortPossibleUnitTypes);
    };
    
    // 使用 BIS_fnc_spawnGroup 生成组
    private _fortGroup = [[0,0,0], EAST, _unitTypes, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
    _fortGroup deleteGroupWhenEmpty true;
    
    // 将单位分配到建筑位置
    {
        private _unit = _x;
        private _posIndex = _forEachIndex % count _positions;
        private _bldPos = _building buildingPos _posIndex;
        _unit setPosATL _bldPos;
        _unit setUnitPos "UP";
        _unit setBehaviour "AWARE";
        _unit setCombatMode "RED";
        
        // 监控确保单位保持在建筑内
        [_unit, _bldPos] spawn {
            params ["_unit", "_fixedPos"];
            sleep 1;
            while {alive _unit && {!isNull _unit}} do {
                if (_unit distance _fixedPos > 3) then {
                    _unit setPosATL _fixedPos;
                };
                sleep 5;
            };
        };
        
        [_unit] call fnc_addRandomLoot;
        if (hardcore_mode_enable && (random 10) < (master_Intel_chance + master_Intel_boost)) then {
            private _code = {[] spawn fnc_found_intel};
            [_unit, "Search for Intel", "search", _code] spawn fnc_actionRotary;
        };
    } forEach units _fortGroup;
    
    diag_log format ["[Zone] Added %1 garrison units to fortification %2", _unitCount, typeOf _building];
} forEach _uniqueBuildings;
// =============================================