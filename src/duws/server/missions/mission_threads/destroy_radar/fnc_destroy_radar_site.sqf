// Offer filter for Destroy Radar: a "map" dot lands on open ground, where the building garrison
// (fnc_garrisonBuildings) finds nothing -- snap to the nearest cluster to give it a block. Placement-quality
// only; the bunker guns and patrols spawn regardless, so no cluster in reach is a dropped offer, not a break.
//
// Contract: [_candidatePos] -> [] reject, or [_buildingPos] accept.
params ["_pos"];
[_pos, 3, 3, "reject-all", 0] call fnc_site_cluster
