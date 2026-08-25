// Locality: server; the trigger bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).
// fnc_createZone.sqf
//  _generatezonescript = ["",_points_zone,_zone_radius,_MissionPos,_fortified,true,_i] spawn fnc_createzone
//  Name of the place,pts,radius,position,fortified,prefab,zone#
//

_name = _this select 0;
_points = _this select 1;
_size = _this select 2;
_zonePos = _this select 3;
_fortified = _this select 4;
_prefab = _this select 5;
_zone_num = _this select 6;
// Named here rather than by the locator that sited it: the manual placer's map-click body runs on
// the clicking client, and the allocator is server-side. An empty name asks for the next one, which
// is what both locators pass -- the zone number survives only as an index for the arrays below.
if (_name == "") then { _name = [] call fnc_zone_name };
_visible = true;
if (hardcore_mode_enable) then {_visible = false};


amount_zones_created = amount_zones_created + 1;
publicVariable "amount_zones_created";
zones_created = true;
publicVariable "zones_created";

// Add the zone to the array of zones (need for manual placement of zones and WARCOM)
if (isNil ("Array_of_OPFOR_zones")) then {Array_of_OPFOR_zones = [];};
Array_of_OPFOR_zones = Array_of_OPFOR_zones + [_zonePos];
zone_namePOS_pairs = zone_namePOS_pairs + [[_name,_zonePos,_visible]];
publicVariable "zone_namePOS_pairs";
// Everything needed to rebuild this zone through this same function: radius and points reach the
// triggers only as compiled strings, so nothing outside can read them. Must stay above the prefab
// block, which reassigns _fortified and _prefab to the chosen decoration. The name is absent
// deliberately: it is drawn, so a rebuild has to be handed the original back rather than re-roll it.
zone_meta_array = zone_meta_array + [[_zone_num,_zonePos,_size,_points,_fortified,_prefab]];
publicVariable "zone_meta_array";

// Add zone to the spawn/despawn array [number, blufor_close, noDespawn]

["INFO", "ZONES", format ["zone %1 registered at %2, worth %3, size %4, fortified=%5, prefab=%6",
	_zone_num, _zonePos, _points, _size, _fortified, _prefab]] call fnc_log;

// Carries the zone's name and nothing else: the size below is an icon scale, so at [0,0] the type
// draws nothing and only the text lands. It has to stay an icon marker -- an area marker draws its
// text as part of drawing its shape, so the same marker at zero size renders nothing at all.
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

// Buildings included, unlike the base sites: a prefab is dropped whole onto a centre moreUrban
// picked for being dense, so a house left standing lands inside it. The cost is that a hide is
// permanent -- a terrain object cannot be deleted, and nothing here puts the town back.
//
// Registered once for the whole campaign, on the first zone that clears ground. The engine swaps a
// hidden building for a fresh, visible one the moment its damage state changes, which is a grenade
// landing anywhere near the zone. The replacement is hidden in its turn and takes the old one's
// place in the register, so a house that is damaged twice does not come back on the second hit.
if (isNil "DUWS_zone_hidden") then {
    DUWS_zone_hidden = [];
    addMissionEventHandler ["BuildingChanged", {
        params ["_old", "_new"];
        private _i = DUWS_zone_hidden find _old;
        if (_i < 0) exitWith {};
        _new hideObjectGlobal true;
        DUWS_zone_hidden set [_i, _new];
    }];
};

