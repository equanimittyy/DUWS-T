// Locality: any. Reads PosOfBLUHQ and DUWS_base_keep_radius, both broadcast by the server.

// Does this position sit within the base-keep ring of the BLUFOR HQ -- the radius the cleanup sweep
// spares (server/misc/fnc_repetitive_cleanup.sqf)? A vehicle placed outside it is collected by the
// sweep, so the depot map-retrieve bounds its drop here: the client predicate on the pick and the
// server on the reported point.
//
// False when the HQ position is not yet known, so a caller never treats an unbounded ring as inside.
// The radius falls back to 250 for a JIP client that missed the DUWS_base_keep_radius broadcast.
params ["_pos"];
if (isNil "PosOfBLUHQ" || {PosOfBLUHQ isEqualTo []}) exitWith { false };
(_pos distance2D PosOfBLUHQ) <= (missionNamespace getVariable ["DUWS_base_keep_radius", 250])
