// Locality: any. Reads zone_meta_array, which the server broadcasts on every zone registration.

// Does this position fall inside a zone's marked circle, optionally widened by a margin?
//
// Measured against each zone's own radius, which is what zone_meta_array carries. The campaign's
// zones_max_radius is the ceiling a zone may be rolled at rather than any zone's actual size, so a
// test against it clears a small zone by most of a kilometre and still leaves a zone rolled at the
// ceiling with its outer quarter open -- which is how a side mission came to be placed inside one.
//
// Ownership is not asked. A zone the player has taken is still ground with a garrison and an
// objective on it, and dropping a side mission into it reads the same either way.
params ["_pos", ["_margin", 0]];

private _meta = missionNamespace getVariable ["zone_meta_array", []];
(_meta findIf { _pos distance2D (_x select 1) < ((_x select 2) + _margin) }) >= 0
