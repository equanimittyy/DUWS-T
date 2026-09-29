// Locality: server. Every unit of _sides that sees the player now.
// Geometric, not nearTargets: a nearTargets fix refreshes about every 5 s (arma_engine_gotchas.md), so a
// 0.5 s meter would keep rising for seconds after the player broke line of sight. checkVisibility is
// the one sight test that smoke blocks. Both vehicles are ignored, because a ray from inside a hull
// hits that hull.
params ["_player", "_sides"];

private _eye = eyePos _player;
private _pv = vehicle _player;
private _cosCone = cos DISGUISE_SPOT_CONE;
private _out = [];
{
    {
        if (alive _x && {side group _x in _sides}) then {
            private _uEye = eyePos _x;
            private _look = vectorNormalized (eyeDirection _x);
            if ((_look vectorDotProduct (_uEye vectorFromTo _eye)) >= _cosCone
                && {([vehicle _x, "VIEW", _pv] checkVisibility [_uEye, _eye]) >= DISGUISE_SPOT_VIS}) then {
                _out pushBack _x;
            };
        };
    } forEach crew _x;
} forEach (_player nearEntities [["AllVehicles"], DISGUISE_SPOT_RANGE]);
_out
