// Locality: server, [] call'd at load. A Rapport run's Value (opcom_plan.md §Value).
// Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

// Skewed to a neutral town: one near -10 turns anyway on the free drift, and a step barely moves one near +10.
DUWS_fnc_opcom_rapportValue = {
    params ["_worth", "_rep"];
    _worth * ((1 - (abs _rep) / 10) max 0.1) * OPCOM_RAPPORT_STEP / 10
};
