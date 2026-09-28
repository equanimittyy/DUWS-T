// Locality: server; the trigger bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).

_name = _this select 0;
_points = _this select 1;
_size = _this select 2;
_zonePos = _this select 3;
_fortified = _this select 4;
_prefab = _this select 5;
_zone_num = _this select 6;
private _kind = _this param [7, ""];
// Named here, not by the locator that sited it: locators run on different localities (client
// map-click vs server allocator); an empty name means "give next", so _zone_num stays just an array index.
if (_name == "") then { _name = [] call fnc_zone_name };
_visible = true;
if (hardcore_mode_enable) then {_visible = false};


amount_zones_created = amount_zones_created + 1;
publicVariable "amount_zones_created";
zones_created = true;
publicVariable "zones_created";

// Both arrays are read downstream by the manual zone placer and by WARCOM, so every zone must be pushed onto them here.
if (isNil ("Array_of_OPFOR_zones")) then {Array_of_OPFOR_zones = [];};
Array_of_OPFOR_zones = Array_of_OPFOR_zones + [_zonePos];
zone_namePOS_pairs = zone_namePOS_pairs + [[_name,_zonePos,_visible]];
publicVariable "zone_namePOS_pairs";
// Rebuild inputs for this same function: radius/points reach the triggers only as compiled strings, so nothing
// outside can read them back. Must stay above the prefab block, which reassigns _fortified/_prefab; the name is
// omitted deliberately -- it's drawn, so a rebuild must be handed the original back rather than re-rolled.
zone_meta_array = zone_meta_array + [[_zone_num,_zonePos,_size,_points,_fortified,_prefab]];
publicVariable "zone_meta_array";

["INFO", "ZONES", format ["zone %1 registered at %2, worth %3, size %4, fortified=%5, prefab=%6",
	_zone_num, _zonePos, _points, _size, _fortified, _prefab]] call fnc_log;

// Size [0,0] below is deliberate: an icon marker at zero size draws only the text; an area marker draws its
// text as part of its shape, so the same zero size would render nothing at all.
_markername = format["%1%2",round(_zonePos select 0),round(_zonePos select 1)];
_markerstr = createMarker [str(_markername),_zonePos];
_markerstr setMarkerShape "ICON";
str(_markername) setMarkerType "o_inf";
str(_markername) setMarkerColor "ColorRed";
str(_markername) setMarkerText _name;
str(_markername) setMarkerSize [0, 0];
if (hardcore_mode_enable) then {
	str(_markername) setMarkerAlpha 0; 
} else {	
	str(_markername) setMarkerAlpha 1; 
};

_markername2 = format["%1%2ellipse",round(_zonePos select 0),round(_zonePos select 1)];
_markerstr2 = createMarker [str(_markername2),_zonePos];
_markerstr2 setMarkerShape "ELLIPSE";
str(_markername2) setMarkerBrush "SolidBorder";
str(_markername2) setMarkerColor "ColorRed";
str(_markername2) setMarkerSize [_size, _size];
if (hardcore_mode_enable) then {
	str(_markername2) setMarkerAlpha 0; 
} else {	
	str(_markername2) setMarkerAlpha 0.3; 
};

if (_prefab) then {
    private _clearRadius = 35;
    // Ahead of the sweep: the helper defines the register the sweep pushes into.
    [_zonePos, _clearRadius] call fnc_clear_buildings;
    private _allObjects = nearestObjects [_zonePos, [], _clearRadius];
    private _deletedCount = 0;
    private _hiddenCount = 0;
    {
        if (!isPlayer _x &&
            !(_x isKindOf "Man") &&
            !(_x isKindOf "Land_HelipadEmpty_F") &&
            !(_x isKindOf "FlagPole_F") &&
            !(_x isEqualTo bluHQ_object) &&
            !(_x in Array_of_FOBS)) then
        {
            deleteVehicle _x;
            if (isNull _x) then {
                _deletedCount = _deletedCount + 1;
            } else {
                _x hideObjectGlobal true;
                DUWS_terrain_hidden pushBackUnique _x;
                _hiddenCount = _hiddenCount + 1;
            };
        };
    } forEach _allObjects;
    if (_deletedCount > 0 || _hiddenCount > 0) then {
        ["INFO", "ZONES", format ["Cleared %1 objects at zone center %2 (%3 deleted, %4 hidden)",
            _deletedCount + _hiddenCount, _zonePos, _deletedCount, _hiddenCount]] call fnc_log;
    };
    sleep 0.5;
};

