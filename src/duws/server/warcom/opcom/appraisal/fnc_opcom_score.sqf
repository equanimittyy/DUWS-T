// Locality: server, [] call'd at load. The score the pick ranks candidates by, and a commit weighs its units on
// (opcom_plan.md §Appraisal).
if (!isServer) exitWith {};

// Cost floors at 1: a free action would divide by zero, and its Value is already its score.
DUWS_fnc_opcom_score = {
    params ["_value", "_pWin", "_cost"];
    _pWin * _value / (_cost max 1)
};
