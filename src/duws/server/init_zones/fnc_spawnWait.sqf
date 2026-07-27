// Locality: server -- inherited from server/init_zones/fnc_createzone.sqf.
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

// nearEntities, not a filter over allUnits: the engine's spatial index answers "who is near
// this zone" directly, so the cost tracks nearby units instead of every unit in the mission.
// One of these runs per zone every 10 s for the whole campaign, so the scan it replaces was
// O(zones x all units) forever.
// Vehicles are queried alongside men and their crew resolved, matching what the mission
// threads do -- a CAManBase-only query is not relied on to report units riding in something.
private _westMenNear = {
	params ["_pos", "_radius"];
	private _out = [];
	{
		if (_x isKindOf "CAManBase") then {
			if (side _x == WEST) then { _out pushBackUnique _x };
		} else {
			{ if (side _x == WEST) then { _out pushBackUnique _x } } forEach crew _x;
		};
	} forEach (_pos nearEntities [["CAManBase", "LandVehicle", "Air"], _radius]);
	_out
};

while {true} do {
	
	if (!_blufor_close) then {

		while {true} do {
			// CHECK FOR 2x ANY UNIT -- wait until BLUFOR are within the perimeter buffer
			if (count ([_spawnPos, _size + _AI_buffer] call _westMenNear) > 1) then {
				_blufor_close = true;
			};

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
			//CHECK FOR AI (500m)
			if (count ([_spawnPos, _size + _AI_buffer] call _westMenNear) > 0) then {
				_blufor_close = true;
			};

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