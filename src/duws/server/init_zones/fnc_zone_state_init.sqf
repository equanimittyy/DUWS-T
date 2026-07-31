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

// Every unit a zone spawned, in one array per zone. Both spawn threads append to it and
// fnc_createzone empties it at the head of each spawn cycle, so it describes the garrison currently
// on the ground rather than every garrison the zone has ever had.
//
// A roster rather than a flag on each unit: the capture condition reads this twice a second while a
// player stands in the zone, and walking allUnits to find the stamped ones would put a
// several-hundred-entry scan on exactly the frames a firefight is using.
fnc_zone_roster = {
	params ["_zoneKey"];
	private _var = format ["DUWS_zoneUnits_%1", _zoneKey];
	private _r = missionNamespace getVariable [_var, []];
	if (isNil {missionNamespace getVariable _var}) then { missionNamespace setVariable [_var, _r] };
	_r
};

// What "this zone's garrison" is worth, wherever it happens to be standing. Deliberately not bounded
// by the zone radius: a patrol that has wandered out is still the zone's, and reinforcements that
// walk in are not, which is the whole reason the roster exists. Shared by the peak and the capture
// test so the strength a zone is measured against cannot be counted differently from the strength
// it is judged by. Units already ordered out are not defending anything.
fnc_zone_garrison_count = {
	params ["_zoneKey"];
	{ alive _x && {!(_x getVariable ["DUWS_retreating", false])} } count ([_zoneKey] call fnc_zone_roster)
};

// Bumped whenever a zone's garrison is raised, packed up, or lost. The spawn band takes up to a
// couple of minutes to place a large zone and the streaming grace period is 120 s, so a band can
// still be running when its own zone despawns; without this it would then publish a garrison peak
// describing units the sweep had already deleted, and the capture test would read that stale figure
// against empty ground as a garrison wiped.
fnc_zone_gen_bump = {
	params ["_zoneKey"];
	private _var = format ["DUWS_zoneGen_%1", _zoneKey];
	private _g = (missionNamespace getVariable [_var, 0]) + 1;
	missionNamespace setVariable [_var, _g];
	_g
};

fnc_zone_gen = {
	params ["_zoneKey"];
	missionNamespace getVariable [format ["DUWS_zoneGen_%1", _zoneKey], 0]
};

// CONTRACT: every path that removes a zone's garrison calls this, and nothing else clears a peak.
// A peak outliving the units it counted reads empty ground as a garrison beaten, so the zone falls
// to whoever walks in next -- silently, with nothing wrong in the SQF to find. Clear and bump are
// one act because either alone leaves that open: the stale figure stands, or a band still placing
// from the torn-down cycle republishes it. fnc_spawnWait is today's only caller; a teardown by any
// other route needs it too.
fnc_zone_garrison_dropped = {
	params ["_zoneKey"];
	missionNamespace setVariable [format ["DUWS_zonePeak_%1", _zoneKey], nil];
	[_zoneKey] call fnc_zone_gen_bump;
};

// How much of its original garrison a zone still has, as a fraction. Read by everything that places
// OPFOR for a zone, so a force the player broke is not handed back to them intact two minutes later.
fnc_zone_strength = {
	params ["_zoneKey"];
	missionNamespace getVariable [format ["DUWS_zoneStrength_%1", _zoneKey], 1]
};

// The one writer, so a mechanic that lets OPFOR rebuild a mauled zone -- spending to restore ground
// they hold, rather than the player being refunded the loss by walking away -- has a single place to
// go through, and inherits the quantisation and the floor rather than restating them.
//
// Tenths because this is a spawn budget, not a casualty ledger: what it scales is whole groups,
// whole buildings and whole emplacements, so finer resolution rounds away at the point of use. The
// epsilon absorbs float slop rather than shifting the rule: SQF scalars are 32-bit floats, and a
// division landing a hair above an exact tenth would buy the garrison a whole free step.
//
// The 0.3 floor is the mechanic rather than a guard. Against the 0.2 break line in
// fnc_zone_capture_ready, a garrison at the floor still sits a tenth of the zone's original strength
// above beaten, so retaking ground you softened is a fight rather than a walk-in. A zone allowed to
// redeploy empty would also be uncapturable outright: a zero peak refuses capture.
fnc_zone_strength_set = {
	params ["_zoneKey", "_frac"];
	private _q = ((ceil ((_frac * 10) - 0.0001)) / 10) max 0.3 min 1;
	missionNamespace setVariable [format ["DUWS_zoneStrength_%1", _zoneKey], _q];
	_q
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
	// Clamped to what the zone already deployed at, so strength only ever falls. Every consumer
	// rounds its own share up and keeps at least one of whatever it is placing, so a garrison sent
	// out at three tenths stands nearer four; measured raw, an untouched zone would climb a step on
	// every visit and heal itself back to full for free.
	private _s = [_zoneKey, (_left / _base) min ([_zoneKey] call fnc_zone_strength)] call fnc_zone_strength_set;
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

// Drops entries from a spawn list at random until the fraction is met, keeping at least one. Random
// rather than off the tail: every caller's list is ordered by kind -- the tier table puts a band's
// vehicles last, the fortification builder walks towers in the order it found them -- so trimming
// the end would cost a weakened zone the same thing every time.
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
