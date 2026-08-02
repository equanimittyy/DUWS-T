// Locality: server -- publishes the site roster accessors. Called once from server_fnc_init, ahead
// of the zone and town state files, which are its consumers.
//
// A site is a keyed place that carries occupants and puts them away when nobody is near: a zone, a
// town, a FOB, the HQ. Its key is the one already in use -- zone_<x>_<y>, town_<n>, FOB_<n>, HQ.
// A site holds one roster per occupant it carries, so a town's crowd and a town's garrison are two
// rosters under one site rather than two systems that happen to share a radius.
if (!isServer) exitWith {};

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
