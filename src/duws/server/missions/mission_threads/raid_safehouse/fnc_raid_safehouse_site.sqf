// Site-finder for the raid-safehouse mission -- the offer filter. Accepts a town-centre candidate only
// where a cluster of at least MIN_BUILDINGS enterable buildings sits within reach, and returns it. The
// mission scatters several candidate safehouses through the block and hides the cache in one, so it needs
// a real cluster to hide amongst, not a lone house.
//
// Runs client-side inside the picker (client/missions/fnc_stratmap.sqf). fnc_usableBuildings is server-only,
// so this inlines the same test as a pure engine query (nearestTerrainObjects + buildingPos + a config
// check), matched to what the thread accepts -- a "House" with a position at index 3 AND a lockable door.
//
// The door test is not decoration: the raid locks every candidate shut and the player breaches by shooting
// a door open. A house with no Door_1_rot animation source can neither be locked nor animated, so it is no
// safehouse -- and the same source name the lock/breach drive must exist, or the mechanic silently no-ops.
//
// Contract: [_candidatePos] -> [] reject, or [_candidatePos] accept.
params ["_pos"];

// TUNABLE. Sweep the whole town -- its own radius, floored so a tight hamlet still spans a fair block.
// Must match the thread's radius so finder and thread see the same cluster.
#define MIN_RADIUS 350
// Floor 3 candidates stay uncleared, so the crowd can only ever rule out (count - 2) decoys; below ~5 the
// asking barely narrows anything, so gate the offer on a cluster wide enough to make the deduction matter.
#define MIN_BUILDINGS 5

// Radius from the town this candidate sits in: duws_town_circles is the client-safe broadcast of the
// server-only civ_locations/civ_radii (fnc_civ_init_Tomata), so it is readable inside the picker.
// Nearest circle wins; no towns (civilians off) leaves the MIN_RADIUS floor.
private _townRad = 0;
private _bestD = 1e9;
{
    _x params ["_c", "_r"];
    private _d = _c distance2D _pos;
    if (_d < _bestD) then { _bestD = _d; _townRad = _r };
} forEach (missionNamespace getVariable ["duws_town_circles", []]);
private _radius = MIN_RADIUS max _townRad;

private _bldgs = nearestTerrainObjects [_pos, ["House"], _radius, true];
private _usable = _bldgs select {
    !(((_x buildingPos 3) select 0) == 0) &&
    { isClass (configFile >> "CfgVehicles" >> typeOf _x >> "AnimationSources" >> "Door_1_rot") }
};
if ((count _usable) < MIN_BUILDINGS) exitWith { [] };

[_pos]