// Declared out here, not inside the if-blocks below, so both branches' assignment is visible to the store at the zone key.
private _prefabName = "";
// Composition builder handle: the wait further down blocks on scriptDone _prefabScript once either branch spawns it.
private _prefabScript = scriptNull;

private _zonePrefabs = call fnc_zone_prefab_set;   // [weightedList, simpleEntry], MODERN-floored
if (_prefab) then {
	_array_of_prefabs = _zonePrefabs select 0;
	// Flattened into selectRandomWeighted's [item, weight, ...] form over the whole list (not a fixed count), so an era set of any length picks correctly.
	private _weighted = [];
	{ _weighted append [_x, _x select 3] } forEach _array_of_prefabs;
	private _saved = _array_of_prefabs findIf { (_x select 0) isEqualTo _kind };
	_prefab_array = if (_saved >= 0) then { _array_of_prefabs select _saved } else { selectRandomWeighted _weighted };

	// Composition kind (not the zone name) drives the marker/readout label; radio traffic uses the callsign alone --
	// a player repeats that back, and "Comm Station" names a building, not a place.
	_prefabName = _prefab_array select 0;
	_fortified = _prefab_array select 1;
	_path = _prefab_array select 2;

	_prefabScript = [_zonePos] spawn _path;
	str(_markername) setMarkerText format["%1 (%2)", _name, _prefabName];

} else {
	_prefab = _zonePrefabs select 1;
	_prefabName = _prefab select 0;
	_fortified = _prefab select 1;
	_path = _prefab select 2;

	_prefabScript = [_zonePos] spawn _path;
	str(_markername) setMarkerText format["%1 (%2)", _name, _prefabName];
};

// No fortification ring: random-sited towers here couldn't aim at terrain/roads/approach. Replaced by the
// hardpoint system (docs/info/gameplay/hardpoints.md); the prefab composition above is unaffected.

// No QRF listener: a FiredNear handler here used to spawn distant OPFOR waves the player couldn't see or interdict.
// Reserve tasking is the commander's job now (docs/plans/opcom_plan.md).

_trg2=createTrigger["EmptyDetector",_zonePos];
_trg2 setTriggerArea[_size,_size,0,false];
_trg2 setTriggerActivation["ANYPLAYER","PRESENT",true];
_trg2 setTriggerStatements["this", format["['%1',%2,'%3','%4',thislist] spawn fnc_enterlocation;",_name,_zonePos,_markername,_markername2], ""];
// Handle not filed: nothing ever deletes this trigger, so there's no reader to keep one for -- unlike the capture
// trigger beside it, filed under trigger_<x>_<y> because fnc_captured/fnc_blufor_cap rewrite it on ownership change.

// Only the enemy-contact direction reports: walking into enemy ground is visible to the player already, but a
// counter-attack on zone they hold isn't. Server-local per fnc_captured.sqf:15's unproven trigger-locality question.
private _trgEnemy = createTrigger ["EmptyDetector", _zonePos, false];
_trgEnemy setTriggerArea [_size * 1.5, _size * 1.5, 0, false];
_trgEnemy setTriggerActivation ["EAST", "PRESENT", true];
// Carried on the trigger, not formatted into the statement string, so this position never becomes text and back.
_trgEnemy setVariable ["DUWS_zonePos", _zonePos];
_trgEnemy setVariable ["DUWS_zoneName", _name];
// Tested as BLUFOR-held rather than not-OPFOR-held, so a zone in neither list stays quiet.
// The <1m distance2D check here is identity ("is this the zone"), not proximity -- it can't use == because the
// far side round-tripped through a formatted statement string; the epsilon is arbitrary slop, unrelated to streaming radii.
_trgEnemy setTriggerStatements [
    "this && {private _p = thisTrigger getVariable ['DUWS_zonePos', []];
        (WARCOM_zones_controled_by_BLUFOR findIf { (_x distance2D _p) < 1 }) >= 0}",
    "[thisTrigger getVariable ['DUWS_zoneName', ''], thisList] call fnc_enemy_contact;",
    ""
];
// Same debounce as the HQ's: OPFOR patrolling across the boundary would otherwise re-report on every pass.
_trgEnemy setTriggerTimeout [10, 10, 10, true];

