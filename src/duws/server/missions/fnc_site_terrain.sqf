// Shared offer-time terrain gate: accepts the dot only where the ground suits the site, and returns it
// unchanged -- it never snaps, so the offered icon and the built site stay together. Any exact snap (a tank
// onto the road) stays a thread settle. Client-side in the picker: terrain queries only, no server state.
//
// Contract: [_pos, _footprint, _maxDrop, _roadMode, _roadRadius] -> [] reject, or [_pos] accept.
//   _footprint   half-width of the level patch to test, metres
//   _maxDrop     reject if a footprint edge sits more than this off the centre; 0 disables the level test
//   _roadMode    "ignore" | "avoid" (reject a road within _roadRadius) | "require" (reject if none within it)
//   _roadRadius  road search radius for avoid / require, metres
params ["_pos", ["_footprint", 15], ["_maxDrop", 3], ["_roadMode", "ignore"], ["_roadRadius", 30]];

private _ok = !(surfaceIsWater _pos);

if (_ok && {_maxDrop > 0}) then {
    private _h0 = getTerrainHeightASL _pos;
    _ok = ([0, 45, 90, 135, 180, 225, 270, 315] findIf {
        abs ((getTerrainHeightASL (_pos getPos [_footprint, _x])) - _h0) > _maxDrop
    }) < 0;
};

if (_ok && {_roadMode != "ignore"}) then {
    private _hasRoad = (_pos nearRoads _roadRadius) isNotEqualTo [];
    _ok = if (_roadMode isEqualTo "require") then { _hasRoad } else { !_hasRoad };
};

if (_ok) then { [_pos] } else { [] }
