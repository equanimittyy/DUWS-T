// Locality: any. Pure, so the unit tests drive it directly.
// Each spotter past the nearest adds only a share of its own rate: a full sum would let a garrison of
// ten at 50 m break a full kit in 5 s, and the disguise exists to move among them.
// Contract: [_meter, _floor, _dists (spotter metres), _rate (ground x body multiplier), _dt] -> meter.
#define RISE_K 100
#define RISE_NEAR 10
#define OTHER_SHARE 0.25
#define DECAY 5

params ["_meter", "_floor", "_dists", "_rate", "_dt"];

private _m = _meter max _floor;
if (_dists isEqualTo []) exitWith { (_m - DECAY * _dt) max _floor };

private _sorted = +_dists;
_sorted sort true;
private _sum = 0;
{
    _sum = _sum + ([OTHER_SHARE, 1] select (_forEachIndex == 0)) * RISE_K / (_x max RISE_NEAR);
} forEach _sorted;
(_m + _sum * _rate * _dt) min 100
