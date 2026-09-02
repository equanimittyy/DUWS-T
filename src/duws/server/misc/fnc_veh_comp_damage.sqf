// Locality: server (compiled in server_fnc_init). Mean hit-point damage, 0 (pristine)..1 (all destroyed).
// Read the parts, not damage/getDammage: field repair moves hit points but never the hull value, so a
// raw-health repair test never trips. See docs/info/architecture/arma_engine_gotchas.md.
params ["_veh"];
private _dmgs = getAllHitPointsDamage _veh param [2, []];
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
