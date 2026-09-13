// Site-finder for Rescue Downed Pilot: the crash must read as gone-down-in-the-wild, so accept the dot only on
// level ground clear of roads. Defers to the shared terrain gate in road-avoid mode.
//
// Contract: [_candidatePos] -> [] reject, or [_pos] accept.
params ["_pos"];
[_pos, 12, 3, "avoid", 150] call fnc_site_terrain
