// Locality: server (compiled in server_fnc_init). Mean field-repairable hit-point damage, 0..1.
// Reads parts, not damage/getDammage: field repair moves hit points but never the hull value. Skips
// structural hull/body too -- those no more field-repair than the hull value does, so averaging them
// pins the mean above the win gate however well the rest is fixed. See docs/info/architecture/arma_engine_gotchas.md.
params ["_veh"];
private _all = getAllHitPointsDamage _veh;
private _names = _all param [0, []];
private _dmgs = _all param [2, []];
if (_dmgs isEqualTo []) exitWith { damage _veh };   // no hit points reported
private _sum = 0;
private _n = 0;
{
    private _name = toLower (_names param [_forEachIndex, ""]);
    if (_name find "hull" < 0 && {_name find "body" < 0}) then {
        private _d = _x;
        if (_d isEqualType "") then { _d = parseNumber _d };
        if (_d isEqualType []) then { _d = _d param [0, 0] };
        if (isNil "_d" || {!(_d isEqualType 0)}) then { _d = 0 };
        _sum = _sum + _d;
        _n = _n + 1;
    };
} forEach _dmgs;
if (_n == 0) exitWith { damage _veh };   // only structural parts exposed
_sum / _n
