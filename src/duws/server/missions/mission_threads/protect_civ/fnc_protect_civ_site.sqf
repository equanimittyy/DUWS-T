// Offer filter for Protect Informant: nearest cluster (no registered town) with a 4-slot building. Defers to
// fnc_site_cluster; the thread re-derives the same building within 30 m.
//
// Contract: [_candidatePos] -> [] reject, or [_buildingPos] accept.
params ["_pos"];
[_pos, 1, 4, "reject-all", 0] call fnc_site_cluster
