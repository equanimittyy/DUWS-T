// Offer filter for rescue-squad: nearest cluster (no registered town) with a building big enough to seat the
// whole squad, so a rural dot the thread would abort on is a clean no-offer instead. Defers to fnc_site_cluster;
// the 6-slot floor clears the recon token's fixed 5-man roster (a mod swaps classes, not the count).
//
// Contract: [_candidatePos] -> [] reject, or [_buildingPos] accept.
params ["_pos"];
[_pos, 3, 6, "reject-all", 150] call fnc_site_cluster
