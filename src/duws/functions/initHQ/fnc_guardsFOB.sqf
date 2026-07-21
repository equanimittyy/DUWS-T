_centerPos = _this select 0;
_safe = [(_centerPos select 0)+10, (_centerPos select 1)+10];

_fob = _this select 1;
_id = _this select 2;

_size = 500;

// Create the guards
_groupGuard = [[0,0], WEST, [blufor_SOLDIER_X, blufor_SOLDIER_X, blufor_SOLDIER_X, blufor_SOLDIER_X],[],[],blufor_ai_skill] call BIS_fnc_spawnGroup; 
_groupGuard deleteGroupWhenEmpty true;

sleep 10;

_HQguard1 = units _groupGuard select 0;
//_HQguard1 addEventHandler ["Fired",{(_this select 0) setVehicleAmmo 1}];
_HQguard2 = units _groupGuard select 1;
//_HQguard2 addEventHandler ["Fired",{(_this select 0) setVehicleAmmo 1}];
_HQguard3 = units _groupGuard select 2;
//_HQguard3 addEventHandler ["Fired",{(_this select 0) setVehicleAmmo 1}];
_HQguard4 = units _groupGuard select 3;
//_HQguard4 addEventHandler ["Fired",{(_this select 0) setVehicleAmmo 1}];

switch (VERSION_X) do {
	case "MODERN": {
		//_HQguard1 = _groupGuard createUnit [blufor_SOLDIER_X, _centerPos, [], 0, "FORM"];
		_HQguard1 setpos [(_centerPos select 0)-6.5, (_centerPos select 1)-1.6];
		_HQguard1 setdir 270;
		//_HQguard2 = _groupGuard createUnit [blufor_SOLDIER_X, _centerPos, [], 0, "FORM"];
		_HQguard2 setpos [(_centerPos select 0)-6.5, (_centerPos select 1)-4.7];
		_HQguard2 setdir 270;
		//_HQguard3 = _groupGuard createUnit [blufor_SOLDIER_TL_X, _centerPos, [], 0, "FORM"];
		_HQguard3 setpos [(_centerPos select 0), (_centerPos select 1)-7.58];
		_HQguard3 setdir 180;
		//_HQguard4 = _groupGuard createUnit [blufor_SOLDIER_LAT_X, _centerPos, [], 0, "FORM"];
		_HQguard4 setpos [(_centerPos select 0), (_centerPos select 1)-9];
		_HQguard4 setdir 0;
	};
};

[_HQguard1,"STAND","FULL"] call BIS_fnc_ambientAnimCombat;
[_HQguard2,"STAND_IA","FULL"] call BIS_fnc_ambientAnimCombat;
[_HQguard3,"LEAN","FULL"] call BIS_fnc_ambientAnimCombat;
[_HQguard4,"STAND","FULL"] call BIS_fnc_ambientAnimCombat;

[_groupGuard, _centerPos] call bis_fnc_taskDefend;

// Patrolling Guards

_groupPatrol = [_safe, WEST, [blufor_SOLDIER_X],[],[],blufor_ai_skill] call BIS_fnc_spawnGroup; 
_groupPatrol deleteGroupWhenEmpty true;

//_HQguard5 = _groupPatrol createUnit [blufor_SOLDIER_GL_X, _centerPos, [], 0, "FORM"];
_HQguard5 = units _groupGuard select 0;
//_HQguard5 addEventHandler ["Fired",{(_this select 0) setVehicleAmmo 1}];

//_HQguard5 setpos [(_centerPos select 0)+10, (_centerPos select 1)+10];

_groupPatrol setCombatMode "WHITE";
_wp = _groupPatrol addWaypoint [[(_centerPos select 0)+10, (_centerPos select 1)+10], 0];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointSpeed "LIMITED";

_wp = _groupPatrol addWaypoint [[(_centerPos select 0)-10, (_centerPos select 1)+10], 0];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointSpeed "LIMITED";

_wp = _groupPatrol addWaypoint [[(_centerPos select 0)-10, (_centerPos select 1)-10], 0];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointSpeed "LIMITED";

_wp = _groupPatrol addWaypoint [[(_centerPos select 0)+10, (_centerPos select 1)-10], 0];
_wp setWaypointType "MOVE";

_wp = _groupPatrol addWaypoint [[(_centerPos select 0)+10, (_centerPos select 1)+10], 0];
_wp setWaypointType "CYCLE";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointSpeed "LIMITED";


// 添加守卫重置动作（防重）
if (isNil {_fob getVariable "FOB_guard_action_done"}) then {
    _fob setVariable ["FOB_guard_action_done", true];
    [_fob,[localize "STR_DUWS_T_p5i8fe14", fnc_reguardFOB, [_groupGuard, _groupPatrol, _centerPos, _fob, _id], 0, true, true, "", "_this == player"]] remoteExec ["addAction",_id,[false,true] select isDedicated];
};


