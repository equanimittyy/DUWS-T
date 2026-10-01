// Zone control ownership and the WARCOM primary-zone pointer.
// Executed by the registry rather than stored as one function: this file defines several.
// Broadcasts stay in server_fnc_init.sqf beside the load, so the manifest remains the one
// place to see what reaches clients.

// The one derivation of a zone's key. The composition system, the streaming thread, the garrison
// peak and the capture test all file under it, so it cannot be spelled out per caller without the
// four drifting the moment one is retuned.
fnc_zone_key = {
	params ["_pos"];
	format ["zone_%1_%2", round (_pos select 0), round (_pos select 1)]
};

// One zone identity, handed out once and never reused. Zones were numbered, which meant every line
// of dialogue naming one read as a spreadsheet row and two adjacent zones sounded like the same
// place; a spoken callsign is what the player ends up using for the ground itself.
// English words with no stringtable key, like the squad callsigns: these are proper nouns a player
// says out loud, and a translated phonetic alphabet is a different alphabet, not a translation.
// The common English spellings rather than the official ICAO ones -- "Alpha", not "Alfa" -- so a
// zone reads the way the team callsign already does ("Alpha 1-1"). "Xray" stays unhyphenated
// because the pair separator below is a hyphen and "X-ray-Bravo" reads as three words.
// Past the twenty-six the pool pairs two distinct words. Selection is by draw-and-retry rather than
// by building the 650 pairs, because a campaign runs to tens of zones and would throw the list away.
fnc_zone_name = {
	private _words = ["ALPHA","BRAVO","CHARLIE","DELTA","ECHO","FOXTROT","GOLF","HOTEL","INDIA",
		"JULIETT","KILO","LIMA","MIKE","NOVEMBER","OSCAR","PAPA","QUEBEC","ROMEO","SIERRA","TANGO",
		"UNIFORM","VICTOR","WHISKEY","XRAY","YANKEE","ZULU"];
	private _used = missionNamespace getVariable ["DUWS_zoneNames", []];
	private _free = _words select {!(_x in _used)};

	private _name = "";
	if (count _free > 0) then {
		_name = selectRandom _free;
	} else {
		for "_i" from 1 to 50 do {
			private _first = selectRandom _words;
			private _try = format ["%1-%2", _first, selectRandom (_words - [_first])];
			if !(_try in _used) exitWith { _name = _try };
		};
		// Fifty draws without a new pair means the pair pool is effectively spent. Uniqueness is what
		// the rest of the mission keys on -- two zones answering to one name would make the map
		// readout and the capture report ambiguous -- so the count is appended rather than risking a collision.
		if (_name == "") then { _name = format ["%1-%2", selectRandom _words, count _used] };
	};

	_used pushBack _name;
	missionNamespace setVariable ["DUWS_zoneNames", _used];
	_name
};

// A zone's garrison roster, which is the shared site store keyed by the zone. Emptied at the head of
// each spawn cycle, so it describes the garrison currently on the ground rather than every garrison
// the zone has ever had. Why a roster rather than a flag on each unit is stated where it is kept.
fnc_zone_roster = {
	params ["_zoneKey"];
	[_zoneKey] call fnc_site_roster
};

// CONTRACT: every path that removes a zone's garrison calls this, and nothing else clears the live flag.
// A garrison left marked live over empty ground reads as a garrison beaten, so the zone falls to whoever
// walks in next -- silently, with nothing wrong in the SQF to find. The full-potential denominator and
// the loss ledger outlive the teardown on purpose (a stowed zone still reports its mauled strength and
// comes back at it); only the liveness is cleared here.
fnc_zone_garrison_dropped = {
	params ["_zoneKey"];
	[_zoneKey, false] call DUWS_fnc_garrisonSetLive;
};

// How much of its garrison a zone still has, as a fraction. Read by the map readout and by anything
// deciding what to place. Names the zone's key to the shared attrition ledger, which a town reads the
// same way -- a live projection of surviving tokens over full potential, so there is nothing to record
// or refresh: it is always current, and it rises only by a bought reinforcement. A wiped group records
// its own loss; recapture reseeds it through DUWS_fnc_garrisonSeedOpforCap.
fnc_zone_strength = {
	params ["_zoneKey"];
	[_zoneKey] call DUWS_fnc_garrisonStrength
};

