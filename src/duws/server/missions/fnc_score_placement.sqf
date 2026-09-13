// Spawn-time in-mission scorer: samples points in a radius around the offered centre and returns the one that
// best satisfies a weighted list of soft terrain preferences. Server-side, so it may use the costly elevation
// and line-of-sight queries the client-side offer finder cannot. Each term is normalised across the sample set
// before weighting, so a raw tree count and a metre of prominence compare fairly. An all-zero field returns the
// centre, so a caller whose preferences are all unmet degrades to a plain settle instead of wandering.
//
// Contract: [_center, _radius, _criteria] -> _bestPos
//   _criteria  list of [term, weight, arg?]: "forest" (tree density), "high" (prominence above the local ring),
//              "los" (clear sight from the point to arg, a target position)
params ["_center", ["_radius", 150], ["_criteria", []]];

private _c2 = [_center select 0, _center select 1];
if (_criteria isEqualTo []) exitWith { _c2 };

#define SAMPLES 24
private _cands = [_c2];
for "_i" from 1 to SAMPLES do {
    (_center getPos [_radius * sqrt (random 1), random 360]) params ["_x", "_y"];
    _cands pushBack [_x, _y];
};

private _rawFor = {
    params ["_p", "_term", "_arg"];
    switch (_term) do {
        case "forest": { count nearestTerrainObjects [_p, ["TREE", "SMALL TREE"], 60, false, true] };
        case "high": {
            private _ring = [0, 60, 120, 180, 240, 300] apply { getTerrainHeightASL (_p getPos [80, _x]) };
            (getTerrainHeightASL _p) - (_ring call BIS_fnc_arithmeticMean)
        };
        case "los": {
            if (_arg isEqualTo []) exitWith { 0 };
            private _a = ATLToASL [_p select 0, _p select 1, (getTerrainHeightASL _p) + 12];
            private _b = ATLToASL [_arg select 0, _arg select 1, (getTerrainHeightASL _arg) + 2];
            if (terrainIntersectASL [_a, _b]) then { 0 } else { 1 }
        };
        default { 0 };
    };
};

// Sum of each term's min-max normalisation across the samples, so weights compare on a common 0..1 scale.
private _totals = _cands apply { 0 };
{
    _x params ["_term", ["_w", 1], ["_arg", []]];
    private _raw = _cands apply { [_x, _term, _arg] call _rawFor };
    private _lo = selectMin _raw;
    private _span = (selectMax _raw) - _lo;
    {
        private _n = if (_span <= 0) then { 0 } else { ((_raw select _forEachIndex) - _lo) / _span };
        _totals set [_forEachIndex, (_totals select _forEachIndex) + _w * _n];
    } forEach _cands;
} forEach _criteria;

// Index 0 is the centre, so a tie or an all-zero field settles there.
private _best = selectMax _totals;
if (_best <= 0) exitWith { _c2 };
_cands select (_totals find _best)