_spawnPos = _zonePos;

// The key everything about this zone files under (stow, stream thread, garrison peak, spawn flag). Derived once
// via the shared helper rather than spelled out per caller, so readers can't drift apart.
private _zoneKey = [_zonePos] call fnc_zone_key;

// Filed under the zone key, not read back off the marker text: unpicking "%1 (%2)" would break if a zone name
// ever contained a bracket.
missionNamespace setVariable [format ["DUWS_zoneKind_%1", _zoneKey], _prefabName];

// Rolled before anything spawns, since both spawn paths size off it; idempotent -- a rebuild through this same
// function keeps the tier it already has, because the roll refuses to run twice.
private _zoneTier = [_zoneKey] call fnc_zone_tier_roll;
["INFO", "ZONES", format ["%1 is tier %2, fielding %3", _zoneKey, _zoneTier,
	DUWS_zoneSpawnTiers select (_zoneTier - 1)]] call fnc_log;

// Nothing stamps OPCOM's force-grid ledger until a zone first raises, so an unvisited zone reads as zero force.
// SetFull, not Derive: the reserve pool belongs to the raise.
private _mult = (round (missionNamespace getVariable ["enemyunitMultiplier", 1])) max 1;
[_zoneKey, [[_zoneTier] call DUWS_fnc_zoneSpawnList, _mult] call DUWS_fnc_scaleComposition] call DUWS_fnc_garrisonSetFull;

// Last point this function can report completion: what follows (OPFOR spawn, then a permanent despawn monitor)
// never returns.
zones_buildout_done = zones_buildout_done + 1;
publicVariable "zones_buildout_done";

// Registered with the shared poller (owns the streaming clock): a streaming loop and a tail loop handshake per
// zone, and raise needs 2 AI but hold only 1 -- hysteresis against a zone flickering at the edge of the force that took it.
[_zoneKey, _spawnPos, _size] call fnc_site_register;
private _occ = [_zoneKey, "garrison", EAST, "zone"] call fnc_site_occupant_register_profile;
_occ set ["minAIHold", 1];
// airRingCommitted wakes the garrison for a committing aircraft (inbound heli, UAV on-station) that the
// ground-only check (fnc_duws_bluforNear) discounts -- gated to the player-crewed, speed-gated air list, so
// AI transit/support or cruising jets don't wake it; DUWS_zoneAirRing=0 keeps the ground-only default.
_occ set ["airRing", DUWS_zoneAirRing];
_occ set ["airRingCommitted", true];
// Once the player owns the ground, the force that matters is the one attacking it: see the poller.
_occ set ["enemyAware", true];
[_zoneKey, "garrison", DUWS_zoneHooks] call fnc_site_hooks_set;

// Driven by the garrison's cycle, not polled: the three occupants have a strict order -- the prefab must exist
// before anything is placed on it, and the guns must be empty before the prefab can be stowed.
{
	_x params ["_kind", "_hooks"];
	([_zoneKey, _kind] call fnc_site_occupant_register) set ["driven", true];
	[_zoneKey, _kind, _hooks] call fnc_site_hooks_set;
} forEach [["structure", DUWS_zoneStructureHooks], ["emplacement", DUWS_zoneEmplacementHooks]];

// Zones build deployed (prefab crews turrets at build time), so without this initial stow a fresh campaign carries
// every zone's props/gunners all session -- exactly the cost streaming exists to cut. The tick can't do it: its
// despawn branch only fires once a zone has raised, and an unvisited zone never has. One AI is enough here, since
// stowing an occupied zone would just deploy it again next pass.
// Waits for the builder because the prefab script places props, sleeps, places weapons, sleeps, then crews --
// a stow racing it finds nothing filed yet and returns false silently, leaving the composition and gunners
// standing for the campaign. Markers/triggers above aren't gated on this: only the stow needs the composition.
waitUntil { scriptDone _prefabScript };

