if (!isServer) exitWith {};
_loop = true;

WARCOM_blu_patrol_type = "";
diag_log format ["WARCOM_blufor_ap_patrol: %1", WARCOM_blufor_ap];

// Type of patrol
[] spawn {

	WARCOM_blu_patrol_type = (blufor_RECON_TEAM_X select 0);

	waitUntil {sleep 30; WARCOM_blufor_ap>40};          
	WARCOM_blu_patrol_type = (blufor_INF_SQUAD_X select 0); 
          
	switch (VERSION_X) do {
		case "MODERN": {
			waitUntil {sleep 30; WARCOM_blufor_ap>65};          
			WARCOM_blu_patrol_type = (blufor_MOTOR_SECTION_X select 0); 
          
			waitUntil {sleep 30; WARCOM_blufor_ap>100};          
			while {WARCOM_blufor_ap<136} do {
				WARCOM_blu_patrol_type = selectRandom [
					(blufor_MECH_SECTION_X select 0),
					(blufor_MECH_SECTION_X select 0),
					(blufor_MOTOR_SECTION_X select 0)
				];
				sleep 30;
			};
			while {true} do {
				sleep 30;          
				WARCOM_blu_patrol_type = selectRandom [
					(blufor_ARMOR_SECTION_X select 0),
					(blufor_ARMOR_SECTION_X select 0),
					(blufor_MECH_SECTION_X select 0),
					(blufor_MOTOR_SECTION_X select 0)
				];
			};
		};
	};
};


sleep 200;  // wait for "Type of Patrol" to get the proper AP

////////////////////////////////
// Patrol main infinite loop
///////////////////////////////

blufor_patrol_count = 0;

[] spawn {

        while {true} do {
		  
			// As soon as extended Campaign (DOMINATION) starts, stop creating patrols 
			if (DUWS_MODE == "DOMINATION") exitWith {};

			// make sure blufor is controlling at least 1 zones and blufor_patrol_count <= total zones
			if (count WARCOM_zones_controled_by_BLUFOR > 0 && blufor_patrol_count <= ((count WARCOM_zones_controled_by_BLUFOR)-1)) then { 
				sleep 2;
				diag_log format ["WARCOM blufor patrol active: %1", str WARCOM_blu_patrol_type];

				// find a zone where to spawn BLU wave *** BEGIN
				_found = false;
				_randomZone = [];
				_failSafe = 0;
				while {!_found} do {
					_randomZone = WARCOM_zones_controled_by_BLUFOR call BIS_fnc_selectRandom;
					// Nearest of all players, not `player`: this loop runs on the server,
					// where player is objNull on a dedicated host so the keep-out always
					// passed, and on a hosted server it only ever measured the host.
					if ((allPlayers findIf {_randomZone distance _x <= 500}) < 0) then {_found=true;};
					sleep 0.2;
					_failSafe = _failSafe + 1;
					if (_failsafe > 10) then {sleep 300; _failsafe = 0;}
				};
				// find a zone *** end 

				// Find a safe position
				//_randomZone = [(_randomZone select 0)+40,_randomZone select 1];
				_spawnLoc = [[(_randomZone select 0), (_randomZone select 1)],300,500,10,0,0.3,0,[],[]] call BIS_fnc_findSafePos;
				_group = "";
				
				_group = [_spawnLoc, WEST, WARCOM_blu_patrol_type,[],[],blufor_ai_skill] call BIS_fnc_spawnGroup;
				sleep 5;
				_groupLeader = leader _group;
				_veh = vehicle _groupLeader;
				_group addVehicle _veh;
				_group deleteGroupWhenEmpty true;
				diag_log format ["WARCOM blufor patrol spawned: %1", str WARCOM_blu_patrol_type];

				sleep 10; // give squads a chance to mount up
				[_group] spawn fnc_WARCOM_wp_blu_patrol;
				//[_group,"derp"] spawn fnc_WARCOM_gps_marker;  

				// SPAWN VEHICLE
				switch (VERSION_X) do {
					case "MODERN": {
						// spawn car
						if (WARCOM_blufor_ap>99) then {
							[BLUFOR_Faction_X,"car",_spawnLoc] spawn fnc_random_veh_blu_patrol;
						};
						// spawn armored
						if (WARCOM_blufor_ap>149) then {
							[BLUFOR_Faction_X,"armored",_spawnLoc] spawn fnc_random_veh_blu_patrol;
						};
						// spawn air	
						if (WARCOM_blufor_ap>199) then {
							[BLUFOR_Faction_X,"air",_spawnLoc] spawn fnc_random_veh_blu_patrol;
						};
					};
				};
				
				blufor_patrol_count = blufor_patrol_count + 1;
			};
			
			sleep floor (random [2700,3800,5400]);	// next patrol delay Rand 45-90 min
        };
};

