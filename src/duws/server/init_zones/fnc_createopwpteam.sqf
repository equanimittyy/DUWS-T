// Locality: server -- inherited from server/init_zones/fnc_zone_spawn_sizes.sqf.
// usage: [position, radius, setQRF] spawn fnc_createopwpteam
// radius: 50 for patrol inside and around base, 500 for medium, 1300 for island

_patrolCenter = _this select 0;
_radius   = _this select 1;

_position = [_patrolCenter,50,_radius,5,0,0.5,0,[],[]] call BIS_fnc_findSafePos;

// hint format["%1",_position];

_initGroup = [opfor_SOLDIER_X];
_multipliedGroup = [];
// Local clamp: the setup menu broadcasts this once, so writing the global here would
// corrupt every later build on this machine with no re-broadcast to repair it.
private _mult = enemyunitMultiplier max 1;
for "_i" from 0 to (_mult - 1) step 1 do
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

[_group, _patrolCenter, _patrolradius] call bis_fnc_taskPatrol;
// Returned for the callers that `call` this rather than `spawn` it -- the zone spawn band
// flags what it raised so the capture test can tell this zone's garrison from passers-by.
_group
