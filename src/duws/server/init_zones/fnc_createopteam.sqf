// Locality: server -- called from the zone spawn sizing and mission patrol builders, all
// server-side.
// usage: [position, radius] spawn fnc_createopteam
// radius: 50 for patrol inside and around base, 500 for medium, 1300 for island

_patrolCenter = _this select 0;
_radius   = _this select 1;

_position = [_patrolCenter,50,_radius,5,0,0.5,0,[],[]] call BIS_fnc_findSafePos;

_initGroup = [opfor_AR_SOLDIER_X,opfor_GL_SOLDIER_X];
_multipliedGroup = [];
if (enemyunitMultiplier < 0) then {enemyunitMultiplier = 1};
for "_i" from 0 to (enemyunitMultiplier - 1) step 1 do
{
	_multipliedGroup = _multipliedGroup + _initGroup;
};
// add more units into squad with launchers and marksman rifles only once
// so we don't get swarmed by 5x snipers and 5x AT
_multipliedGroup = _multipliedGroup + [opfor_MARK_SOLDIER_X,opfor_LAT_SOLDIER_X];
// task leader should be added after multiplication so we dont' get X TLs
_multipliedGroup = _multipliedGroup + [opfor_TL_SOLDIER_X];
_group = [_position, EAST, _multipliedGroup,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
_group deleteGroupWhenEmpty true;

// ========== 添加随机战利品 ==========
{
    [_x] call fnc_addRandomLoot;
} forEach units _group;
// =================================

_patrolRadius = round(_radius/2);
[_group, _patrolCenter, _patrolradius] call bis_fnc_taskPatrol;