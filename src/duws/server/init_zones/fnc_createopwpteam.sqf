// Locality: server -- inherited from server/init_zones/fnc_zone_spawn_sizes.sqf.
// usage: [position, radius, setQRF] spawn fnc_createopwpteam
// radius: 50 for patrol inside and around base, 500 for medium, 1300 for island

_patrolCenter = _this select 0;
_radius   = _this select 1;

_position = [_patrolCenter,50,_radius,5,0,0.5,0,[],[]] call BIS_fnc_findSafePos;

// hint format["%1",_position];

_initGroup = [opfor_SOLDIER_X];
_multipliedGroup = [];
if (enemyunitMultiplier < 0) then {enemyunitMultiplier = 1};
for "_i" from 0 to (enemyunitMultiplier - 1) step 1 do
{
	_multipliedGroup = _multipliedGroup + _initGroup;
};
// add one AA and AT units per team so we don't get swarmed.
// Riflemans still multiplied.
_multipliedGroup = _multipliedGroup + [opfor_AA_SOLDIER_X,opfor_AT_SOLDIER_X, opfor_SPECOPS_MEDIC_X];
// task leader should be added after multiplication so we dont' get infinite TLs
_multipliedGroup = [_multipliedGroup, [opfor_TL_SOLDIER_X], 0] call BIS_fnc_arrayInsert;
_group = [_position, EAST, _multipliedGroup,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;

// ========== 添加随机战利品 ==========
{
    [_x] call fnc_addRandomLoot;
} forEach units _group;
// =================================

_patrolRadius = round(_radius/1.25);
[_group, _patrolCenter, _patrolradius] call bis_fnc_taskPatrol;

// Put an intel action on leader
if (hardcore_mode_enable && (random 10) < (master_Intel_chance + master_Intel_boost)) then {
	_leader = units _group select 0;
	_code = {[] spawn fnc_found_intel};
	[_leader, "Search for Intel", "search", _code] spawn fnc_actionRotary;
};