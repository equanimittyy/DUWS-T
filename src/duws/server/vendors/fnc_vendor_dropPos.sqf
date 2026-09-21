// Locality: server -- asked before the buyer is charged, so a shop with nowhere to put the thing
// refuses the sale rather than taking the money for it.
/*
    Where a bought vehicle is set down beside its dealer. Params: [_vendor, _kind].
    Returns a position, or [] when there is no room.
*/
if (!isServer) exitWith { [] };
params ["_vendor", "_kind"];

private _o = getPos _vendor;

// Clear ground, never the shopkeeper's own feet: a vendor stands in a doorway, and a hull put down
// there would spawn through the wall behind them.
if (_kind != "boat") exitWith { [_o, 60, 15, 10, 0.3, []] call fnc_safe_pos };

// A boat has to float, which is the one thing fnc_safe_pos refuses to return. The shop was sited as
// close to the shore as the town's buildings allow, so the launch is the first open water walking out
// from it -- taken twenty metres past the first hit, so the hull clears the surf line instead of
// grounding on the beach it was found from.
private _launch = [];
for "_ring" from 1 to 12 do {
    if (_launch isEqualTo []) then {
        private _r = 25 * _ring;
        for "_i" from 0 to 15 do {
            private _bearing = _i * 22.5;
            private _out = _o getPos [_r + 20, _bearing];
            if (_launch isEqualTo []
                && {surfaceIsWater (_o getPos [_r, _bearing])}
                && {surfaceIsWater _out}) then {
                _launch = _out;
            };
        };
    };
};
_launch
