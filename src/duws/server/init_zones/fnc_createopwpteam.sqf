// Locality: server -- inherited from server/init_zones/fnc_zone_spawn_sizes.sqf.
// usage: [position, radius, setQRF] spawn fnc_createopwpteam
// radius: 50 for patrol inside and around base, 500 for medium, 1300 for island

_patrolCenter = _this select 0;
_radius   = _this select 1;

_position = [_patrolCenter,50,_radius,5,0,0.5,0,[],[]] call BIS_fnc_findSafePos;

// hint format["%1",_position];

private _roster = ["wpteam", enemyunitMultiplier] call DUWS_fnc_groupRoster;
_group = [_position, EAST, _roster,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
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
