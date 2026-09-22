// Locality: server, [] call'd at load. What an Arty mission is worth: the believed force it catches in one pattern
// (opcom_plan.md §Value). Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

// A gun scatters wider the further it shoots. The pattern the mission lays, not what the rounds are worth: where
// the rounds fall is the shooter's property, so it prices no kills.
DUWS_fnc_opcom_artySpread = {
    params ["_base", "_range"];
    (_base + OPCOM_ARTY_SPREAD_PER_KM * _range / 1000) max OPCOM_ARTY_MIN_SPREAD
};

// The radius the rounds can cover: the disc their lethal areas tile. Rounds buy footprint, so a bigger mission
// catches a looser cluster and the round count is worth choosing rather than a tax.
DUWS_fnc_opcom_artyReach = {
    params ["_lethal", "_rounds"];
    _lethal * sqrt _rounds
};

// Believed force inside the reach, weighted by the share of everything OPCOM believes is out there that stands in
// it: guns are for a mass, and a pattern that catches one squad of many is a poor use of them. OPFOR's own force
// under the pattern comes off first, over the spread rather than the reach, because that is where rounds land.
DUWS_fnc_opcom_artyValue = {
    params ["_pos", "_reach", "_spread", "_seen", "_total"];
    if (_total <= 0) exitWith { 0 };
    private _mass = 0;
    { if (((_x select 0) distance2D _pos) <= _reach) then { _mass = _mass + (_x select 1) } } forEach _seen;
    private _own = 0;
    { if (((_x get "pos") distance2D _pos) < _spread) then { _own = _own + (_x get "effForce") } } forEach DUWS_opcom_taskings;
    ((_mass - _own) max 0) * (_mass / _total) * OPCOM_AP_PER_FORCE
};
