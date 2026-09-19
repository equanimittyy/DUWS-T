// Vegetation a lineIntersectsSurfaces ray passes through: canopy (alpha leaves, no geometry) and low
// bushes (no geometry LOD). Grass is client-side clutter with no object, so nothing can test it.
// Only the stretch next to _tgt is sampled, so the verdict holds for any eye position (the recon hold's
// eye must agree with its thread's overwatch); a caller that cannot dodge eye-end foliage swaps the args.
// 2D lookup: a tree anywhere in the corridor counts whatever its height, failing a sight conservatively.
// Contract: [_eye, _tgt] (positions) -> true when the _tgt end is clear of vegetation.
params ["_eye", "_tgt"];

#define FOLIAGE_KINDS  ["TREE", "SMALL TREE", "BUSH"]
#define SAMPLE_BAND    150   // metres back from the target the sample spans. TUNABLE.
#define SAMPLE_STEP    10    // sample spacing, metres. TUNABLE.
#define SAMPLE_RADIUS  6     // vegetation within this of a sample occludes -- canopy-sized, and > STEP/2
                             // so a thin trunk cannot slip a gap between samples. TUNABLE.

private _band = SAMPLE_BAND min (_eye distance _tgt);
private _dir  = _tgt vectorFromTo _eye;
private _n    = floor (_band / SAMPLE_STEP);
private _clear = true;
// From 0 so the target point itself is sampled -- a tree standing on the target buries it.
for "_i" from 0 to _n do {
    private _p = _tgt vectorAdd (_dir vectorMultiply (_i * SAMPLE_STEP));
    if !((nearestTerrainObjects [_p, FOLIAGE_KINDS, SAMPLE_RADIUS, false, true]) isEqualTo []) exitWith {
        _clear = false;
    };
};
_clear