if (_prefab) then {
    private _clearRadius = 35;
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
                DUWS_zone_hidden pushBack _x;
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

// Declared out here because both branches below set it and the store at the zone key reads it:
// a first assignment inside an if-block would be local to that block.
private _prefabName = "";
// The handle of the composition builder, for the opening stow further down to wait on. Same reason
// as the name above: both branches spawn one.
private _prefabScript = scriptNull;

private _zonePrefabs = call fnc_zone_prefab_set;   // [weightedList, simpleEntry], MODERN-floored
if (_prefab) then {
	_array_of_prefabs = _zonePrefabs select 0;
	// Flatten [.,.,.,weight] rows into selectRandomWeighted's [item, weight, ...] form over the whole
	// list rather than a fixed count, so an era set of any length picks correctly.
	private _weighted = [];
	{ _weighted append [_x, _x select 3] } forEach _array_of_prefabs;
	_prefab_array = selectRandomWeighted _weighted;

	// The composition's kind, not the zone's name -- it used to overwrite the name, which is why a
	// capture reported "Comm Station" while the map called the same ground Zone 4. It stays a map
	// label, on the marker and in the readout; radio traffic uses the callsign alone, because that is
	// what a player repeats back and "Comm Station" names a building rather than a place.
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

// No fortification ring. Three or four towers were scattered on a random bearing and distance, sited
// and facing by luck -- but the emplacements that make a zone worth taking need to be sited
// deliberately, against terrain, the roads and the approach the player will actually use. That is the
// hardpoint system's job, and the plan for it is docs/info/gameplay/hardpoints.md; the prefab composition
// above still stands, so a zone keeps its built centre.

// No QRF listener. A hidden object sat here carrying a FiredNear handler, so the first shot fired
// anywhere in the zone spawned up to four infantry waves at a distant OPFOR zone and walked them in
// -- reinforcement the player could neither see coming nor interdict. Tasking OPFOR reserves is the
// commander's job, and the plan for it is docs/plans/opcom_plan.md.

_trg2=createTrigger["EmptyDetector",_zonePos];
_trg2 setTriggerArea[_size,_size,0,false];
_trg2 setTriggerActivation["ANYPLAYER","PRESENT",true];
_trg2 setTriggerStatements["this", format["['%1',%2,'%3','%4',thislist] spawn fnc_enterlocation;",_name,_zonePos,_markername,_markername2], ""];
// The handle is not filed anywhere. Nothing deletes this trigger -- a zone lives for the
// campaign and its notification fires whoever owns the ground -- so there is no reader to keep
// one for. The capture trigger beside it is filed, under trigger_<x>_<y>, because fnc_captured
// and fnc_blufor_cap rewrite it on every ownership change.

// Enemy contact on ground the player holds, the same report the HQ and every FOB already make.
// Only that direction: walking into enemy ground is something the player chose and can see, so it
// announces nothing, while a counter-attack on a zone they took is news they cannot be present for.
// Server-local, so the dialogue is raised once no matter how the engine treats a global trigger's
// statement -- a question fnc_captured.sqf:15 records as unproven rather than answered.
private _trgEnemy = createTrigger ["EmptyDetector", _zonePos, false];
_trgEnemy setTriggerArea [_size, _size, 0, false];
_trgEnemy setTriggerActivation ["EAST", "PRESENT", true];
// Carried on the trigger, not formatted into the statement string, so this position never becomes
// text and back.
_trgEnemy setVariable ["DUWS_zonePos", _zonePos];
_trgEnemy setVariable ["DUWS_zoneName", _name];
// Tested as BLUFOR-held rather than not-OPFOR-held, so a zone in neither list stays quiet.
//
// The distance test below is an identity lookup -- "which zone is this" -- not a proximity check. Whether
// enemies are here is already answered by the trigger area above; this only asks whether the entry in the
// ownership list is *this* zone. It cannot use `==` or `in`, because the entry on the other side has been
// through text: the capture trigger formats its position into a statement string (`%5` below), so what
// fnc_zone_control_set files was parsed back out of characters and need not equal the array this zone was
// built from. The metre is float slop, not a game distance -- it could be 0.5 or 5 and mean the same thing,
// and it must not be folded in with the real radii the streaming checks use.
_trgEnemy setTriggerStatements [
    "this && {private _p = thisTrigger getVariable ['DUWS_zonePos', []];
        (WARCOM_zones_controled_by_BLUFOR findIf { (_x distance2D _p) < 1 }) >= 0}",
    "[thisTrigger getVariable ['DUWS_zoneName', ''], thisList] call fnc_enemy_contact;",
    ""
];
// Same debounce as the HQ's: OPFOR crossing the boundary on patrol would otherwise re-report on
// every pass.
_trgEnemy setTriggerTimeout [10, 10, 10, true];

_spawnPos = _zonePos;

// The key everything about this zone files under: its stowed composition, its streaming thread, its
// garrison peak and the flag on every unit it spawns. Derived once here through the shared helper
// rather than spelled out per caller, so the readers cannot drift apart.
private _zoneKey = [_zonePos] call fnc_zone_key;

// Filed under the zone key like the garrison state rather than read back off the marker text: the
// readout would otherwise have to unpick "%1 (%2)" to recover the kind, and a zone whose name ever
// contains a bracket would take the parse with it.
missionNamespace setVariable [format ["DUWS_zoneKind_%1", _zoneKey], _prefabName];

// Rolled before anything spawns, because both spawn paths read it to size themselves. A rebuild
// through this same function keeps the tier it already has -- the roll refuses to run twice.
private _zoneTier = [_zoneKey] call fnc_zone_tier_roll;
["INFO", "ZONES", format ["%1 is tier %2, fielding %3", _zoneKey, _zoneTier,
	DUWS_zoneSpawnTiers select (_zoneTier - 1)]] call fnc_log;

// Build-out ends here: markers, prefab, fortifications and triggers are all placed. What
// follows is OPFOR spawning and then a permanent despawn monitor, so this is the last point
// at which this function can report completion -- it never returns.
zones_buildout_done = zones_buildout_done + 1;
publicVariable "zones_buildout_done";

// Registered with the shared poller, which owns the streaming clock from here. Two permanent threads
// per zone -- a streaming loop and a tail loop polling the array slot it set -- go with the
// handshake between them; the tick raises directly and adopts what it raised.
//
// Two AI to raise a zone and one to hold it: that hysteresis stops a zone flickering off around the
// edges of the force that just took it.
[_zoneKey, _spawnPos, _size] call fnc_site_register;
private _occ = [_zoneKey, "garrison", EAST, "zone"] call fnc_site_occupant_register_profile;
_occ set ["minAIHold", 1];
// A committing aircraft -- a player-crewed heli inbound, a UAV on-station -- wakes the garrison the
// ground ring discounts as airborne (fnc_duws_bluforNear). airRingCommitted picks the poller's
// player-crewed, speed-gated air list, so an AI transit, an AI support heli, or a jet at cruise is
// not a wake. DUWS_zoneAirRing at 0 leaves the air answer off: a ground-only wake, as before.
_occ set ["airRing", DUWS_zoneAirRing];
_occ set ["airRingCommitted", true];
[_zoneKey, "garrison", DUWS_zoneHooks] call fnc_site_hooks_set;

// The zone's other two occupants: the prefab it stands on and the guns bolted to it. Driven by the
// garrison's cycle rather than polled, because the order between the three is the whole contract --
// the prefab has to exist before anyone is placed on it, and the guns have to be empty before the
// prefab can be stowed.
{
	_x params ["_kind", "_hooks"];
	([_zoneKey, _kind] call fnc_site_occupant_register) set ["driven", true];
	[_zoneKey, _kind, _hooks] call fnc_site_hooks_set;
} forEach [["structure", DUWS_zoneStructureHooks], ["emplacement", DUWS_zoneEmplacementHooks]];

// Zones are built deployed and the prefab mans their turrets at build time, so without this a fresh
// campaign carries every zone's props and gunners for the whole session -- the exact cost streaming
// exists to remove. The tick cannot do it: its despawn branch is only reachable once a zone has been
// raised, and a zone nobody has visited never has been. One AI is enough here, because stowing a zone
// somebody is already standing in would deploy it again on the next pass.
//
// Held until the builder has finished, and that wait is the whole point of it. The prefab is a
// spawned script that places its props, sleeps, places its weapons, sleeps again and only then crews
// them, so a stow racing it finds nothing filed under the key yet and returns false without a word --
// leaving the composition and its gunners standing for the campaign. The markers and triggers above
// are deliberately not behind this: only the stow needs the composition to exist.
waitUntil { scriptDone _prefabScript };
if !([_spawnPos, _size + DUWS_streamArrivalMargin, 1] call fnc_duws_bluforNear) then {
	[_zoneKey] call DUWS_fnc_zoneStow;
};

// The deliberate emplacements that replace the fortification ring removed above are sited in their own
// generation phase after every zone is built (fnc_init_OPFOR_WARCOM.sqf), not here per zone, so the
// player watches a Hard Point Generation pass between zones and civilians. Siting still keys off this
// zone's centre, so its cap guard and streaming coupling are unchanged.

// Server-local, unlike the notification trigger above it: the capture condition reads the zone's
// garrison peak, which is a server-side global, so a client evaluating it would answer for state it
// cannot see. It also settles the locality question fnc_captured.sqf records as unproven.
_trg = createTrigger ["EmptyDetector", _zonePos, false];
_trg setTriggerArea [_size, _size, 0, false];
// PRESENT rather than SEIZED on the BLUFOR direction. SEIZED demands the whole area be empty of
// OPFOR, which made a capture a sweep of every last patrol out to the zone radius; the condition
// asks instead whether the garrison is beaten and whether BLUFOR outnumber what is still standing.
// What is left in the outer streaming ring is walked off once the zone flips (fnc_zone_stream_init.sqf).
_trg setTriggerActivation ["WEST", "PRESENT", true];
// Carried on the trigger rather than formatted into the condition, so this position never becomes
// text and back -- the same reason the enemy-contact trigger above carries its own. Both ride the
// trigger through every ownership change, so the handlers that re-arm it move only the activation
// and the statement.
_trg setVariable ["DUWS_zonePos", _zonePos];
_trg setVariable ["DUWS_zoneKey", _zoneKey];
// Seventh argument is the retired CP-bounty slot, now always 0: the first capture pays a flat
// liberation bonus (fnc_captured) rather than a worth-scaled bounty, and no CP rides a recapture.
// _points stays the zone's permanent worth and drives the AP swings. The slot is kept so the 7-arg
// signature is unchanged across the capture handlers.
_trg setTriggerStatements ["this && {[thisTrigger] call fnc_zone_capture_ready}", format["[""%1"",%2,""%3"",""%4"",%5,%6,%7] spawn fnc_captured", _name, _points, _markername, _markername2, _zonePos, _size, 0], ""];
// Flat, not the usual min/mid/max spread: the hold is a rule the player learns, and a capture that
// sometimes lands at 30 s and sometimes at 50 reads as the mechanic being unreliable. Interruptable,
// so stepping off the objective restarts it.
_trg setTriggerTimeout [30, 30, 30, true];

// floor abs so the key carries no minus sign (the capture handlers rebuild the same name)
private _trgVarName = format["trigger_%1_%2", floor abs (_zonePos select 0), floor abs (_zonePos select 1)];
missionNamespace setVariable [_trgVarName, _trg];
_trg setVariable ["isZoneCaptureTrigger", true];

if (VERSION_X == "MODERN" || simple_zones_enable) then {
    private _offsetDist = 15 + random 10;
    private _offsetDir = random 360;
    private _flagPos = _zonePos getPos [_offsetDist, _offsetDir];
    
    // Safe-pos so the flag doesn't hang in the air
    private _safePos = [_flagPos, 0, 3, 1, 0, 0.2, 0] call BIS_fnc_findSafePos;
    if (_safePos isEqualTo [0,0,0]) then { _safePos = _flagPos };
    _safePos set [2, 0];
    
    private _flg = "FlagPole_F" createVehicle _safePos;
    private _flagVarName = format["flag_%1_%2", floor abs (_zonePos select 0), floor abs (_zonePos select 1)];
    missionNamespace setVariable [_flagVarName, _flg];
    _flg setFlagTexture "\A3\Data_F\Flags\flag_red_CO.paa";
};
