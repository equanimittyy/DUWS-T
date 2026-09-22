// True when _unit sees standing head height at _pos. eyePos is ASL, so the target is converted to match.
// VIEW and GEOM together answer terrain and buildings.
// No foliage test, unlike fnc_sightline_clear: a missed bush reads as seen, which only rejects a spawn spot.
params ["_pos", "_unit"];
private _to = AGLToASL [_pos select 0, _pos select 1, 1.5];
(lineIntersectsSurfaces [eyePos _unit, _to, _unit, objNull, true, 1, "VIEW", "GEOM"]) isEqualTo []
