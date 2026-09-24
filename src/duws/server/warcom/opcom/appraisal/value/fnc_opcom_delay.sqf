// Locality: server, [] call'd at load. The delay discount: Value that lands later counts for less (opcom_plan.md §Value).
// Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

// Straight-line, not the route: planning a route per candidate would not fit the pick's unscheduled pass.
DUWS_fnc_opcom_delay = {
    params ["_dist", "_ticksPerCell"];
    0.5 ^ ((_dist / OPCOM_GRID_CELL) * _ticksPerCell / OPCOM_VALUE_HALFLIFE)
};

DUWS_fnc_opcom_moveDelay = {
    params ["_dist", "_moveType"];
    [_dist, DUWS_opcom_speed getOrDefault [_moveType, 15]] call DUWS_fnc_opcom_delay
};