// Pinned (3rd fnc_duws_keep arg) and hidden, not deleted, while the zone streams out: pinning keeps it the same
// object across stream cycles so its namespace ref, texture, Zeus-lock and carry wiring survive; hiding spares an
// inactive zone a lone flag in open country. Placed after the prefab so its clear pass can't take it, and reused
// (not recreated) on a re-entrant call, since createzone can run again for the same zone.
if (VERSION_X == "MODERN" || simple_zones_enable) then {
	private _flagVarName = format ["flag_%1_%2", floor abs (_zonePos select 0), floor abs (_zonePos select 1)];
	if (isNull (missionNamespace getVariable [_flagVarName, objNull])) then {
		// Not BIS_fnc_findSafePos: its 3 m search failed on any slope and returned a random map position, flinging the
		// flag off its zone (the [0,0,0] guard never caught that far fallback).
		(["FlagPole_F"] call fnc_class_half_extents) params ["", "", "_poleH"];
		private _cands = [];
		for "_i" from 1 to 16 do { private _t = _zonePos getPos [8 + random 18, random 360]; _t set [2, 0]; _cands pushBack _t; };
		// The footprint rays stop at 1.2 m, so a roof or overhang over the spot is left to the mast ray.
		private _idx = _cands findIf {
			(lineIntersectsSurfaces [AGLToASL (_x vectorAdd [0, 0, 0.2]), AGLToASL (_x vectorAdd [0, 0, _poleH]), objNull, objNull, true, 1, "GEOM"]) isEqualTo []
			&& {["FlagPole_F", _x, 0] call fnc_footprint_clear}
		};
		private _flagPos = _cands select (_idx max 0);
		private _flg = createVehicle ["FlagPole_F", _flagPos, [], 0, "CAN_COLLIDE"];
		_flg setPosATL [_flagPos select 0, _flagPos select 1, 0];
		_flg setFlagTexture "\A3\Data_F\Flags\flag_red_CO.paa";
		missionNamespace setVariable [_flagVarName, _flg];
		[_flg, _zoneKey, true] call fnc_duws_keep;
		// Hold the flag out of Zeus so a game master cannot delete the zone marker (fnc_asset_guard).
		[_flg] call fnc_guard_register;
		[_flg, _zoneKey] call DUWS_fnc_siteBuildArm;
		// OPFOR-held at spawn, so not yet movable.
		[_flg, false] call fnc_zone_flag_logistics;
	};
};

if !([_spawnPos, _size + DUWS_streamArrivalMargin, 1] call fnc_duws_bluforNear) then {
	[_zoneKey] call DUWS_fnc_zoneStow;
};

// Hardpoints (replacing the ring removed above) are sited in their own pass after every zone is built
// (fnc_init_OPFOR_WARCOM.sqf), not per-zone here -- but they still key off this zone's centre, so its cap guard and streaming coupling are unaffected.

// Server-local, unlike the notification trigger above: the capture condition reads the garrison ledger, which is
// server-side state a client can't see -- settling the locality question fnc_captured.sqf records as unproven.
_trg = createTrigger ["EmptyDetector", _zonePos, false];
_trg setTriggerArea [_size, _size, 0, false];
// No activation: DUWS_fnc_siteTaken tests presence itself and stamps its own hold, which a `this` gate would stop
// it resetting when the attacker steps out. The re-arm handlers swap only the statement.
_trg setTriggerActivation ["NONE", "PRESENT", true];
// Carried on the trigger, not formatted into the condition -- same reason as the enemy-contact trigger above.
_trg setVariable ["DUWS_zoneKey", _zoneKey];
// 7th arg is the retired CP-bounty slot, always 0 now: liberation pays a flat bonus (fnc_captured), not a
// worth-scaled one, and no CP rides a recapture. _points here is separate -- the zone's permanent worth,
// driving AP swings -- kept only so the 7-arg signature matches across capture handlers.
_trg setTriggerStatements ["[thisTrigger getVariable 'DUWS_zoneKey', 'zone', WEST, EAST] call DUWS_fnc_siteTaken", format["[""%1"",%2,""%3"",""%4"",%5,%6,%7] spawn fnc_captured", _name, _points, _markername, _markername2, _zonePos, _size, 0], ""];

// floor abs so the key carries no minus sign (the capture handlers rebuild the same name)
private _trgVarName = format["trigger_%1_%2", floor abs (_zonePos select 0), floor abs (_zonePos select 1)];
missionNamespace setVariable [_trgVarName, _trg];
_trg setVariable ["isZoneCaptureTrigger", true];
