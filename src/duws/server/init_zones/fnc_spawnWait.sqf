// Locality: server -- inherited from server/init_zones/fnc_createzone.sqf.
// LOOP TO WAIT UNTIL BLUFOR CLOSE - SPAWN /DESPAWN
// Despawn is _despawn_timer seconds after BLUFOR were last seen, re-checked for as long as the
// zone is up. A zone is never pinned: leaving is what starts the clock, not how long you stayed.

_spawnPos = _this select 0;
_size = _this select 1;
_index = _this select 2;

_blufor_close = false;

_AI_buffer = 400;
// Twice the civilian handler's 60 s grace, and for the same reason: a zone left standing for five
// minutes after the last sighting leaves a trail of fully spawned garrisons behind anyone crossing
// the map. Zones are the more expensive of the two, so they get the shorter multiple, not a longer
// clock -- what buys the zone its extra minute is the composition rebuild a re-entry pays for.
_despawn_timer = 120;

// The key the prefab and the fortification ring both file their objects under
// (prefabs/modern/*.sqf:9, fnc_createzone.sqf:204), and the key every unit this zone spawns is
// stamped with. Derived from the same position array they use rather than passed in, and through
// the shared helper, so none of them can drift apart without the zone itself moving.
_zoneKey = [_spawnPos] call fnc_zone_key;

