// Muzzle, pointer, optic and bipod sit at 1, 2, 3 and 6 of each getUnitLoadout weapon array.
params ["_loadout"];
private _out = [];
{
    private _weapon = _loadout param [_x, []];
    {
        private _cls = _weapon param [_x, ""];
        if (_cls != "") then { _out pushBackUnique _cls };
    } forEach [1, 2, 3, 6];
} forEach [0, 1, 2];
_out
