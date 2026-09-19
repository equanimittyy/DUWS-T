// Locality: any (a pure placement query); every caller is server-side.
//
// Fit a convoy hull's spawn point to clear ground BEFORE it is created. A raw route slot can sit on a wall or
// rock, or -- because the column is seated tight along one route -- on a hull already spawned this frame;
// createVehicle's own relocate is weak and leaves the hull inside the obstacle, where it detonates or is flung
// on spawn. findEmptyPosition tests THIS class's footprint against nearby buildings and vehicles and returns a
// spot it fits, falling back to safe ground, then the raw point. So the column is seated where it will not
// collide, rather than spawned overlapping and repaired after.
//
// Sequential use is the point: each hull is fitted just before it spawns, so it tests against the hulls already
// down and steps clear of them; fitting the whole column up front (before any is created) could not.
//
// [_pos, _class] -> _fittedPos
params ["_pos", "_class"];
private _fit = _pos findEmptyPosition [0, 25, _class];
if (_fit isEqualTo []) then {
    _fit = [_pos, 25, 0, (sizeOf _class) max 6, 0.3] call fnc_safe_pos;
};
_fit
