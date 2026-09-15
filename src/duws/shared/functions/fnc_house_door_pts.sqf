// Locality: any (broadcast). Maps each openable door source (fnc_house_doors) to its world position and the
// selection that position came from, so a breach shot can name the one door it hit and the locked-door action
// can anchor to that door. selectionPosition needs the leaf selection, which is usually the source name but on
// some models drops the _rot/_source suffix or lives in another LOD, so strip and fall through LODs; a source
// no LOD can place is dropped, and that door gets no anchored action.
//
// Contract: [_building] -> [[worldPos, source, selection], ...].
params ["_building"];
private _out = [];
{
    private _src = _x;
    private _names = [_src];
    { private _i = _src find _x; if (_i > 0) then { _names pushBackUnique (_src select [0, _i]) } } forEach ["_rot", "_source", "_axis"];
    private _p = [0, 0, 0];
    private _hitSel = "";
    {
        private _sel = _x;
        {
            private _q = _building selectionPosition [_sel, _x];
            if !(_q isEqualTo [0, 0, 0]) exitWith { _p = _q };
        } forEach ["Memory", "Geometry", "FireGeometry"];
        if !(_p isEqualTo [0, 0, 0]) exitWith { _hitSel = _sel };
    } forEach _names;
    if !(_p isEqualTo [0, 0, 0]) then { _out pushBack [_building modelToWorld _p, _src, _hitSel] };
} forEach ([_building] call fnc_house_doors);
_out
