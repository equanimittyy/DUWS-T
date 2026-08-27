// Site-finder for Destroy Patrol Camp. Accepts a picker candidate only where the ground is wooded --
// the camps hide in treeline and are betrayed only by their campfire smoke -- so open ground is rejected
// and the picker draws another candidate. This is what "heavily weights treeline" reduces to: the offer
// simply does not seat where there are no trees.
//
// Runs client-side inside the picker (client/missions/fnc_stratmap.sqf), so it does terrain queries only
// (nearestTerrainObjects, a cheap engine call) and reads no server state.
//
// Contract: [_candidatePos] -> [] reject, or [_candidatePos] accept.

params ["_pos"];

// TUNABLE. How many trees must stand within this radius of the candidate for it to read as treeline.
// First-pass numbers -- raise TREE_MIN to demand denser cover, widen TREE_RADIUS to accept a forest edge.
#define TREE_RADIUS 70
#define TREE_MIN    15

private _trees = nearestTerrainObjects [_pos, ["TREE", "SMALL TREE"], TREE_RADIUS, false, true];
if (count _trees < TREE_MIN) exitWith { [] };

[_pos]
