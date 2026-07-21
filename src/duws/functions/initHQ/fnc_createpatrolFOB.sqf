// usage: [_foundPickupPos, _size] spawn fnc_createpatrolFOB;
// radius: 50 for patrol inside and around FOB, 500 for medium, 1300 for island

_position = _this select 0;
_radius   = _this select 1;

_group = [[(_position select 0)+200, (_position select 1)+200], WEST, [blufor_SOLDIER_TL_X,blufor_SOLDIER_X],[],[],blufor_ai_skill] call BIS_fnc_spawnGroup;
_patrolRadius = round(_radius/3);
[_group, _position, _patrolRadius] call bis_fnc_taskPatrol;