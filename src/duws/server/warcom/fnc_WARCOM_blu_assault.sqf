if (!isServer) exitWith {};
WARCOM_blu_attack_wave_type = "";
WARCOM_blu_attack_wave_avalaible = false;


// Type of attack wave
[] spawn {
// 使用本地化字符串（从stringtable.xml加载

		  
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
			[localize "STR_DUWS_T_OVERLORD", format[localize "STR_DUWS_T_7y9is2hm", _TFname]] remoteExec ["BIS_fnc_showSubtitle", 0];
            [] remoteExec ["fnc_broadcastRadioChatter", 0];
			[{hint localize "STR_DUWS_T_7y9is2hm2"}] remoteExec ["BIS_fnc_Spawn", 0];
			sleep 10; // give squads a chance to mount up
			// 让特遣队在基地附近待命（移动到基地附近但不攻击）
private _hqPos = WARCOM_blu_hq_pos;
// 清除所有现有路点
while {count (waypoints _group) > 0} do {
    deleteWaypoint ((waypoints _group) select 0);
};
// 添加一个移动到基地附近的路点
_wp = _group addWaypoint [_hqPos, 100];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "AWARE";
_wp setWaypointSpeed "NORMAL";
_wp setWaypointCompletionRadius 100;
// 添加一个循环路点（可选，让他们在基地附近停留）
_wp2 = _group addWaypoint [_hqPos, 50];
_wp2 setWaypointType "CYCLE";
_wp2 setWaypointBehaviour "AWARE";
_wp2 setWaypointSpeed "NORMAL";

// 记录该组到待命数组
private _standby = missionNamespace getVariable ["blu_taskforces_standby", []];
_standby pushBack _group;
missionNamespace setVariable ["blu_taskforces_standby", _standby, true];

// 仍然添加 GPS 标记（让玩家能看到他们）
[_group,_TFname] spawn fnc_WARCOM_gps_marker;

			sleep 5;
			{
				_x allowDamage true;
			} forEach (units _group);

			//sleep WARCOM_blu_attack_delay;   // 1800 sec
			sleep 1800;//floor (random [1800,2700,3600]);	// next assault delay Rand 30-60 min
          };
};
