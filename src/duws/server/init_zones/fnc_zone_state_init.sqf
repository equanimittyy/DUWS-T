// Zone control ownership and the WARCOM primary-zone pointer.
//
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
//
// English words with no stringtable key, like the squad callsigns: these are proper nouns a player
// says out loud, and a translated phonetic alphabet is a different alphabet, not a translation.
//
// The common English spellings rather than the official ICAO ones -- "Alpha", not "Alfa" -- so a
// zone reads the way the team callsign already does ("Alpha 1-1"). "Xray" stays unhyphenated
// because the pair separator below is a hyphen and "X-ray-Bravo" reads as three words.
//
// Past the twenty-six the pool pairs two distinct words. Selection is by draw-and-retry rather than
// by building the 650 pairs, because a campaign runs to tens of zones and would throw the list away.
fnc_zone_name = {
	private _words = ["Alpha","Bravo","Charlie","Delta","Echo","Foxtrot","Golf","Hotel","India",
		"Juliett","Kilo","Lima","Mike","November","Oscar","Papa","Quebec","Romeo","Sierra","Tango",
		"Uniform","Victor","Whiskey","Xray","Yankee","Zulu"];
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
		// Fifty draws without a new pair means the pair pool is effectively spent. Uniqueness is
		// what the rest of the mission keys on -- two zones answering to one name would make the
		// map readout and the capture report ambiguous -- so the count is appended rather than
		// risking a collision.
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

// What "this zone's garrison" is worth, wherever it happens to be standing. Deliberately not bounded
// by the zone radius: a patrol that has wandered out is still the zone's, and reinforcements that
// walk in are not, which is the whole reason the roster exists. Shared by the peak and the capture
// test so the strength a zone is measured against cannot be counted differently from the strength
// it is judged by.
fnc_zone_garrison_count = {
	params ["_zoneKey"];
	[_zoneKey] call fnc_site_alive
};

// CONTRACT: every path that removes a zone's garrison calls this, and nothing else clears a peak.
// A peak outliving the units it counted reads empty ground as a garrison beaten, so the zone falls
// to whoever walks in next -- silently, with nothing wrong in the SQF to find.
//
// The generation counter that used to ride along with it is gone. It existed because a band still
// placing from a torn-down cycle could republish a stale peak over the top of a new one; the raise
// flag on the zone's occupant closes that window instead, by refusing to start a second raise or a
// teardown until the first has reported.
fnc_zone_garrison_dropped = {
	params ["_zoneKey"];
	missionNamespace setVariable [format ["DUWS_zonePeak_%1", _zoneKey], nil];
};

// How much of its original garrison a zone still has, as a fraction. Read by everything that places
// OPFOR for a zone, so a force the player broke is not handed back to them intact two minutes later.
// Both of these name the zone's key to the shared attrition store, which owns the quantisation, the
// floor and the record -- a town wears down by the same rules and reads the same functions.
fnc_zone_strength = {
	params ["_zoneKey"];
	[_zoneKey] call DUWS_fnc_garrisonStrength
};

fnc_zone_strength_set = {
	params ["_zoneKey", "_frac"];
	[_zoneKey, _frac] call DUWS_fnc_garrisonStrengthSet
};

// Measured against the force the zone was first given -- DUWS_zoneBase_<key>, published beside the
// peak in fnc_zone_spawn -- rather than the possibly already reduced force it last deployed, so
// attrition accumulates across visits instead of each one starting from a fresh hundred per cent.
// Called on the streaming teardown, before the sweep deletes the survivors it is counting.
fnc_zone_strength_record = {
	params ["_zoneKey"];
	// The peak is published when the spawn band settles and cleared on teardown, so its presence is
	// the one signal that what is standing finished arriving. A band still placing when its own zone
	// packs up would otherwise be recorded as casualties nobody inflicted, and the zone would come
	// back permanently weaker for having been driven past. Callers must run this before
	// fnc_zone_garrison_dropped.
	if (isNil {missionNamespace getVariable (format ["DUWS_zonePeak_%1", _zoneKey])}) exitWith {};
	private _base = missionNamespace getVariable [format ["DUWS_zoneBase_%1", _zoneKey], 0];
	// No baseline means no cycle of this zone has ever finished placing, so there is nothing to
	// measure against and what is standing describes a garrison that was still arriving.
	if (_base <= 0) exitWith {};
	private _left = [_zoneKey] call fnc_zone_garrison_count;
	private _s = [_zoneKey, _left, _base] call DUWS_fnc_garrisonStrengthRecord;
	["INFO", "ZONES", format ["%1 packed up holding %2 of %3; redeploys at %4 strength",
		_zoneKey, _left, _base, _s]] call fnc_log;
};

// Brings every deployed zone's recorded strength up to what is standing right now. The record is
// otherwise written only on the streaming teardown, so a zone the player mauled and walked away from
// carried its old figure until the grace period expired -- and the map readout is read exactly in
// that window, while deciding where to go next. Called when a player opens the map readout, which is
// the only time the stored figure is read for anything but a redeploy.
//
// Falls but never rises, like the teardown record and for the same reason: a zone that healed itself
// because somebody looked at the map would refund the attrition it just took.
fnc_zone_strength_refresh = {
	if (!isServer) exitWith {};
	{
		_x params ["", "_pos"];
		private _key = [_pos] call fnc_zone_key;
		private _base = missionNamespace getVariable [format ["DUWS_zoneBase_%1", _key], 0];
		// No peak means stowed or still arriving. Stowed already reads what it last recorded, and a
		// garrison mid-placement would be recorded as casualties nobody inflicted.
		if (!isNil {missionNamespace getVariable (format ["DUWS_zonePeak_%1", _key])} && {_base > 0}) then {
			private _left = [_key] call fnc_zone_garrison_count;
			[_key, (_left / _base) min ([_key] call fnc_zone_strength)] call fnc_zone_strength_set;
		};
	} forEach zone_meta_array;
};

// A zone's inherent size, rolled once when it is generated and fixed for the campaign. Distinct from
// fnc_zone_strength, which is attrition: tier picks which composition the zone fields, strength says
// how much of it is left. Keeping them apart is what lets the map readout show a tier I zone at a
// full bar -- small, but not yet fought over.
//
// Tier selects a list rather than scaling one, so it reaches only the units a zone spawns alongside
// itself. The fortification garrison and the composition's gun crews scale by attrition alone.
//
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
//
// Skewed to the top: most zones are the full-strength objective the campaign has always fielded, and
// the lower tiers are the occasional soft one worth taking early. selectRandomWeighted rather than a
// hand-rolled cumulative sum, as fnc_createzone's prefab pick already uses.
fnc_zone_tier_roll = {
	params ["_zoneKey"];
	private _var = format ["DUWS_zoneTier_%1", _zoneKey];
	private _existing = missionNamespace getVariable [_var, 0];
	if (_existing > 0) exitWith { _existing };
	private _tier = selectRandomWeighted [1, 1, 2, 2, 3, 3, 4, 4];
	missionNamespace setVariable [_var, _tier];
	_tier
};

// Drops entries from a list at random until the fraction is met, keeping at least one. Random rather
// than off the tail: a caller's list is ordered by what it found, and a team's roster puts its
// leader first, so trimming the end would cost a weakened zone the same thing every time.
//
// This thins *things* -- the men inside a team. It is no longer what
// attrition does to a composition: a composition entry is not a unit, so dropping entries made two
// zones reported at the same strength differ by twenty men. DUWS_fnc_thinComposition is that.
fnc_zone_thin = {
	params ["_list", "_frac"];
	private _out = +_list;
	private _keep = (ceil (_frac * count _out)) max 1;
	while {count _out > _keep} do { _out deleteAt (floor random count _out) };
	_out
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
// globals at once -- both side lists and both counters -- and each used to be its own
// read-modify-write plus broadcast, so the four could be left inconsistent with each
// other as well as individually lost. Applying them together makes a transition atomic.
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
			// Position is the only stable zone id here: the capture path never receives the
			// generation index, and the prefab name it does carry is not unique.
			["INFO", "ZONES", format ["captured by BLUFOR at %1, now holding %2",
				_zonePos, zoneundercontrolblu]] call fnc_log;
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
};
