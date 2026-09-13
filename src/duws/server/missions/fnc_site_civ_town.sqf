// Shared finder for the civilian delivery pair (Escort Informant, Deliver Supplies): both hand cargo to the
// nearest non-enemy town, so the offer must sit on that same town. Defers to fnc_site_town at the pair's 2500 m
// reach.
//
// Contract: [_candidatePos] -> [] reject, or [_townCentre] accept.
params ["_pos"];
[_pos, 2500] call fnc_site_town
