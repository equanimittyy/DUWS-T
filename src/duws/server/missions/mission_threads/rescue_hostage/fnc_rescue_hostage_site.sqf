// Offer filter for the rescue-hostage mission: accepts a candidate only where a building cluster to hide the
// hostage in sits clear of the capturable-zone fight and outside any side-held town (a covert rescue belongs
// in no-man's-land). Returns the candidate; the thread re-derives the exact building.
//
// Runs client-side in the picker (fnc_stratmap), so it reads only broadcast state: the cluster test is a pure
// engine query (fnc_usableBuildings' own criteria, valid on any client), zones from zone_meta_array, town
// ownership from the two broadcast lists (DUWS_enemy_town_pos / DUWS_blufor_town_pos) since civ_town_rep is
// server-only.
//
// Contract: [_candidatePos] -> [] reject, or [_candidatePos] accept.
params ["_pos"];

// TUNABLE. Must match the thread's building-search radius so the finder and the thread see the same cluster.
#define ACCEPT_RADIUS 350
#define MIN_BUILDINGS 3
#define ZONE_STANDOFF 300

// A real cluster to hide in: at least MIN_BUILDINGS enterable buildings within reach.
private _bldgs = nearestTerrainObjects [_pos, ["House"], ACCEPT_RADIUS, true];
private _usable = _bldgs select { !(((_x buildingPos 3) select 0) == 0) };
if ((count _usable) < MIN_BUILDINGS) exitWith { [] };

// Clear of the capturable-zone fight: ZONE_STANDOFF metres off every zone edge.
private _zones = missionNamespace getVariable ["zone_meta_array", []];
if ((_zones findIf { _x params ["", "_zp", "_zs"]; ((_pos distance2D _zp) - _zs) < ZONE_STANDOFF }) >= 0) exitWith { [] };

// Not inside a side-held town: reject if the candidate sits within a town whose centre is in either
// faction's broadcast list. A neutral town or open ground passes.
private _held = (missionNamespace getVariable ["DUWS_enemy_town_pos", []]) + (missionNamespace getVariable ["DUWS_blufor_town_pos", []]);
private _circles = missionNamespace getVariable ["duws_town_circles", []];
if ((_circles findIf {
    _x params ["_c", "_r"];
    (_pos distance2D _c < _r) && {(_held findIf { _x distance2D _c < 5 }) >= 0}
}) >= 0) exitWith { [] };

[_pos]
