// Locality: any -- pure arithmetic over a weight table, touching no engine state.
//
// Draws one payout kind from [[kind, weight], ...] in proportion to weight. Split out of the
// search driver because it is the only part of a search the unit layer can exercise: everything
// around it needs a corpse, a pool or a player.
//
// _roll is a 0-1 fraction standing in for the draw, so a test can name the outcome it wants.
// Negative means roll for real; a caller passing 1 exactly lands on the last kind, since the
// comparison below is strict and the accumulator ends at _total.
params ["_weights", ["_roll", -1]];

private _total = 0;
{ _total = _total + (_x select 1) } forEach _weights;
if (_total <= 0) exitWith { "" };

private _pick = if (_roll < 0) then { random _total } else { (_roll min 0.999999) * _total };

private _acc = 0;
private _out = "";
{
    _acc = _acc + (_x select 1);
    // No early exit: exitWith inside forEach would unwind the whole function and lose _out.
    if (_out isEqualTo "" && {_pick < _acc}) then { _out = _x select 0 };
} forEach _weights;

_out
