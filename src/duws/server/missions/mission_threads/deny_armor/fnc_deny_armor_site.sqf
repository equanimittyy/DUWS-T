// Site-finder for Deny Armor: the derelict tank blocks a road, so accept the dot only where a road is in reach;
// the exact snap onto the road stays a thread settle. Defers to the shared terrain gate in require-road mode,
// with the level test off since a roadside is graded ground.
//
// Contract: [_candidatePos] -> [] reject, or [_pos] accept.
params ["_pos"];
[_pos, 0, 0, "require", 100] call fnc_site_terrain
