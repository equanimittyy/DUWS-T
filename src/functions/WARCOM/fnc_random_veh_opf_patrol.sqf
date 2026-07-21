if (!isServer) exitWith {};
_faction = _this select 0;
_vehClass = _this select 1;
_position = _this select 2;
_radius = _this select 3;

// DETERMINE LA FACTION

_side = EAST; 

// Find a safe location FAR FROM ZONE CENTER (keeps buggy zone selection from surprising BLUFOR)
_vehpos = [[(_position select 0)+10, (_position select 1)+0],400,600,15,0,0.5,0,[],[]] call BIS_fnc_findSafePos;

// ARRAY of Random Vehicles

_car = selectRandomWeighted [
	opfor_ARMED_CAR1_X,1.0
];

_anyveh = "";
_airveh = "";
switch (VERSION_X) do {
	case "MODERN": {
		if (HeavyArmor == 1) then {
			_anyveh = selectRandomWeighted [
				opfor_COVERED_TRUCK_X,0.1,
				opfor_TRANS_TRUCK_X,0.1,
				opfor_AMMO_TRUCK_X,0.1,
				opfor_REPAIR_TRUCK_X,0.1,
				opfor_ARMED_CAR1_X,0.5,
				opfor_APC1_X,0.5,
				opfor_APC2_X,0.5,
				opfor_AA_APC_X,0.3,
				opfor_MBT_TANK1_X,0.8
			];
		} else {
			_anyveh = selectRandomWeighted [
				opfor_COVERED_TRUCK_X,0.1,
				opfor_TRANS_TRUCK_X,0.1,
				opfor_AMMO_TRUCK_X,0.1,
				opfor_REPAIR_TRUCK_X,0.1,
				opfor_ARMED_CAR1_X,1.0,
				opfor_APC1_X,1.0,
				opfor_APC2_X,1.0,
				opfor_AA_APC_X,0.5
			];
		};
		
		_airveh = selectRandomWeighted [
			opfor_TRANS_HELI_X,1.0,
			opfor_ATTACK_HELI_X,1.0,
			opfor_MISC_AIR_X,0.7
		];
	};
	
};	

_createdVehFnc = [];
if (_vehClass == "car") then {
	_createdVehFnc = [_vehpos,0,_car,_side] call bis_fnc_spawnvehicle;
} else {
	if (_vehClass == "air" && AttackHeli == 1) then {
_vec =[random [-1,0,1], random [-1,0,1], 0];
_dist = 2000 + random 3000;  // 修改为2000-5000米随机距离
_vehpos = ((vectorNormalized _vec) vectorMultiply _dist) vectorAdd _patrolCenter;
_vehpos = [_vehpos select 0, _vehpos select 1, (_vehpos select 2)+800];
		_createdVehFnc = [_vehpos,0,_airveh,_side] call bis_fnc_spawnvehicle;
	} else {
		_createdVehFnc = [_vehpos,0,_anyveh,_side] call bis_fnc_spawnvehicle;
	};	
};

_veh = _createdVehFnc select 0 ;// vehicle object

if (_vehClass == "air" && AttackHeli == 1) then {
	_veh engineOn true;
	switch (VERSION_X) do {
		case "MODERN": {
			_veh flyInHeight 150;
		};
	};
};

_vehGroup = _createdVehFnc select 2;
_vehGroup deleteGroupWhenEmpty true;
{
    [_x] call fnc_addRandomLoot;
} forEach units _vehGroup;
{
	if (_vehClass == "air" && VERSION_X == "MODERN") then {
		if !(("OPTRE" in BLUFOR_FactionFile_X) 
			or ("HL2ECR" in BLUFOR_FactionFile_X)
			or ("TIOW" in BLUFOR_FactionFile_X)) then {
			_x forceAddUniform "U_I_pilotCoveralls";
		};
	};
	_x setSkill opfor_ai_skill_random;
} foreach units _vehGroup;

// Set the waypoints
//hint format["%1",_patrolRadius];
[_vehGroup] spawn fnc_WARCOM_wp_opf_patrol;