// A zone's inherent size, rolled once when it is generated; only a bought fortification raises it. It is
// the holder's tier, not OPFOR's: a flip in either direction drops it to 0, and what the new holder does
// then is the one place the two sides differ -- an OPFOR retake resets it to I, where BLUFOR must buy
// their way up from nothing.
// Distinct from fnc_zone_strength, which is attrition: tier picks which composition the zone fields,
// strength says how much of it is left. Keeping them apart is what lets the map readout show a tier I zone at a full bar --
// small, but not yet fought over.
// Tier selects a list rather than scaling one, so it reaches only the units a zone spawns alongside
// itself. The fortification garrison and the composition's gun crews scale by attrition alone.
// Defaults to IV so a zone that never rolled one -- a save written before tiers existed, or any path
// that reaches the spawn without passing through the roll -- fields what it always did rather than
// silently coming back at half strength.
fnc_zone_tier = {
	params ["_zoneKey"];
	missionNamespace getVariable [format ["DUWS_zoneTier_%1", _zoneKey], 4]
};

// Rolled once per zone and never re-rolled. fnc_createzone is re-entrant by design -- zone_meta_array
// exists so a zone can be rebuilt through it -- and a rebuild that re-rolled would change what the
// ground is worth behind the player's back, and disagree with the garrison peak already measured
// against the old tier.
// Skewed to the top: most zones are the full-strength objective the campaign has always fielded, and
// the lower tiers are the occasional soft one worth taking early. selectRandomWeighted rather than a
// hand-rolled cumulative sum, as fnc_createzone's prefab pick already uses.
fnc_zone_tier_roll = {
	params ["_zoneKey"];
	private _var = format ["DUWS_zoneTier_%1", _zoneKey];
	// Tested for absence, not for a positive tier: 0 is a stored tier, BLUFOR ground, and must not re-roll.
	if !(isNil { missionNamespace getVariable _var }) exitWith { missionNamespace getVariable _var };
	private _tier = selectRandomWeighted [1, 1, 2, 2, 3, 3, 4, 4];
	missionNamespace setVariable [_var, _tier];
	_tier
};

// Whether BLUFOR hold a zone. Tested by key, since a held position may have round-tripped through a string.
fnc_zone_bluforHeld = {
	params ["_zoneKey"];
	(WARCOM_zones_controled_by_BLUFOR findIf { ([_x] call fnc_zone_key) isEqualTo _zoneKey }) >= 0
};

// Whoever holds the ground may buy. Neither side pays here -- the price is the caller's, and each side's
// candidate list is what keeps a commander off the other's ground.
// -> the new strength, or -1 if refused. Tier 0 has no garrison to put men back into.
fnc_zone_garrison_reinforce = {
	params ["_zoneKey", ["_reason", ""]];
	private _tier = [_zoneKey] call fnc_zone_tier;
	if (_tier < 1) exitWith {
		["INFO", "ZONES", format ["%1 reinforcement refused (%2): no garrison", _zoneKey, _reason]] call fnc_log;
		-1
	};
	private _old = [_zoneKey] call DUWS_fnc_garrisonStrength;
	[_zoneKey, [_tier, [_zoneKey] call DUWS_fnc_garrisonSideOf] call DUWS_fnc_zoneSpawnList] call DUWS_fnc_garrisonReinforce;
	private _new = [_zoneKey] call DUWS_fnc_garrisonStrength;
	["INFO", "ZONES", format ["%1 reinforced %2 -> %3 (%4)", _zoneKey, _old, _new, _reason]] call fnc_log;
	_new
};

