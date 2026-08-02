// Locality: server -- publishes the site store. Called once from server_fnc_init, ahead of the zone
// and town state files, which are its consumers.
//
// A site is a keyed place that carries occupants and puts them away when nobody is near: a zone, a
// town, a FOB, the HQ. Its key is the one already in use -- zone_<x>_<y>, town_<n>, FOB_<n>, HQ.
// A site holds one record per occupant it carries, so a town's crowd and a town's garrison are two
// occupants of one site rather than two systems that happen to share a radius.
if (!isServer) exitWith {};

// Plain values only. The mission namespace is written into save games and everything in it must have
// a serialized form, so the hooks -- which are CODE -- live in a store of their own and are rebuilt
// at boot rather than restored (docs/info/arma_engine_gotchas.md).
if (isNil "DUWS_sites") then { DUWS_sites = createHashMap };
if (isNil "DUWS_occupants") then { DUWS_occupants = createHashMap };
if (isNil "DUWS_siteHooks") then { DUWS_siteHooks = createHashMap };

// Disposal is a property of the site, not of what it carries. A zone's infantry is deleted and a
// FOB's is frozen and they are the same kind of thing, so the choice sits one level up.
//
//   stream -- occupants are taken off the map: men deleted, structures stowed. What was lost is
//             remembered as attrition rather than as objects.
//   freeze -- everything stays where it is with simulation off. For a site whose contents are the
//             player's property: rebuilding those from a table would hand back every soldier who
//             had been killed and every point of damage a building had taken.
#define DISPOSAL_DEFAULT "stream"

// Registered once, by whatever builds the place. Idempotent: a zone that is rebuilt keeps the record
// it already had, because the state on it -- the vacate latch, the empty clock -- describes the
// ground rather than the garrison currently standing on it.
fnc_site_register = {
    params ["_key", "_pos", "_radius", ["_disposal", DISPOSAL_DEFAULT]];
    private _s = DUWS_sites getOrDefault [_key, createHashMap];
    if (count _s == 0) then {
        _s set ["key", _key];
        _s set ["nextDue", 0];
        DUWS_sites set [_key, _s];
        DUWS_occupants set [_key, []];
    };
    // Refreshed on every registration: a zone can be rebuilt at a different radius, and a stale one
    // would stream against ground the site no longer covers.
    _s set ["pos", _pos];
    _s set ["radius", _radius];
    _s set ["disposal", _disposal];
    _s
};

fnc_site_at = { params ["_key"]; DUWS_sites getOrDefault [_key, createHashMap] };

// Buffer, grace and the whole presence answer are per occupant rather than per site, which the
// numbers force: a town's crowd is noticed 200 m out and cleaned up after 60 s, and the garrison
// standing in the same town is 400 and 120. Towns can sit 210 m apart where zones_spacing holds
// zones 1200 apart, and a long grace on a crowd leaves a trail of populated towns behind a player
// crossing the map -- two decisions about one town that a single pair of fields would have to pick a
// winner between. "Is anyone here" therefore has two answers at one town, and each occupant keeps
// its own.
//
// awaitVacate starts latched: an occupant registered under a player's feet would otherwise read them
// as having just walked up and raise its men around them.
fnc_site_occupant_register = {
    params ["_key", "_kind", ["_side", EAST], ["_buffer", 400], ["_grace", 120]];
    private _list = DUWS_occupants getOrDefault [_key, []];
    private _i = _list findIf { (_x get "kind") isEqualTo _kind };
    if (_i >= 0) exitWith { _list select _i };
    private _o = createHashMapFromArray [
        ["kind", _kind], ["side", _side], ["buffer", _buffer], ["grace", _grace],
        ["awake", false], ["seenLast", false], ["emptySince", -1], ["awaitVacate", true],
        ["baseline", 0], ["tier", 0], ["strength", 1], ["deployedList", []],
        ["deployedStrength", 0], ["trg", objNull], ["hold", 0],
        ["raising", false], ["withdrawing", false]
    ];
    _list pushBack _o;
    DUWS_occupants set [_key, _list];
    _o
};

// createHashMap rather than nil for a miss: every caller reads fields off the answer, and a nil
// would fault the whole pass rather than the one site that was never registered.
fnc_site_occupant = {
    params ["_key", "_kind"];
    private _list = DUWS_occupants getOrDefault [_key, []];
    private _i = _list findIf { (_x get "kind") isEqualTo _kind };
    if (_i < 0) then { createHashMap } else { _list select _i }
};

// Kept apart from the records so those stay serializable. Rebuilt at boot by whatever registers the
// site, which is also what makes a reloaded campaign safe: the data comes back from the save and the
// behaviour comes back from the source.
fnc_site_hooks_set = {
    params ["_key", "_kind", "_hooks"];
    (DUWS_siteHooks getOrDefault [_key, createHashMap, true]) set [_kind, _hooks];
};

fnc_site_hook = {
    params ["_key", "_kind", "_name"];
    ((DUWS_siteHooks getOrDefault [_key, createHashMap]) getOrDefault [_kind, createHashMap])
        getOrDefault [_name, {}]
};

// Every unit an occupant spawned, in one array per site and kind.
//
// A roster rather than a flag on each unit: the zone capture condition reads its count twice a
// second while a player stands in the zone, and walking allUnits to find the stamped ones would put
// a several-hundred-entry scan on exactly the frames a firefight is using. The crowd handler was
// doing that walk -- allUnits + allDeadMen, once per emptied town -- for want of anywhere to keep
// the list.
//
// Dead men stay on it. A corpse is still the site's to collect, and the count below asks about the
// living, so nothing has to be removed at the moment of death. What does have to leave is anything
// that changes hands -- a recruited civilian is the player's now, and a teardown that still held it
// would delete a man standing in their squad.
//
// Held outside the occupant record because a roster is object references, and the record is the half
// of this that has to survive a save.
fnc_site_roster = {
    params ["_siteKey", ["_kind", "garrison"]];
    private _var = format ["DUWS_siteUnits_%1_%2", _siteKey, _kind];
    private _r = missionNamespace getVariable [_var, []];
    // Stored on first read so every later caller appends into the same array rather than into a
    // copy the next read would discard.
    if (isNil {missionNamespace getVariable _var}) then { missionNamespace setVariable [_var, _r] };
    _r
};

// Emptied in place, not replaced: callers hold the array itself, and swapping in a new one would
// leave them appending into an array nothing reads.
fnc_site_roster_clear = {
    params ["_siteKey", ["_kind", "garrison"]];
    private _r = [_siteKey, _kind] call fnc_site_roster;
    _r resize 0;
};

fnc_site_roster_drop = {
    params ["_siteKey", "_unit", ["_kind", "garrison"]];
    private _r = [_siteKey, _kind] call fnc_site_roster;
    private _i = _r find _unit;
    if (_i >= 0) then { _r deleteAt _i };
};

// What an occupant is worth, wherever its men happen to be standing. Deliberately not bounded by the
// site radius: a patrol that has wandered out is still the site's, and reinforcements that walk in
// are not, which is the whole reason a roster exists.
fnc_site_alive = {
    params ["_siteKey", ["_kind", "garrison"]];
    { alive _x } count ([_siteKey, _kind] call fnc_site_roster)
};

// The key a town's occupants file under. One place builds it, so the crowd and the garrison cannot
// disagree about which town they are in.
fnc_town_site_key = {
    params ["_townIndex"];
    format ["town_%1", _townIndex]
};
