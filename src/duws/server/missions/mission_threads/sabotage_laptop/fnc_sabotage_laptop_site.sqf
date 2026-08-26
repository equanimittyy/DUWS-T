// Site-finder for the sabotage-laptop mission -- the offer filter. Accepts a candidate only where a cluster of
// at least MIN_BUILDINGS enterable buildings sits within reach, and returns the candidate itself. The mission
// marks several buildings as possible laptop sites and hides it in one, so it needs a real cluster to hunt
// through, not a lone building: a hamlet or town block in contested ground qualifies, open country or a single
// farmhouse does not.
//
// Runs client-side inside the picker (client/missions/fnc_stratmap.sqf). fnc_usableBuildings is server-only,
// so this inlines the same test as a pure engine query (nearestTerrainObjects + buildingPos) valid on any
// client, matched to that function's criteria -- a "House" terrain object with a position at index 3.
//
// Contract: [_candidatePos] -> [] reject, or [_candidatePos] accept.
params ["_pos"];

// TUNABLE. Must match the thread's building-search radius so the finder and the thread see the same cluster.
#define ACCEPT_RADIUS 350
#define MIN_BUILDINGS 3

private _bldgs = nearestTerrainObjects [_pos, ["House"], ACCEPT_RADIUS, true];
private _usable = _bldgs select { !(((_x buildingPos 3) select 0) == 0) };
if ((count _usable) < MIN_BUILDINGS) exitWith { [] };

[_pos]
