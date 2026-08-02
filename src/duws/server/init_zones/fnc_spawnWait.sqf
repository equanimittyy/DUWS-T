// Locality: server -- inherited from server/init_zones/fnc_createzone.sqf.
// LOOP TO WAIT UNTIL BLUFOR CLOSE - SPAWN /DESPAWN
// Despawn is _despawn_timer seconds after BLUFOR were last seen, re-checked for as long as the
// zone is up. A zone is never pinned: leaving is what starts the clock, not how long you stayed.

_spawnPos = _this select 0;
_size = _this select 1;
_index = _this select 2;

_blufor_close = false;

// Held until this zone has been seen empty of BLUFOR once. The arrival test fires on anyone inside
// the radius plus the buffer and cannot tell somebody walking up from somebody already standing in
// the middle, so a thread that starts under a player's feet would raise the garrison around them.
// Only the opening case needs it: a despawn happens only once they have left, and a retake cannot
// fire while they are inside, so every later cycle already begins from empty ground.
// Starts latched rather than sampling presence here -- the poll below runs within ten seconds and
// clears it for the ordinary zone nobody is near, which is all of them at campaign start.
private _awaitVacate = true;

_AI_buffer = 400;
// Twice the civilian handler's 60 s grace, and for the same reason: a zone left standing for five
// minutes after the last sighting leaves a trail of fully spawned garrisons behind anyone crossing
// the map. Zones are the more expensive of the two, so they get the shorter multiple, not a longer
// clock -- what buys the zone its extra minute is the composition rebuild a re-entry pays for.
_despawn_timer = 120;

// The key the prefab files its objects under (prefabs/modern/*.sqf:9), and the key every unit this
// zone spawns is stamped with. Derived from the same position array they use rather than passed in,
// and through the shared helper, so the two cannot drift apart without the zone itself moving.
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
	private _roster = [_key] call fnc_zone_roster;
	private _statics = (DUWS_compositions getOrDefault [_key, []]) select {
		!isNull _x && {alive _x} && {_x isKindOf "StaticWeapon"}
	};

	// A gun still carrying the crew the prefab gave it. That gunner is the zone's garrison as much
	// as a spawned one, so he joins the roster rather than holding the objective off the books:
	// unrostered, he denies capture through fnc_opfor_count_at while counting toward neither the
	// peak nor the break line, so killing him is progress the zone never registers.
	{
		{ _x setVariable ["DUWS_garrisonUnit", true] } forEach crew _x;
		_roster append (crew _x);
	} forEach (_statics select {count crew _x > 0});

	private _guns = _statics select {count crew _x == 0};
	if (count _guns == 0) exitWith {};
	// Manned to the garrison's strength: a weakened zone gets fewer emplacements manned, not weaker
	// ones. Attrition only, not tier -- these crew the prefab's own guns, and tier picks what the
	// zone spawns alongside itself rather than who stands on its fortifications.
	_guns = [_guns, [_key] call fnc_zone_strength] call fnc_zone_thin;
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
	// Flagged like everything DUWS_fnc_raiseGarrison raises: these are the zone's garrison too, and
	// a blunt radius sweep has no other way to know it.
	{ _x setVariable ["DUWS_garrisonUnit", true] } forEach units _grp;
	_roster append (units _grp);
	// Searchable on the same terms as the rest of the garrison. A gunner is the one defender a
	// player is certain to have to kill, so leaving him unflagged made the objective itself the
	// least rewarding thing in the zone.
	[_grp, "garrison"] call fnc_search_flag_group;
	[_grp, _pos] call bis_fnc_taskDefend;
};

// How far a fallen zone's survivors are sent. Past the streaming ring, so a group that actually
// walks it ends up outside the radius the player who just took the zone is likely to still be in.
#define WITHDRAW_DISTANCE 800

// No player within this of a survivor before it is collected. Wider than the litter sweep's 300 m
// because these are live men: a body blinking out at 300 m goes unnoticed and a soldier doing it
// does not.
#define WITHDRAW_KEEP_RADIUS 500

