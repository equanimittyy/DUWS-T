// Locality: server (compiled in server_fnc_init). Mean damage over every hit point, 0..1. Reads the parts,
// not damage/getDammage: field repair moves the hit points, never the hull value. Includes the pinned
// engine and un-repaired hull -- see docs/info/architecture/arma_engine_gotchas.md for why that still clears the gate.
params ["_veh"];
private _all = getAllHitPointsDamage _veh;
private _dmgs = _all param [2, []];
if (_dmgs isEqualTo []) exitWith { damage _veh };   // no hit points reported
private _sum = 0;
{
    private _d = _x;
    if (_d isEqualType "") then { _d = parseNumber _d };
    if (_d isEqualType []) then { _d = _d param [0, 0] };
    if (isNil "_d" || {!(_d isEqualType 0)}) then { _d = 0 };
    _sum = _sum + _d;
} forEach _dmgs;
_sum / (count _dmgs)
