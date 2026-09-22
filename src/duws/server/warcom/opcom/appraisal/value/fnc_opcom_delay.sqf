// Locality: server, [] call'd at load. The delay discount: Value that lands later counts for less (opcom_plan.md §Value).
// Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

// Straight-line, not the route: planning a route per candidate would not fit the pick's unscheduled pass.
DUWS_fnc_opcom_delay = {
    params ["_dist", "_ticksPerCell"];
    0.5 ^ ((_dist / OPCOM_GRID_CELL) * _ticksPerCell / OPCOM_VALUE_HALFLIFE)
};

// A delivery's Value lands when the truck arrives.
DUWS_fnc_opcom_truckDelay = {
    params ["_truck"];
    [_truck select 2, DUWS_opcom_speed get (DUWS_opcom_moveType get "truck")] call DUWS_fnc_opcom_delay
};

// A commit's Value lands when the unit sent reaches its target.
DUWS_fnc_opcom_unitDelay = {
    params ["_t", "_to"];
    [(_t get "pos") distance2D _to, DUWS_opcom_speed getOrDefault [_t get "moveType", 15]] call DUWS_fnc_opcom_delay
};
