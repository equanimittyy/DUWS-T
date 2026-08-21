// Locality: server -- called by the convoy mission threads while choosing an approach bearing.
//
// Straight-line water probe for a convoy corridor _a -> _b: true if any sample along the segment sits on
// water. Ground convoys cannot cross the sea, so a thread picking a spawn bearing re-rolls until this is
// false. Samples every ~_step metres, endpoints included; a coarse step is deliberate -- an inlet wide
// enough to strand a column is far wider than the step, and a per-metre walk is wasted work on a check
// that runs several times at spawn. This answers "is the sea in the way", not "is there a road" -- the
// callers pair it with their own nearRoads snap.
params ["_a", "_b", ["_step", 150]];
private _d = _a distance2D _b;
if (_d < 1) exitWith { surfaceIsWater _a };
private _steps = ceil (_d / _step);
private _hit = false;
for "_i" from 0 to _steps do {
    private _t = _i / _steps;
    private _p = [
        (_a select 0) + ((_b select 0) - (_a select 0)) * _t,
        (_a select 1) + ((_b select 1) - (_a select 1)) * _t
    ];
    if (surfaceIsWater _p) exitWith { _hit = true };
};
_hit
