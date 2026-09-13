// Shared offer-time terrain gate: accepts the dot only where the ground is level and dry, returning it
// unchanged -- it never snaps, so the offered icon and the built site stay together. Level matters because a
// slope leaves a fenced composition floating. Client-side in the picker: terrain queries only, no server state.
//
// Contract: [_pos, _footprint, _maxDrop] -> [] reject, or [_pos] accept.
//   _footprint  half-width of the level patch to test, metres
//   _maxDrop    reject if a footprint edge sits more than this off the centre, metres
params ["_pos", ["_footprint", 15], ["_maxDrop", 3]];

if (surfaceIsWater _pos) exitWith { [] };

private _h0 = getTerrainHeightASL _pos;
private _steep = [0, 45, 90, 135, 180, 225, 270, 315] findIf {
    abs ((getTerrainHeightASL (_pos getPos [_footprint, _x])) - _h0) > _maxDrop
};
if (_steep >= 0) exitWith { [] };

[_pos]
