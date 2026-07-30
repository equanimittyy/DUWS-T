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
// Local clamp: the setup menu broadcasts this once, so writing the global here would
// corrupt every later build on this machine with no re-broadcast to repair it.
private _mult = enemyunitMultiplier max 1;

for "_i" from 0 to (_mult - 1) step 1 do
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
_group = [[0,0], EAST, _bldgUnits,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;

// ========== 添加随机战利品 ==========
{
    [_x] call fnc_addRandomLoot;
} forEach units _group;
// =================================

// Sliced rather than walked whole: the loop this replaces capped itself on _forEachIndex, and
// _usableBuildings is the uncapped list here where the other two callers cap at selection.
[_group, _usableBuildings select [0, _maxBuildingsToUse], _unitsPerBuilding, "UP"] call fnc_spreadIntoBuildings;

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

private _fortPossibleUnitTypes = [[
    opfor_SOLDIER_X,
    opfor_AR_SOLDIER_X,
    opfor_GL_SOLDIER_X,
    opfor_LAT_SOLDIER_X,
    opfor_MARK_SOLDIER_X
]] call fnc_opforRoles;

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

        [_unit, _building, [_bldPos], "PIN"] spawn fnc_holdBuildingPost;

        [_unit] call fnc_addRandomLoot;
    } forEach units _fortGroup;
    
    ["INFO", "ZONES", format ["Added %1 garrison units to fortification %2", _unitCount, typeOf _building]] call fnc_log;
} forEach _uniqueBuildings;
// =============================================