if (!isServer) exitWith {};
WARCOM_opf_attack_wave_type = "";
WARCOM_opf_attack_wave_avalaible = false;

// Type of attack wave
[] spawn {

	waitUntil {sleep 30; WARCOM_opfor_ap>=10};
	WARCOM_opf_attack_wave_avalaible = true;
	WARCOM_opf_attack_wave_type = opfor_INFTEAM_X;

	waitUntil {sleep 30; WARCOM_opfor_ap>40};          
    WARCOM_opf_attack_wave_type = opfor_INFSQUAD_X;
        
	waitUntil {sleep 30; WARCOM_opfor_ap>65};          
	WARCOM_opf_attack_wave_type = opfor_INFWEPSQUAD_X;

	switch (VERSION_X) do {
		case "MODERN": {
			waitUntil {sleep 30; WARCOM_opfor_ap>100};
			while {WARCOM_opfor_ap<136} do {
				WARCOM_opf_attack_wave_type = 
					[selectRandomWeighted [
						opfor_ARMED_CAR1_X,1.0,
						opfor_APC1_X,1.0,
						opfor_APC2_X,1.0,
						opfor_AA_APC_X,0.5
					]];
				sleep 30;
			};
			while {true} do {
				sleep 30;          
				if (HeavyArmor == 1) then {
					WARCOM_opf_attack_wave_type = 
						[selectRandomWeighted [
							opfor_MBT_TANK1_X,1.0,
							opfor_ARMED_CAR1_X,1.0,
							opfor_APC1_X,1.0,
							opfor_APC2_X,1.0,
							opfor_AA_APC_X,0.5
						]];
				} else {
					WARCOM_opf_attack_wave_type = 
						[selectRandomWeighted [
							opfor_ARMED_CAR1_X,1.0,
							opfor_APC1_X,1.0,
							opfor_APC2_X,1.0,
							opfor_AA_APC_X,0.5
						]];
				};	
			};
		};
	};
};

// Attack waves main
[] spawn {
        waitUntil {sleep 1800; WARCOM_opf_attack_wave_avalaible};   //Wait 30 min before first Assault

        while {true} do {
          sleep 2;
          
          // find a zone where to spawn OPF wave *** BEGIN
          _found = false;
          _randomZone = [];
		  _spawnLoc = [];
          _failSafe = 0;
		  _max = (count WARCOM_zones_controled_by_OPFOR) - 1;
		  if (count WARCOM_zones_controled_by_OPFOR > 1) then {
			while {!_found} do {
				//_randomZone = WARCOM_zones_controled_by_OPFOR call BIS_fnc_selectRandom;
				_randomZone = WARCOM_zones_controled_by_OPFOR select _failsafe;
				_spawnLoc = [[(_randomZone select 0), (_randomZone select 1)],400,600,15,0,0.3,0,[],[]] call BIS_fnc_findSafePos;
				_found = true;
				{
					if (_spawnLoc distance _x < 1500) then {_found=false};
				} forEach call BIS_fnc_ListPlayers;
				sleep 1;
				_failSafe = _failSafe + 1;
				if (_failsafe > _max) then {sleep 300; _failsafe = 0}
			};
		  };
          // find a zone *** end 
		
          if (count WARCOM_zones_controled_by_OPFOR < 1) then {
			_randomZone = WARCOM_zones_controled_by_OPFOR select 0;
			while {!_found} do {
				_found = true;
				_spawnLoc = [[(_randomZone select 0), (_randomZone select 1)],1000,1500,15,0,0.3,0,[],[]] call BIS_fnc_findSafePos;
				{
					if (_spawnloc distance _x < 1000 || _spawnLoc distance WARCOM_blu_hq_pos < 1000) then {_found=false};
				} forEach call BIS_fnc_ListPlayers;
			};
		  };
		  _group = "";
		  {
			if (WARCOM_opfor_ap>100) then {
				_group = [_spawnLoc, EAST, WARCOM_opf_attack_wave_type,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
				sleep 5;
				_addgroup = [_spawnLoc, EAST, opfor_INFTEAM_X,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
				sleep 5;
				_addgroup deleteGroupWhenEmpty true;
				(units _addgroup) joinSilent _group;
				_groupLeader = leader _group;
				_veh = vehicle _groupLeader;
				_group addVehicle _veh;
				_group deleteGroupWhenEmpty true;
			} else { 
				_group = [_spawnLoc, EAST, WARCOM_opf_attack_wave_type,[],[],opfor_ai_skill] call BIS_fnc_spawnGroup;
				_group deleteGroupWhenEmpty true;
			};
          
			sleep 10; // give squads a chance to mount up
			[_group,_spawnLoc] spawn fnc_WARCOM_wp_opf_assault;
			if (count WARCOM_zones_controled_by_BLUFOR == 0) exitWith {};  // 2 assault squads for BLU zones, 1 for BLUHQ
			[localize "STR_DUWS_T_allseer", localize "STR_DUWS_T_opfast"] remoteExec ["fnc_duws_dialogue", 0];
			sleep 120;
		  } forEach [1,2];

          if (count WARCOM_zones_controled_by_BLUFOR == 0) then {
			sleep floor (random [1800,2700,3600]);	// next HQ assault delay Rand 30-60 min
          } else {  
			sleep 1800;  // zone assaults have 2 spawns every 30 min
		  };
        };
};
