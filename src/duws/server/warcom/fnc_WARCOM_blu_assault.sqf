if (!isServer) exitWith {};

// How many task forces may sit at base waiting to be launched. They spawn on a timer and leave the
// standby list only when the player launches one (fnc_blu_taskforces_launch) or the group is wiped
// (fnc_WARCOM_gps_marker), and nothing else will ever collect them -- zone streaming deletes EAST
// only, and mission cleanup skips WEST. Uncapped, a task force the player ignores was permanently
// simulated AI parked inside view distance of the base, arriving at two groups an hour.
#define TASKFORCE_STANDBY_CAP 1

WARCOM_blu_attack_wave_type = "";
WARCOM_blu_attack_wave_avalaible = false;


// Type of attack wave
[] spawn {

		  
    waitUntil {sleep 30; WARCOM_blufor_ap>=10};
    WARCOM_blu_attack_wave_avalaible = true;
    WARCOM_blu_attack_wave_type = (blufor_RECON_TEAM_X select 0);

    waitUntil {sleep 30; WARCOM_blufor_ap>40};          
    WARCOM_blu_attack_wave_type = (blufor_INF_SQUAD_X select 0); 
          
	switch (VERSION_X) do {
	
		case "MODERN": {
			waitUntil {sleep 30; WARCOM_blufor_ap>65};          
			WARCOM_blu_attack_wave_type = (blufor_MOTOR_SECTION_X select 0); 

			waitUntil {sleep 30; WARCOM_blufor_ap>100};
			while {WARCOM_blufor_ap<136} do {
				WARCOM_blu_attack_wave_type = selectRandom [
					(blufor_MECH_SECTION_X select 0),
					(blufor_MECH_SECTION_X select 0),
					(blufor_MOTOR_SECTION_X select 0)
				];
				sleep 30;
			};
			while {true} do {
				sleep 30;          
				WARCOM_blu_attack_wave_type = selectRandom [
					(blufor_ARMOR_SECTION_X select 0),
					(blufor_ARMOR_SECTION_X select 0),
					(blufor_MECH_SECTION_X select 0),
					(blufor_MOTOR_SECTION_X select 0)
				];
			};
		};
	};
};

// Attack waves main
[] spawn {
		  // WAIT 5 min before launching first assault
          waitUntil {sleep 300; WARCOM_blu_attack_wave_avalaible};  
          while {true} do {

			// Held here rather than spawned and counted afterwards: the ceiling is on what stands
			// at base, so the next one is built when there is room for it. The patrol spawner gates
			// the same way on blufor_patrol_count.
			waitUntil {
				sleep 30;
				private _standby = missionNamespace getVariable ["blu_taskforces_standby", []];
				private _live = _standby select { !isNull _x };
				// Written back only when it actually shrank. This is a broadcast global, and
				// republishing an unchanged array every thirty seconds is traffic for nothing.
				// A wiped group is dropped by fnc_WARCOM_gps_marker, but deleteGroupWhenEmpty can
				// retire one before that loop next ticks, so the list is filtered rather than
				// trusted -- an entry left null would hold the ceiling closed for the campaign.
				if (count _live != count _standby) then {
					missionNamespace setVariable ["blu_taskforces_standby", _live, true];
				};
				count _live < TASKFORCE_STANDBY_CAP
			};

			// WAIT for Hardcore to find a zone
			if (hardcore_mode_enable) then {
				waitUntil {sleep 5;hardcore_visibleZone_found};
				["INFO", "WARCOM", format ["BLUFOR ASSAULT. WARCOM_blu_attack_wave_type: %1", WARCOM_blu_attack_wave_type]] call fnc_log;
				sleep 30;
			};
		  
		  
			// Find a safe position
			_pos = [[(WARCOM_blu_hq_pos select 0), (WARCOM_blu_hq_pos select 1)],200,300,15,0,0.3,0,[],[]] call BIS_fnc_findSafePos;
		  
			_group = "";
			_group = [_pos, WEST, WARCOM_blu_attack_wave_type,[],[],blufor_ai_skill] call BIS_fnc_spawnGroup;
			_groupLeader = leader _group;
			_veh = vehicle _groupLeader;
			_group addVehicle _veh;
			_group deleteGroupWhenEmpty true;
			sleep 30;

			{
				_x allowDamage false;
			} forEach (units _group);
			
			_TFname = [1] call fnc_random_name;
			waitUntil {sleep 0.1;!isNil "_TFname"};
			sleep 2;
			[localize "STR_DUWS_T_OVERLORD", format[localize "STR_DUWS_T_7y9is2hm", _TFname]] remoteExec ["fnc_duws_dialogue", 0];
			[{hint localize "STR_DUWS_T_7y9is2hm2"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];
			sleep 10; // give squads a chance to mount up
			// Park the task force on standby near base -- move up but hold, not assault.
private _hqPos = WARCOM_blu_hq_pos;
while {count (waypoints _group) > 0} do {
    deleteWaypoint ((waypoints _group) select 0);
};
_wp = _group addWaypoint [_hqPos, 100];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "AWARE";
_wp setWaypointSpeed "NORMAL";
_wp setWaypointCompletionRadius 100;
_wp2 = _group addWaypoint [_hqPos, 50];
_wp2 setWaypointType "CYCLE";
_wp2 setWaypointBehaviour "AWARE";
_wp2 setWaypointSpeed "NORMAL";

private _standby = missionNamespace getVariable ["blu_taskforces_standby", []];
_standby pushBack _group;
missionNamespace setVariable ["blu_taskforces_standby", _standby, true];

[_group,_TFname] spawn fnc_WARCOM_gps_marker;

			sleep 5;
			{
				_x allowDamage true;
			} forEach (units _group);

			//sleep WARCOM_blu_attack_delay;   // 1800 sec
			sleep 1800;//floor (random [1800,2700,3600]);	// next assault delay Rand 30-60 min
          };
};
