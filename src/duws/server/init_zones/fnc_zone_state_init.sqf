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
