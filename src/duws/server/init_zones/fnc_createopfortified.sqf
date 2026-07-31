// Locality: server -- inherited from server/init_zones/fnc_createzone.sqf.
// fnc_createopfortified.sqf
// Spawn guards around prefab and random units in buildings
_position = _this select 0;
// Every group raised here is part of the zone's garrison, and the capture test counts the roster
// rather than whatever happens to be standing nearby -- so anything spawned here and not appended
// is invisible to it, and the zone reads as beaten while its emplacements are still manned.
_zoneKey = _this param [1, ""];
if (_zoneKey == "") then { _zoneKey = [_position] call fnc_zone_key };
private _roster = [_zoneKey] call fnc_zone_roster;
// Rostering and flagging are one act: a group that defends the zone is a group whose bodies are
// worth searching, and separating them is how the spawn band ended up rostered but unflagged.
private _fnc_own = {
    params ["_g"];
    _roster append (units _g);
    [_g, "garrison"] call fnc_search_flag_group;
};
// The zone redeploys at whatever its garrison was ground down to, and this half of it has to shrink
// with the spawn band: at three tenths strength a zone still holding every building and every tower
// would be no thinner where the player actually fights it.
private _strength = [_zoneKey] call fnc_zone_strength;
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
// Thinned before the leader is inserted, so a section that has taken losses still has one.
_multipliedGroup = [_multipliedGroup, _strength] call fnc_zone_thin;
// let's add squad leader now
_multipliedGroup = [_multipliedGroup, [opfor_SL_SOLDIER_X], 0] call BIS_fnc_arrayInsert;
_group = [_spawn, EAST, _multipliedGroup,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;
[_group] call _fnc_own;

// ========== 添加随机战利品 ==========
// Scattered on a ring before taskDefend rather than left to walk apart. Zones stream in, so a
// garrison spawns while BLUFOR are already close enough to watch it happen: on one point it reads
// as a clump appearing out of nothing and then filing outward, and a defence stacked on the centre
// is one the player can fight from a single angle. Spread wide, they have to be dug out.
//
// findEmptyPosition rather than BIS_fnc_findSafePos: this runs once per unit on the frame budget
// of a player arriving, and the safe-pos search is the expensive one. The ring does the spreading;
// the lookup only keeps a body out of a wall, and falls back to the bare ring point.
{
    [_x] call fnc_addRandomLoot;
    private _ring = _position getPos [40 + random 110, random 360];
    private _spot = _ring findEmptyPosition [0, 15, typeOf _x];
    _x setPos ([_spot, _ring] select (_spot isEqualTo []));
} forEach units _group;
// =================================

// Radius passed rather than defaulted: taskDefend defends 50 m unless told otherwise, and treats
// anyone outside that as out of position -- so it would walk the ring back onto the centre and
// undo the spread above. It has to describe the same ground the units were just placed on.
[_group, _position, 150] call bis_fnc_taskDefend;


// Add a mortar team anyway
// Not thinned with the rest: two men, and the zone's only indirect fire. Scaling a pair by a
// fraction takes the tube away entirely, which changes what the zone is rather than how strong.
		_group = [_spawn, EAST, [opfor_SOLDIER_X,opfor_SOLDIER_X],[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
		[_group] call _fnc_own;
		(units _group select 0) addbackpack "O_Mortar_01_support_F";
		(units _group select 1) addbackpack "O_Mortar_01_weapon_F";
		// Left on the centre while the rifles fan out. The tube and its ammunition are a backpack
		// each on the two different men, so the pair has to stay together, and a mortar belongs
		// behind the position it is firing over rather than out on the perimeter with the patrols.
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
// Fewer buildings held rather than fewer men in each: three to a house is what makes clearing one
// cost something, and a house with a single man in it is a house the player walks through.
_maxBuildingsToUse = ((ceil (_strength * _maxBuildingsToUse)) max 1);
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
[_group] call _fnc_own;

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
// Towers left empty rather than held thinly, for the same reason the houses above are.
_uniqueBuildings = [_uniqueBuildings, _strength] call fnc_zone_thin;

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
    [_fortGroup] call _fnc_own;
    
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