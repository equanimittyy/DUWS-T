// Locality: server only -- supports/fnc_fob_server.sqf on build, fnc_refortifyFOB via
// remoteExec target 2 on refortify. A FOB's turrets are campaign property, so spawning them
// on the refortifying client would leave them simulated there and orphaned on disconnect.
if (!isServer) exitWith {};

params ["_centerPos", "_fob", ["_refortify", false], ["_refundOnBusy", 0]];

// One rebuild at a time. The scroll action lives on every machine, so two players can fire it
// at once; without this the second would spawn a duplicate ring over the first. The charge is
// still taken client-side before the request arrives, so the loser is refunded here.
if (_fob getVariable ["FOB_fortify_busy", false]) exitWith {
	if (_refundOnBusy > 0) then { [_refundOnBusy] remoteExec ["fnc_cp_adjust", 2]; };
};
_fob setVariable ["FOB_fortify_busy", true];

// Refortify replaces the previous ring rather than adding to it. The current turrets are read
// off the FOB instead of passed in, so no copy of the scroll action can hold stale references
// after another player rebuilds. Server-local: only this machine ever reads them.
{ { deleteVehicle _x } forEach (crew _x); deleteVehicle _x; } forEach (_fob getVariable ["FOB_turrets", []]);

_safe = [(_centerPos select 0)+10, (_centerPos select 1)+10];

playSound "loadgun";

_groupGuard = [[0,0], WEST, [blufor_SOLDIER_X, blufor_SOLDIER_X, blufor_SOLDIER_X, blufor_SOLDIER_X, blufor_SOLDIER_X],[],[],blufor_ai_skill] call BIS_fnc_spawnGroup; 
_groupGuard deleteGroupWhenEmpty true;

_fobGuard1 = units _groupGuard select 0;
_fobGuard2 = units _groupGuard select 1;
_fobGuard3 = units _groupGuard select 2;
_fobGuard4 = units _groupGuard select 3;
_fobGuard5 = units _groupGuard select 4;

_forty_spawn = {
	_name = _this select 0;
	_center = _this select 1;
	_offset = _this select 2;

	_newx = (_center select 0) + (_offset select 0);
	_newy = (_center select 1) + (_offset select 1);
	_newz = (_offset select 2);

	_new = createVehicle [_name, [0,0,0], [], 0, "CAN_COLLIDE"];
	_new allowdamage false;
	_new setpos [_newx, _newy, _newz];
	_new setdamage 0;
	_new
};

// REFORTIFY STATICS
_turret1 = "";
_turret2 = "";
_turret3 = "";
_turret4 = "";
_turret5 = "";

_glPod1 = "";
_glPod2 = "";
_turret3 = "";
_hmgPod1 = "";
_aaPod = "";

switch (VERSION_X) do {
	case "MODERN": {
		// GMG
		//_sandbags = ["land_bagfence_round_f",_centerPos,[9.5,9,0]] call _forty_spawn;
		_turret1 = [blufor_TURRET_GMG,_centerPos,[9,9.5,0]] call _forty_spawn;
		//_sandbags setDir(getPosWorld _turret1 getDir _centerPos); //try to situate this guy radially
		_turret1 setDir( _centerPos getDir getPosWorld _turret1); //try to situate this guy radially
		//_turret1 addEventHandler ["Fired",{(_this select 0) setVehicleAmmo 1}];
		// GMG
		//_sandbags = ["land_bagfence_round_f",_centerPos,[-9,7,0]] call _forty_spawn;
		_turret2 = [blufor_TURRET_GMG,_centerPos,[-8.5,7.5,0]] call _forty_spawn;
		//_sandbags setDir(getPosWorld _turret2 getDir _centerPos); //try to situate this guy radially
		_turret2 setDir( _centerPos getDir getPosWorld _turret2); //try to situate this guy radially
		//_turret2 addEventHandler ["Fired",{(_this select 0) setVehicleAmmo 1}];
		// AT
		//_sandbags = ["land_bagfence_round_f",_centerPos,[-9,-10.8,-0.3]] call _forty_spawn;
		_turret3 = [blufor_TURRET_AT,_centerPos,[-8,-9,0]] call _forty_spawn;
		//_sandbags setDir(getPosWorld _turret3 getDir _centerPos); //try to situate this guy radially
		_turret3 setDir( _centerPos getDir getPosWorld _turret3); //try to situate this guy radially
		//_turret3 addEventHandler ["Fired",{(_this select 0) setVehicleAmmo 1}];
		// HMG
		//_sandbags = ["land_bagfence_round_f",_centerPos,[10.2,-10.7,0]] call _forty_spawn;
		_turret4 = [blufor_TURRET_HMG,_centerPos,[9.5,-9.5,0]] call _forty_spawn;
		//_sandbags setDir(getPosWorld _turret4 getDir _centerPos); //try to situate this guy radially
		_turret4 setDir( _centerPos getDir getPosWorld _turret4); //try to situate this guy radially
		//_turret4 addEventHandler ["Fired",{(_this select 0) setVehicleAmmo 1}];
		// AA on the roof
		_tempPos = _fob buildingPos 5;
		_turret5 = createVehicle [blufor_TURRET_AA, [0,0,0], [], 0, "CAN_COLLIDE"];
		_turret5 setPosATL [(_tempPos select 0)-3, (_tempPos select 1)-5, _tempPos select 2];
		//_turret5 = [blufor_TURRET_AA,_centerPos,[0,0,2.9]] call _forty_spawn;
		//_turret5 addEventHandler ["Fired",{(_this select 0) setVehicleAmmo 1}];
	};
};	

//////////////////
// PERM Statics
//////////////////

