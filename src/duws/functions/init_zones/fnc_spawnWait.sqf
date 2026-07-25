// Locality: server -- inherited from init_zones/fnc_createzone.sqf.
// LOOP TO WAIT UNTIL BLUFOR CLOSE - SPAWN /DESPAWN 
// AFTER 10 min of BLUFOR CLOSE, NO DESPAWN

_spawnPos = _this select 0;
_size = _this select 1;
_index = _this select 2;

_blufor_close = false;
_noDespawn = false;

_AI_buffer = 400;
_player_buffer = 400;
_despawn_timer = 300;
_startTime = time;

while {true} do {
	
	if (!_blufor_close) then {

		while {true} do {
			_count_blu = 0;
			_westUnits = [];
			{
				if ((side _x) == WEST) then {
					_westUnits pushBack _x;
				};
			} forEach allUnits;

			// CHECK FOR 2x ANY UNIT
			{
				if ((_spawnPos distance _x) < (_size + _AI_buffer)) then {  // wait until BLUFOR are within 500m of perimeter
					_count_blu = _count_blu + 1;
					if (_count_blu > 1) then {
						_blufor_close = true;
					};  
				};
			} forEach _westUnits;
			
			// CHECK FOR 1x PLAYERS
			{
				if ((_spawnPos distance _x) < (_size + _player_buffer)) then {
					_blufor_close = true;
				};
			} foreach call BIS_fnc_ListPlayers;

			// Start the Spawns and start the timer
			if (_blufor_close) exitWith {
				(zone_spawn_array select _index) set [1,true];
				_startTime = time;
			};
			
			sleep 10;
		};
		
	} else {

		while {true} do {
			
			_blufor_close = false;  // until timer hits 10 min
			
			// Wait 10 min before DESPAWN
			if (time - _startTime < _despawn_timer || !(_spawnPos in WARCOM_zones_controled_by_OPFOR)) exitWith {
				_blufor_close = true;
			};

			// after 10 min check if BLUFOR still close
			_westUnits = [];
			{
				if ((side _x) == WEST) then {
					_westUnits pushBack _x;
				};
			} forEach allUnits;
			
			//CHECK FOR AI (500m)
			{
				if ((_spawnPos distance _x) < (_size + _AI_buffer)) then {  
					_blufor_close = true;
				};  
				if (_blufor_close == true) exitWith {};
			} forEach _westUnits;

			// CHECK FOR PLAYERS (1000m)
			{
				if ((_spawnPos distance _x) < (_size + _player_buffer)) then {
					_blufor_close = true;
				};
			} foreach call BIS_fnc_ListPlayers;

			sleep 10;
			
			// If blufor still close after 10 min, leave the zone as is, no despawn 
			if (_blufor_close == true) exitWith {
				_noDespawn = true;
				(zone_spawn_array select _index) set [2,true];
			};

			if (_blufor_close == false) exitWith {};

		};
		
		// CLEANUP ZONE
		if (_blufor_close == false) then {
			// ========== 清理前强制终止增援监控 ==========
			private _varSuffix = format ["zone_%1_%2", round(_spawnPos select 0), round(_spawnPos select 1)];
			private _triggeredVar = format ["opf_reinforce_%1", _varSuffix];
			missionNamespace setVariable [_triggeredVar, true, true];
			// =========================================
			
			(zone_spawn_array select _index) set [1,false];
			_zoneObj = _spawnPos nearObjects (_size + _AI_buffer);
			{
				// Delete vehicles and crew
				if (side _x == EAST && !(_x isKindOf "StaticWeapon") && !(_x isKindOf "Man")) then {
					deleteVehicleCrew _x;
					deleteVehicle _x;
				};
				// Delete units not in vehicles
				if (side _x == EAST && _x isKindOf "Man" && vehicle _x == _x) then {
					deleteVehicle _x;
				};
				
			} foreach _zoneObj;
		};
	};

	if (_noDespawn == true) then {
		waitUntil {sleep 60;(!(_spawnPos in WARCOM_zones_controled_by_OPFOR) || count WARCOM_zones_controled_by_OPFOR < 1)};
		if (count WARCOM_zones_controled_by_OPFOR < 1) exitWith {};
		waitUntil {sleep 60;(_spawnPos in WARCOM_zones_controled_by_OPFOR || count WARCOM_zones_controled_by_OPFOR < 1)};
		if (count WARCOM_zones_controled_by_OPFOR < 1) exitWith {};
		_opfor_spawn = false;
		_noDespawn = false;
		_blufor_close = false;
		(zone_spawn_array select _index) set [1,false];
		(zone_spawn_array select _index) set [2,false];
	};
	if (count WARCOM_zones_controled_by_OPFOR < 1) exitWith {};

};