// -> the tier it now stands at, or -1 if refused. Raising from 0 is the whole of how a BLUFOR garrison comes
// to exist; the capture forgot the ledger, so that first tier is bought clean.
fnc_zone_garrison_fortify = {
	params ["_zoneKey", ["_reason", ""]];
	private _old = [_zoneKey] call fnc_zone_tier;
	private _new = (_old + 1) min (count DUWS_zoneSpawnTiers);
	if (_new == _old) exitWith { _old };
	private _side = [_zoneKey] call DUWS_fnc_garrisonSideOf;
	missionNamespace setVariable [format ["DUWS_zoneTier_%1", _zoneKey], _new];
	private _x1 = [_new, _side] call DUWS_fnc_zoneSpawnList;
	[_zoneKey, [_old, _side] call DUWS_fnc_zoneSpawnList, _x1] call DUWS_fnc_garrisonBuyTier;
	// No thread adopts a zone's tier, so the buy re-stands it here.
	if ([_zoneKey] call DUWS_fnc_garrisonHeld) then { [_zoneKey, _x1] call DUWS_fnc_garrisonRestand };
	[_zoneKey, _old, _new] call DUWS_fnc_zoneBuildGrant;
	["INFO", "ZONES", format ["%1 tier %2 -> %3 (%4)", _zoneKey, _old, _new, _reason]] call fnc_log;
	_new
};

// The enemy multiplier is reserve depth, not a live-force multiplier: a zone always stands up its x1
// tier garrison and holds the surplus (mult-1) copies as a pool that refills the garrison to its x1
// group count as casualties are taken. These are the accounting the capture test, the attrition record
// and the refill pass all read; the pass, the placement and the hunt orders are fnc_zone_reserve's.
// The model is docs/info/gameplay/garrison_and_reserves.md.

// The pool is per-awake-session state: seeded by fnc_zone_spawn, spent by the refill pass, cleared on
// stow and reseeded on the next raise. An ordered token list, popped head-first; empty at multiplier 1
// where the whole model is inert and every measure below collapses to the garrison alone.
DUWS_fnc_garrisonReserve = {
	params ["_key"];
	missionNamespace getVariable [format ["DUWS_zoneReserve_%1", _key], []]
};

DUWS_fnc_garrisonReserveSet = {
	params ["_key", "_pool"];
	missionNamespace setVariable [format ["DUWS_zoneReserve_%1", _key], _pool];
};

// Everything the awake session put down that the next raise rebuilds from scratch: the pool, the group
// ceiling the refill tops up to, the OPCOM tokens accounted to both, and the event debounce stamp. Baseline and strength are left alone --
// those outlive a stow, which is how attrition accumulates across visits.
DUWS_fnc_garrisonReserveClear = {
	params ["_key"];
	missionNamespace setVariable [format ["DUWS_zoneReserve_%1", _key], []];
	missionNamespace setVariable [format ["DUWS_zoneCeiling_%1", _key], nil];
	missionNamespace setVariable [format ["DUWS_zoneReserveOpcom_%1", _key], nil];
	missionNamespace setVariable [format ["DUWS_zoneReserveEventAt_%1", _key], nil];
};

// The zone's live *composition* group count: distinct groups, with a man still standing, that the
// streaming garrison raised -- the initial band and its reserves. Compared to the x1 ceiling to decide
// refills, so the two must count the same population, and the ceiling is composition tokens only. A
// prefab's static-weapon crews sit on the same roster but are emplacement occupants, not composition
// groups: they carry no reserve key (DUWS_fnc_garrisonReserveWatch tags only what it raises), so they are
// excluded here, and a zone with manned guns does not read as already at its ceiling.
DUWS_fnc_garrisonGroupCount = {
	params ["_key"];
	private _grps = [];
	{
		if (alive _x && {(_x getVariable ["DUWS_garrisonKey", ""]) == _key}) then {
			_grps pushBackUnique (group _x);
		};
	} forEach ([_key] call fnc_zone_roster);
	count _grps
};

// Every group one side holds anywhere -- the global throttle input. Against the 144-per-side cap, not a
// zone's own count: hardpoints raise their own groups on their own rules and are not
// pooled or per-zone bounded, but they do count here, so a dense field pushes zones to back off and
// leave the engine headroom. The cap is per side, so BLUFOR's count carries the player's own squads.
DUWS_fnc_sideGroupCount = {
	params [["_side", "OPF"]];
	private _army = [east, west] select (_side isEqualTo "BLU");
	count (allGroups select { side _x == _army })
};

