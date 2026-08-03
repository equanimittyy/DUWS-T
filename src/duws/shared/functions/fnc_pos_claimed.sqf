// Locality: any. Reads zone_meta_array and duws_town_circles, both broadcast by the server.

// Does this position sit on ground the campaign already owns -- a military zone or a civilian town
// -- optionally widened by a margin?
//
// Measured against each zone's and each town's own radius. The campaign's zones_max_radius is the
// ceiling a zone may be rolled at rather than any zone's actual size, so a test against it clears a
// small zone by most of a kilometre and still leaves a zone rolled at the ceiling with its outer
// quarter open -- which is how a side mission came to be placed inside one.
//
// Ownership is not asked of a zone: one the player has taken is still ground with a garrison and an
// objective on it. Towns are here for a different reason rather than the same one -- a side mission
// fought in a town costs reputation the player never chose to spend, and its garrison lands on top
// of the town's own.
params ["_pos", ["_margin", 0]];

private _zones = missionNamespace getVariable ["zone_meta_array", []];
if ((_zones findIf { _pos distance2D (_x select 1) < ((_x select 2) + _margin) }) >= 0) exitWith { true };

private _towns = missionNamespace getVariable ["duws_town_circles", []];
(_towns findIf { _pos distance2D (_x select 0) < ((_x select 1) + _margin) }) >= 0