// Survivors of a zone that has fallen: ordered off the objective here, collected by the sweep below
// once nobody can see them go. The order is what makes the collection quiet rather than what
// performs it -- a group that cannot path is still collected on distance, so nothing is left
// standing whether or not the walk works.
//
// Roster-scoped, so only this zone's own garrison goes: a neighbouring town's or a side mission's
// guards are not this zone's to take. Returns the men, for the sweep to work through.
//
// Locality: addWaypoint and setBehaviour are ignored unless the group is local to the machine
// issuing them (docs/info/arma_engine_gotchas.md); every group on a zone roster is server-spawned.
private _sendOff = {
	params ["_key", "_pos"];
	private _men = ([_key] call fnc_zone_roster) select { alive _x };
	private _grps = [];
	{ _grps pushBackUnique (group _x) } forEach _men;
	{
		private _grp = _x;
		// The defend and patrol waypoints the spawners gave them would pull them straight back onto
		// the objective. Back to front: deleteWaypoint shifts every later index down, so a forward
		// pass deletes every other one.
		private _wps = waypoints _grp;
		reverse _wps;
		{ deleteWaypoint _x } forEach _wps;
		// Outward on the bearing they already stand on, so a group on the far side of the zone does
		// not cross it to leave.
		private _dest = _pos getPos [WITHDRAW_DISTANCE, _pos getDir (leader _grp)];
		private _wp = _grp addWaypoint [_dest, 50];
		_wp setWaypointType "MOVE";
		_wp setWaypointSpeed "FULL";
		_grp setBehaviour "AWARE";
		_grp setSpeedMode "FULL";
		// Saves the sweep having to tidy up behind itself: the engine drops the group on the last
		// man, whether he was collected or shot.
		_grp deleteGroupWhenEmpty true;
	} forEach _grps;
	_men
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

			// One empty sighting spends the latch. Tested on the same call the arrival uses, so
			// "here" means one thing: a zone cannot clear the latch and spawn on the same pass.
			if (_awaitVacate) then {
				if (!_blufor_close) then { _awaitVacate = false };
				_blufor_close = false;
			};

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
				// The spawn cycle opens here rather than where the band is raised, because the
				// turret crews below are garrison too and a roster cleared after them would drop
				// them. Clear and bump stay one act, and fnc_createzone reads the generation this
				// publishes instead of bumping its own.
				[_zoneKey] call fnc_zone_gen_bump;
				[_zoneKey] call fnc_site_roster_clear;
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

		// What the player left of the garrison, off the roster and above the line below: the record
		// reads the peak to tell a garrison that finished arriving from one still being placed, and
		// the next statement clears it. The sweep further down is what deletes the men it counts.
		if (_despawn) then { [_zoneKey] call fnc_zone_strength_record };

		// Both exits, before the split below: the garrison is about to be deleted or the zone has
		// changed hands, and either ends what the capture test was judging. Ordering is the point --
		// a peak surviving into the sweep reads a pack-up as a garrison wiped. Do not inline.
		[_zoneKey] call fnc_zone_garrison_dropped;

		// CLEANUP ZONE
		if (_despawn) then {
			(zone_spawn_array select _index) set [1,false];
			// By roster, not by proximity. This swept every EAST man inside _size + _AI_buffer
			// whoever raised them, and town discs overlap zone circles by design -- so a zone
			// streaming out took the neighbouring town's garrison with it. The town then measured
			// its survivors against its baseline, recorded a mauling that never happened, and came
			// back thinned for the rest of the campaign. Nothing standing in the ring that is not on
			// this roster is this zone's to delete; whoever raised it streams it out themselves.
			private _men = ([_zoneKey] call fnc_zone_roster) select { !isNull _x };
			private _vehs = [];
			{ if (vehicle _x != _x) then { _vehs pushBackUnique (vehicle _x) } } forEach _men;
			{ deleteVehicle _x } forEach _men;
			// After the men, and only if nothing else is aboard: a transport the zone crewed goes
			// with its crew, while one the player left in the ring is not on this roster and stays.
			{ if (({alive _x} count crew _x) == 0) then { deleteVehicle _x } } forEach _vehs;

			[_zoneKey] call _stowZone;
		} else {
			// The zone changed hands, so the composition is not despawned -- the emplacements are
			// the player's now.
			//
			// Its surviving OPFOR are a different question. The capture trigger tests over _size
			// (fnc_createzone.sqf) while this thread streams over _size + _AI_buffer, so the zone
			// can flip with everything in that 400 m ring still alive: those units were never
			// inside the test. Left alone they stand in ground the player now owns for the rest of
			// the campaign, because this branch only idles and the sweep above is unreachable once
			// the zone is BLUFOR's. Bounded rather than open-ended: fnc_zone_capture_ready refuses
			// while more than its break fraction of the peak is alive on the roster anywhere, so
			// this is a fifth of a garrison at worst.
			private _leftovers = [_zoneKey, _spawnPos] call _sendOff;
			if (count _leftovers > 0) then {
				["INFO", "STREAM", format ["%1 lost; %2 surviving garrison man/men ordered off",
					_zoneKey, count _leftovers]] call fnc_log;
			};

			// The attrition this zone carried is left as it stands. It used to be reset to full
			// here, on the reasoning that a retaken zone is manned by a fresh force -- which handed
			// the player's grinding straight back the moment they lost the ground again. What OPFOR
			// put on a zone they had to retake is a scratch force instead, and fnc_opfor_cap floors
			// the figure when the flip actually happens rather than guessing here that it will.

			// This thread idles until OPFOR hold it again rather than re-entering the arrival
			// branch, which would spawn an OPFOR garrison inside a zone BLUFOR own. The withdrawal
			// ordered above is collected on the same clock, on the rule the litter sweep collects
			// everything else by: a survivor goes once no player is within WITHDRAW_KEEP_RADIUS of
			// him, retried every pass rather than timed out, so one somebody is standing over is
			// collected when they leave rather than never. Nothing else would ever collect them --
			// fnc_repetitive_cleanup takes bodies, wrecks and empty vehicles, never living men.
			//
			// BIS_fnc_ListPlayers, not allPlayers: this is the streaming system's own answer to
			// "is a player here" (fnc_duws_bluforNear), and the whole sweep turns on it. A list
			// that came back empty where it should not -- a hosted session, a singleplayer
			// campaign -- would delete every survivor on the first pass, which is precisely the
			// vanishing act the walk-off exists to avoid.
			private _held = true;
			while {_held} do {
				// The 60 s this always idled at once there is nothing left to collect, so a zone
				// held for hours costs what it did before; 20 s while there is, because the
				// collection has to catch the moment the player moves off.
				sleep ([60, 20] select (count _leftovers > 0));
				private _players = call BIS_fnc_ListPlayers;
				{
					private _man = _x;
					if ((_players findIf {_x distance _man < WITHDRAW_KEEP_RADIUS}) < 0) then {
						deleteVehicle _man;
					};
				} forEach _leftovers;
				_leftovers = _leftovers select { alive _x };
				_held = !(_spawnPos in WARCOM_zones_controled_by_OPFOR)
					&& {count WARCOM_zones_controled_by_OPFOR > 0};
			};
			// Whatever is still walking goes with BLUFOR's tenure. A retake means they left the
			// zone, so there is nobody to watch it happen, and the garrison that arrives files a
			// roster of its own these men would not be on -- left alive, nothing would collect them.
			{ deleteVehicle _x } forEach _leftovers;
			(zone_spawn_array select _index) set [1,false];
			// Re-latched, because a retake is not the clean start it looks like. EAST SEIZED only
			// promises BLUFOR are outside the *trigger* radius; the arrival test below reaches 400 m
			// further, so a player who has backed off the objective but is still on the approach is
			// near by its reckoning and would have the new garrison raised in front of them. The
			// same is true of anyone who walks back in during the ten seconds before the next poll.
			// Held until the whole ring is empty once, exactly as at campaign start.
			_awaitVacate = true;
		};

		_blufor_close = false;
	};
	if (count WARCOM_zones_controled_by_OPFOR < 1) exitWith {};

};