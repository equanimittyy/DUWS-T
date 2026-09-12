// Offer filter for the rescue-hostage mission: homes the offered candidate onto the nearest building cluster --
// any village, hamlet or town, NOT only a registered DUWS town -- that sits clear of the capturable-zone fight
// and outside any side-held town (a covert rescue belongs in no-man's-land). The map survey hands a broad dot on
// open ground; snapping to a real cluster within reach is what lets the type site at all, since a raw dot almost
// never has a cluster under it. The thread re-derives the exact building from the returned position.
//
// Runs client-side in the picker (fnc_stratmap), so it reads only broadcast state: nearestLocations and the
// cluster test are pure engine queries (valid on any client), zones from zone_meta_array, town ownership from the
// two broadcast lists (DUWS_enemy_town_pos / DUWS_blufor_town_pos) since civ_town_rep is server-only.
//
// Contract: [_candidatePos] -> [] reject, or [_snappedPos] accept.
params ["_pos"];

// TUNABLE. ACCEPT_RADIUS must match the thread's building-search radius so the finder and thread see the same
// cluster. SNAP_RADIUS is how far off the offered dot a settlement may sit and still be pulled in.
#define SNAP_RADIUS   1500
#define ACCEPT_RADIUS 350
#define MIN_BUILDINGS 3
#define ZONE_STANDOFF 300

private _zones = missionNamespace getVariable ["zone_meta_array", []];
private _held = (missionNamespace getVariable ["DUWS_enemy_town_pos", []]) + (missionNamespace getVariable ["DUWS_blufor_town_pos", []]);
private _circles = missionNamespace getVariable ["duws_town_circles", []];

// Settlements near the dot, nearest first (nearestLocations sorts by distance). NameLocal/NameVillage pull in
// the isolated hamlets a curated town list leaves out; the first that clears every gate wins.
private _locs = nearestLocations [_pos, ["NameCityCapital", "NameCity", "NameVillage", "NameLocal"], SNAP_RADIUS];
private _idx = _locs findIf {
    private _c = locationPosition _x;
    // A real cluster to hide in: at least MIN_BUILDINGS enterable buildings within reach.
    private _usable = (nearestTerrainObjects [_c, ["House"], ACCEPT_RADIUS, true]) select { !(((_x buildingPos 3) select 0) == 0) };
    (count _usable >= MIN_BUILDINGS)
        // Clear of the capturable-zone fight: ZONE_STANDOFF metres off every zone edge.
        && { (_zones findIf { _x params ["", "_zp", "_zs"]; ((_c distance2D _zp) - _zs) < ZONE_STANDOFF }) < 0 }
        // Not inside a side-held town (a neutral town or open-ground hamlet passes).
        && { (_circles findIf { _x params ["_tc", "_r"]; (_c distance2D _tc < _r) && {(_held findIf { _x distance2D _tc < 5 }) >= 0} }) < 0 }
};
if (_idx < 0) exitWith { [] };

[locationPosition (_locs select _idx)]