// Server-authoritative reorder of the OPFOR assault queue. The map-click picker runs
// on the clicking player's machine, so mutating this shared list there and
// broadcasting the absolute array would drop a concurrent capture's edit to it.
// Matches by position value: the caller passes an entry it read from this same list,
// so a stale pick simply finds nothing rather than resurrecting a captured zone.
fnc_warcom_set_primary_zone = {
	if (!isServer) exitWith {};
	params [["_zonePos", []]];
	private _i = WARCOM_zones_controled_by_OPFOR findIf {_x isEqualTo _zonePos};
	if (_i < 0) exitWith {};
	WARCOM_zones_controled_by_OPFOR deleteAt _i;
	WARCOM_zones_controled_by_OPFOR = [WARCOM_zones_controled_by_OPFOR,[WARCOM_blu_hq_pos],{_input0 distance _x},"ASCEND"] call BIS_fnc_sortBy;
	WARCOM_zones_controled_by_OPFOR insert [0, [_zonePos]];
	publicVariable "WARCOM_zones_controled_by_OPFOR";
};

// Server-authoritative zone-control transition. A capture or loss moves four networked
// globals at once -- both side lists and both counters. Done as four separate read-modify-write-plus-
// broadcasts, they could be left inconsistent with each other as well as individually lost; applying
// them together makes a transition atomic.
// Position matching is on the x/y components rather than isEqualTo: a stored zone
// position and the trigger position that reports it can differ in z.
// No floor on the counters on purpose -- they are accounting, and a negative would mean
// a zone was processed twice, which should stay visible rather than be clamped away.
fnc_zone_control_set = {
	if (!isServer) exitWith {};
	params [["_side", ""], ["_zonePos", []]];
	if (_zonePos isEqualTo []) exitWith {};
	private _fnc_dropFrom = {
		params ["_list", "_pos"];
		private _i = _list findIf {
			((_x select 0) == (_pos select 0)) && ((_x select 1) == (_pos select 1))
		};
		if (_i >= 0) then { _list deleteAt _i };
	};
	switch (_side) do {
		case "BLU": {
			WARCOM_zones_controled_by_BLUFOR pushBack _zonePos;
			[WARCOM_zones_controled_by_OPFOR, _zonePos] call _fnc_dropFrom;
			amount_zones_captured = amount_zones_captured + 1;
			zoneundercontrolblu = zoneundercontrolblu + 1;
			// Tier and ledger go together, or the player's first bought tier would come back already
			// mauled by the fight they just won -- and BLUFOR inherit nothing.
			missionNamespace setVariable [format ["DUWS_zoneTier_%1", [_zonePos] call fnc_zone_key], 0];
			[[_zonePos] call fnc_zone_key] call DUWS_fnc_garrisonForget;
			// Position is the only stable zone id here: the capture path never receives the
			// generation index, and the prefab name it does carry is not unique.
			["INFO", "ZONES", format ["captured by BLUFOR at %1, now holding %2",
				_zonePos, zoneundercontrolblu]] call fnc_log;
			// Guarded: this transition is the critical path and OPCOM lives in a separate subsystem
			// (docs/plans/opcom/opcom_plan.md).
			if (!isNil "DUWS_fnc_opcom_siteLost") then { [[_zonePos] call fnc_zone_key] call DUWS_fnc_opcom_siteLost };
		};
		case "OPF": {
			[WARCOM_zones_controled_by_BLUFOR, _zonePos] call _fnc_dropFrom;
			// Sort by distance to HQ, then force the just-lost zone to the front: WARCOM
			// reads index 0 as the primary assault target.
			WARCOM_zones_controled_by_OPFOR = [WARCOM_zones_controled_by_OPFOR,[WARCOM_blu_hq_pos],{_input0 distance _x},"ASCEND"] call BIS_fnc_sortBy;
			WARCOM_zones_controled_by_OPFOR insert [0, [_zonePos]];
			amount_zones_captured = amount_zones_captured - 1;
			zoneundercontrolblu = zoneundercontrolblu - 1;
			["INFO", "ZONES", format ["lost to OPFOR at %1, now holding %2, primary assault target",
				_zonePos, zoneundercontrolblu]] call fnc_log;
		};
		default { ["ERROR", "ZONES", format ["fnc_zone_control_set: unrecognised side '%1'", _side]] call fnc_log; };
	};
	publicVariable "WARCOM_zones_controled_by_BLUFOR";
	publicVariable "WARCOM_zones_controled_by_OPFOR";
	publicVariable "amount_zones_captured";
	publicVariable "zoneundercontrolblu";
	[[_zonePos] call fnc_zone_key] call DUWS_fnc_opcom_gridDirty;
};
