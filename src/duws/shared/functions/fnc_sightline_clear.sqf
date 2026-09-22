// Recon's hold check and its overwatch pick share this test, so the hold cannot drift from what the pick certified.
// _bothEnds also samples foliage at the _eye end, for an eye that cannot step off a bush.
// Contract: [_eye, _tgt, _ignore1, _ignore2, _bothEnds] (ASL positions, objects the ray skips) -> true when clear.
params ["_eye", "_tgt", ["_ignore1", objNull], ["_ignore2", objNull], ["_bothEnds", false]];

!(terrainIntersectASL [_eye, _tgt])
&& {(lineIntersectsSurfaces [_eye, _tgt, _ignore1, _ignore2]) isEqualTo []}
&& {[_eye, _tgt] call fnc_sightline_foliageClear}
&& {!_bothEnds || {[_tgt, _eye] call fnc_sightline_foliageClear}}