// One of these runs per zone every 10 s for the whole campaign, so the scan it replaces was
// O(zones x all units) forever. The test itself lives in fnc_duws_bluforNear, shared with the
// town garrison; the two buffers below are equal, so one radius covers both halves of it.
private _bluforNear = {
	params [["_minAI", 2]];
	[_spawnPos, _size + _AI_buffer, _minAI] call fnc_duws_bluforNear
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

// Crewing out has to happen here rather than in the loop below: that loop's man clause tests
// vehicle _x == _x, so a gunner sitting in a static keeps his seat, and stow refuses while any
// member is crewed. Shared by the opening stow and the despawn one so the two cannot drift.
private _stowZone = {
	params ["_key"];
	{
		if (_x isKindOf "StaticWeapon") then { deleteVehicleCrew _x };
	} forEach ((DUWS_compositions getOrDefault [_key, []]) select {!isNull _x});
	if ([_key] call fnc_duws_stow) then {
		["INFO", "STREAM", format ["stowed %1", _key]] call fnc_log;
	};
};

// Zones are built deployed, and the prefab mans their turrets at build time, so without this a
// fresh campaign carries every zone's props and gunners for the whole session -- the exact cost
// streaming exists to remove. The despawn branch below cannot do it: it is only reachable once a
// zone has been spawned, and a zone nobody has visited never has been.
// One AI is enough to keep it deployed here: this is the opening test, and stowing a zone
// somebody is already standing in would deploy it again on the next pass.
if !([1] call _bluforNear) then {
	[_zoneKey] call _stowZone;
};

while {true} do {
	
	if (!_blufor_close) then {

		while {true} do {
			_blufor_close = [2] call _bluforNear;

			// Confirmed after a pause rather than acted on the moment anyone clips the perimeter.
			// A helicopter transiting, or a patrol that turns back at the edge, would otherwise
			// spawn a garrison and rebuild a whole composition for someone already leaving --
			// and the pair is expensive enough that a false trigger is worth five seconds.
			if (_blufor_close) then {
				sleep 5;
				_blufor_close = [2] call _bluforNear;
			};

			// Start the Spawns
			if (_blufor_close) exitWith {
				// Props before the garrison: units must not spawn into ground that is about to
				// have a bunker on it, and the turrets have to exist before anyone mans them.
				if (_zoneKey in DUWS_stowed) then {
					[_zoneKey] call fnc_duws_deploy;
					["INFO", "STREAM", format ["deployed %1", _zoneKey]] call fnc_log;
				};
				[_spawnPos, _zoneKey] call _manStatics;
				(zone_spawn_array select _index) set [1,true];
			};
			
			sleep 10;
		};
		
	} else {

		// Presence is re-sampled for as long as the zone is up, and the grace period restarts every
		// time BLUFOR are seen. The shape this replaces tested once at the despawn_timer mark and
		// then pinned the zone permanently if anyone happened to be inside at that instant, so an
		// assault lasting longer than the timer left the zone -- garrison and every prop -- standing
		// for the rest of the campaign. One AI holds it here against two needed to raise it.
		private _lastSeen = time;
		private _despawn = false;
		while {true} do {
			if !(_spawnPos in WARCOM_zones_controled_by_OPFOR) exitWith {};
			if ([1] call _bluforNear) then { _lastSeen = time };
			if (time - _lastSeen >= _despawn_timer) exitWith { _despawn = true };
			sleep 10;
		};

		// Both exits, before the split below: the garrison is about to be deleted or the zone has
		// changed hands, and either ends what the capture test was judging. Ordering is the point --
		// a peak surviving into the sweep reads a pack-up as a garrison wiped. Do not inline.
		[_zoneKey] call fnc_zone_garrison_dropped;

		// CLEANUP ZONE
		if (_despawn) then {
			(zone_spawn_array select _index) set [1,false];
			_zoneObj = _spawnPos nearObjects (_size + _AI_buffer);
			// A withdrawal in progress is exempt: fnc_opfor_retreat owns those units until it has
			// taken them clear of anyone watching, and towns sit on enemy zones by design, so a
			// town garrison walking out crosses this radius on its way. Collecting it here would
			// delete it in front of the force that pushed it out, which is the one thing the
			// retreat exists to avoid. The give-up path in that function drops the flag, so
			// nothing it abandons stays exempt.
			{
				// Delete vehicles and crew
				if (side _x == EAST && !(_x isKindOf "StaticWeapon") && !(_x isKindOf "Man")
					&& !(_x getVariable ["DUWS_retreating", false])) then {
					deleteVehicleCrew _x;
					deleteVehicle _x;
				};
				// Delete units not in vehicles
				if (side _x == EAST && _x isKindOf "Man" && vehicle _x == _x
					&& !(_x getVariable ["DUWS_retreating", false])) then {
					deleteVehicle _x;
				};
				
			} foreach _zoneObj;

			[_zoneKey] call _stowZone;
		} else {
			// The zone changed hands, so the composition is not despawned -- the emplacements are
			// the player's now.
			//
			// Its surviving OPFOR are a different question. The capture trigger tests WEST SEIZED
			// over _size (fnc_createzone.sqf) while this thread streams over _size + _AI_buffer, so
			// the zone can flip with everything in that 400 m ring still alive: those units were
			// never inside the test. Left alone they stand in ground the player now owns for the
			// rest of the campaign, because this branch only idles and the sweep above is
			// unreachable once the zone is BLUFOR's. Deleting them is not an option either -- a
			// capture is watched by definition. So they withdraw.
			// This zone's own units, off its roster -- not every EAST man in the ring. A neighbouring
			// town's garrison, or a WARCOM wave that came to relieve the zone, is not this zone's to
			// order off the map. Read before the peak's cycle ends, so the roster still describes
			// the garrison that was holding when the zone fell.
			private _grps = [];
			{
				if (alive _x) then { _grps pushBackUnique (group _x) };
			} forEach ([_zoneKey] call fnc_zone_roster);
			if (count _grps > 0) then {
				["INFO", "STREAM", format ["%1 lost; %2 surviving group(s) ordered out", _zoneKey, count _grps]] call fnc_log;
				[_grps, _spawnPos] spawn fnc_opfor_retreat;
			};

			// This thread idles until OPFOR hold it again rather than re-entering the arrival
			// branch, which would spawn an OPFOR garrison inside a zone BLUFOR own.
			waitUntil {sleep 60; (_spawnPos in WARCOM_zones_controled_by_OPFOR)
				|| {count WARCOM_zones_controled_by_OPFOR < 1}};
			(zone_spawn_array select _index) set [1,false];
		};

		_blufor_close = false;
	};
	if (count WARCOM_zones_controled_by_OPFOR < 1) exitWith {};

};