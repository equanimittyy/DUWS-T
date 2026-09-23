// Locality: server, [] call'd at load. The score the pick ranks candidates by, and a commit weighs its units on
// (opcom_plan.md §Appraisal).
if (!isServer) exitWith {};

// Cost floors at 1: a free action would divide by zero, and its Value is already its score.
DUWS_fnc_opcom_score = {
    params ["_value", "_pWin", "_cost"];
    _pWin * _value / (_cost max 1)
};

// -> _key's mix factor: its target count over its standing count, each +1 so a key with none standing reads finite.
// The target is _key's weight over the weights of _keys, times their standing count; 1 for a key outside the row.
DUWS_fnc_opcom_mixFactor = {
    params ["_row", "_counts", "_key", "_keys"];
    private _w = _row getOrDefault [_key, 0];
    if (_w <= 0) exitWith { 1 };
    private _wSum = 0;
    private _n = 0;
    { _wSum = _wSum + (_row getOrDefault [_x, 0]); _n = _n + (_counts getOrDefault [_x, 0]) } forEach _keys;
    (_n * _w / _wSum + 1) / ((_counts getOrDefault [_key, 0]) + 1)
};
