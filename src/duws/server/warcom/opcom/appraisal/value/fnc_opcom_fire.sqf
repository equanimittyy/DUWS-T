// Locality: server, [] call'd at load. An Arty mission's pattern and what it kills (opcom_plan.md §Value).
// Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

// A gun scatters wider the further it shoots, and tighter when an OP is watching the rounds fall.
DUWS_fnc_opcom_artySpread = {
    params ["_base", "_range", "_observed"];
    (_base + OPCOM_ARTY_SPREAD_PER_KM * _range / 1000 - ([0, OPCOM_ARTY_SPREAD_OP] select _observed)) max OPCOM_ARTY_MIN_SPREAD
};

// The share of what stands in the pattern the rounds account for: each round covers its lethal area out of the
// pattern's, and rounds enough to cover it all kill everything in it once.
DUWS_fnc_opcom_artyShare = {
    params ["_rounds", "_lethal", "_area"];
    (_rounds * pi * _lethal * _lethal / (_area max 1)) min 1
};

DUWS_fnc_opcom_patternArea = {
    params ["_shape"];
    if ((_shape select 0) isEqualTo "creep") exitWith { (_shape select 1) * (_shape select 2) };
    pi * (_shape select 1) ^ 2
};

// Net kills: the commander must not shell its own units standing in the pattern, so their force comes off the
// believed force at the target before the share is taken.
DUWS_fnc_opcom_artyValue = {
    params ["_pos", "_force", "_radius", "_share"];
    private _own = 0;
    { if (((_x get "pos") distance2D _pos) < _radius) then { _own = _own + (_x get "effForce") } } forEach DUWS_opcom_taskings;
    ((_force - _own) max 0) * _share * OPCOM_AP_PER_FORCE
};
