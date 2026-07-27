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

// The key the prefab and the fortification ring both file their objects under
// (prefabs/modern/*.sqf:9, fnc_createzone.sqf:204). Derived from the same position array they
// use rather than passed in, so the three cannot drift apart without the zone itself moving.
_zoneKey = format ["zone_%1_%2", round (_spawnPos select 0), round (_spawnPos select 1)];

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

// Zone turrets get their gunners from the prefab at build time, and the prefab never runs again --
// so a composition that has been stowed comes back with empty guns unless they are re-crewed here.
// Skipped once the zone is BLUFOR's: the emplacements are then the player's to use, which is the
// same reason zone compositions are persistent rather than released on capture.
private _manStatics = {
	params ["_pos", "_key"];
	if !(_pos in WARCOM_zones_controled_by_OPFOR) exitWith {};
	private _guns = (DUWS_compositions getOrDefault [_key, []]) select {
		!isNull _x && {alive _x} && {_x isKindOf "StaticWeapon"} && {count crew _x == 0}
	};
	if (count _guns == 0) exitWith {};
	private _types = _guns apply {opfor_SOLDIER_X};
	private _spawn = _pos findEmptyPosition [0, 30, opfor_SOLDIER_X];
	if (count _spawn == 0) then { _spawn = _pos };
	private _grp = [_spawn, EAST, _types, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
	_grp deleteGroupWhenEmpty true;
	// Indexed off the spawned group rather than assumed one-to-one: a group that came back short
	// would otherwise throw here every despawn cycle for the rest of the campaign.
	{
		private _unit = (units _grp) param [_forEachIndex, objNull];
		if (!isNull _unit) then { _unit moveInGunner _x };
	} forEach _guns;
	[_grp, _pos] call bis_fnc_taskDefend;
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
				// Props before the garrison: units must not spawn into ground that is about to
				// have a bunker on it, and the turrets have to exist before anyone mans them.
				if (_zoneKey in DUWS_stowed) then {
					[_zoneKey] call fnc_duws_deploy;
					["INFO", "STREAM", format ["deployed %1", _zoneKey]] call fnc_log;
				};
				[_spawnPos, _zoneKey] call _manStatics;
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
			private _triggeredVar = format ["opf_reinforce_%1", _zoneKey];
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

			// The loop above cannot reach a turret gunner: its man clause tests vehicle _x == _x,
			// so a crewed static keeps its crew. Stow refuses while any member is crewed, so
			// without this pass the zone's props would never leave the map. Players are not
			// deleted by deleteVehicleCrew, so one sitting in a captured gun holds the zone
			// deployed until they get out, which is the direction that failure should go.
			{
				if (_x isKindOf "StaticWeapon") then { deleteVehicleCrew _x };
			} forEach ((DUWS_compositions getOrDefault [_zoneKey, []]) select {!isNull _x});

			if ([_zoneKey] call fnc_duws_stow) then {
				["INFO", "STREAM", format ["stowed %1", _zoneKey]] call fnc_log;
			};
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