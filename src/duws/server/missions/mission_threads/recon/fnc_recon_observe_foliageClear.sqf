// Foliage occlusion on the target end of a recon sightline, shared by the thread's overwatch pick
// (server) and the observe hold (client) so the two cannot reach different verdicts and strand a hold
// the player can never complete -- the same drift the pick/thread split is written to avoid.
//
// lineIntersectsSurfaces, which the thread and the hold already run, blocks the solid hits: buildings,
// rocks, and the tree TRUNKS a ray passes through. The gap it leaves is the overwatch chosen to look
// DOWN onto the target -- the thread scores exactly for that -- whose ray rides high and clears the
// trunk's geometry while passing through the canopy (alpha leaves, no geometry) and the low bushes (no
// geometry LOD) that still bury the target on screen. This samples the line for those vegetation
// OBJECTS. Grass is client-side terrain clutter with no object and no geometry -- no command can
// ray-test it -- so it is out of scope and nothing here pretends to catch it.
//
// Sampled on the target end only: foliage out by the distant overwatch the player just steps around
// inside the overwatch area, but foliage on the target cannot be dodged from any bearing in the standoff
// band. Sampling that near-target stretch also makes the verdict independent of the exact eye position,
// which is what lets the thread's overwatch and the player's real eye agree. nearestTerrainObjects is a
// 2D lookup, so a tree anywhere in the corridor counts whatever its height -- conservative, the right
// way to fail a sight.
//
// Contract: [_eye, _tgt] (positions) -> true when the target end is clear of vegetation.
params ["_eye", "_tgt"];

#define FOLIAGE_KINDS  ["TREE", "SMALL TREE", "BUSH"]
#define SAMPLE_BAND    150   // metres back from the target the sample spans. TUNABLE.
#define SAMPLE_STEP    10    // sample spacing, metres. TUNABLE.
#define SAMPLE_RADIUS  6     // vegetation within this of a sample occludes -- canopy-sized, and > STEP/2
                             // so a thin trunk cannot slip a gap between samples. TUNABLE.

private _band = SAMPLE_BAND min (_eye distance _tgt);
private _dir  = _tgt vectorFromTo _eye;   // unit vector, target -> eye
private _n    = floor (_band / SAMPLE_STEP);
private _clear = true;
// From 0 so the target point itself is sampled -- a tree standing on the objective buries it.
for "_i" from 0 to _n do {
    private _p = _tgt vectorAdd (_dir vectorMultiply (_i * SAMPLE_STEP));
    if !((nearestTerrainObjects [_p, FOLIAGE_KINDS, SAMPLE_RADIUS, false]) isEqualTo []) exitWith {
        _clear = false;
    };
};
_clear