if !(_refortify) then {
	switch (VERSION_X) do {
		case "MODERN": {
			_hesco = ["Land_HBarrier_1_F",_centerPos,[-10,4.5,0]] call _forty_spawn;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[-10,3,0]] call _forty_spawn;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[-10,1.5,0]] call _forty_spawn;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[-10,0,0]] call _forty_spawn;
			//_hesco = ["Land_HBarrier_1_F",_centerPos,[-10,-1.5,0]] call _forty_spawn;
			//_hesco = ["Land_HBarrier_1_F",_centerPos,[-10,-4.5,0]] call _forty_spawn;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[-10,-6,0]] call _forty_spawn;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[-10,-7.5,0]] call _forty_spawn;
	
			_hesco = ["Land_HBarrier_1_F",_centerPos,[-6,-11.5,0]] call _forty_spawn;
			_hesco setDir 90;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[-4.5,-11.5,0]] call _forty_spawn;
			_hesco setDir 90;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[-3,-11.5,0]] call _forty_spawn;
			_hesco setDir 90;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[-1.5,-11.5,0]] call _forty_spawn;
			_hesco setDir 90;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[0,-11.5,0]] call _forty_spawn;
			_hesco setDir 90;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[1.5,-11.5,0]] call _forty_spawn;
			_hesco setDir 90;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[3,-11.5,0]] call _forty_spawn;
			_hesco setDir 90;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[4.5,-11.5,0]] call _forty_spawn;
			_hesco setDir 90;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[6,-11.5,0]] call _forty_spawn;
			_hesco setDir 90;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[7.5,-11.5,0]] call _forty_spawn;
			_hesco setDir 90;
		
			//_sandbags = ["land_bagfence_end_f",_centerPos,[10.5,-8,0]] call _forty_spawn;
			//_sandbags setDir 270;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[11,-7,0]] call _forty_spawn;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[11,-5.5,0]] call _forty_spawn;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[11,-4,0]] call _forty_spawn;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[11,-2.5,0]] call _forty_spawn;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[11,-1,0]] call _forty_spawn;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[11,0.5,0]] call _forty_spawn;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[11,2,0]] call _forty_spawn;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[11,3.5,0]] call _forty_spawn;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[11,5,0]] call _forty_spawn;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[11,6.5,0]] call _forty_spawn;
	
			_hesco = ["Land_HBarrier_1_F",_centerPos,[6.5,10,0]] call _forty_spawn;
			_hesco setDir 90;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[5,10,0]] call _forty_spawn;
			_hesco setDir 90;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[3.5,10,0]] call _forty_spawn;
			_hesco setDir 90;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[2,10,0]] call _forty_spawn;
			_hesco setDir 90;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[0.5,10,0]] call _forty_spawn;
			_hesco setDir 90;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[-1,10,0]] call _forty_spawn;
			_hesco setDir 90;
			//_hesco = ["Land_HBarrier_1_F",_centerPos,[-2.5,10,0]] call _forty_spawn;
			//_hesco setDir 90;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[-5.5,10,0]] call _forty_spawn;
			_hesco setDir 90;
			_hesco = ["Land_HBarrier_1_F",_centerPos,[-7,10,0]] call _forty_spawn;
			_hesco setDir 90;
	
			// LIGHTS
			//["Land_Camping_Light_F",_foundPickupPos,[0,0,2]] call _forty_spawn;
			["Land_Camping_Light_F",_centerPos,[5.5,-5.5,0]] call _forty_spawn;
			["Land_Camping_Light_F",_centerPos,[-5.5,3.5,0]] call _forty_spawn;
			["Land_Camping_Light_F",_centerPos,[5.5,3.5,0]] call _forty_spawn;
			["Land_Camping_Light_F",_centerPos,[-5.5,-5.5,0]] call _forty_spawn;
			["Land_Camping_Light_F",_centerPos,[-2.75,-2.75,0]] call _forty_spawn;
			["Land_Camping_Light_F",_centerPos,[-2.75,2.75,0]] call _forty_spawn;
			["Land_Camping_Light_F",_centerPos,[2.75,2.75,0]] call _forty_spawn;
			["Land_Camping_Light_F",_centerPos,[2.75,2.75,1]] call _forty_spawn;
		};
	};
};

sleep 10;
_fobGuard1 setpos _centerPos;
_fobGuard2 setpos _centerPos;
_fobGuard3 setpos _centerPos;
_fobGuard4 setpos _centerPos;
_fobGuard5 setpos _centerPos;
_fobGuard1 moveinGunner _turret1;
_fobGuard2 moveinGunner _turret2;
_fobGuard3 moveinGunner _turret3;
_fobGuard4 moveinGunner _turret4;
_fobGuard5 moveinGunner _turret5;

sleep 50;
_turret1 allowdamage false;
_turret2 allowdamage false;
_turret3 allowdamage false;
_turret4 allowdamage false;
_turret5 allowdamage false;

[_groupGuard, _centerPos] call bis_fnc_taskDefend;

_fob setVariable ["FOB_turrets", [_turret1, _turret2, _turret3, _turret4, _turret5]];
_fob setVariable ["FOB_fortify_busy", false];

// Added once, to every machine that has a player and to JIP joiners, so any player can
// refortify rather than only whoever built the FOB. Same targeting as supports/fnc_FOBactions.
// It carries no arguments: the action's target is the FOB itself and the server reads the
// rest, so it never needs removing and re-adding.
if (!_refortify) then {
	[_fob,[localize "STR_DUWS_T_qxrh9fws", fnc_refortifyFOB, [], 0, true, true, "", "_this == player"]] remoteExec ["addAction", [0,-2] select isDedicated, true];
};




