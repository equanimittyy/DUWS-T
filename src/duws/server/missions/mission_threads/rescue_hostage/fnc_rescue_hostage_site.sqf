// Offer filter for rescue-hostage: nearest cluster clear of the zone fight, in no-man's-land or a neutral town
// but never a side-held one -- a covert rescue. The 300 m standoff and "allow-neutral" policy are that rule.
// Defers to fnc_site_cluster; the thread re-derives the building.
//
// Contract: [_candidatePos] -> [] reject, or [_buildingPos] accept.
params ["_pos"];
[_pos, 3, 3, "allow-neutral", 300] call fnc_site_cluster
