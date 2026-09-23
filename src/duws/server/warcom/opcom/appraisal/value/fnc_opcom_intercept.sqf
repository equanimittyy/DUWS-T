// Locality: server, [] call'd at load. An Intercept's Value: the need around a sighting x the share of the local defense
// the sighted group can overwhelm (opcom_plan.md §Value). Read from the pick's unscheduled pass, so nothing here may
// suspend.
if (!isServer) exitWith {};

// The group's force as the block reads it, so both sides of the share carry the grid's spread.
DUWS_fnc_opcom_interceptShare = {
    params ["_str", "_fri"];
    ((_str * (call DUWS_fnc_opcom_blockGain)) / (_fri + 1)) min 1
};

DUWS_fnc_opcom_interceptValue = {
    params ["_pos", "_str"];
    private _need = 0;
    { _need = _need + ([_x] call DUWS_fnc_opcom_needAt) } forEach ([[_pos] call DUWS_fnc_opcom_w2c, OPCOM_NEED_K] call DUWS_fnc_opcom_blockCells);
    _need * ([_str, ([_pos] call DUWS_fnc_opcom_blockForce) select 0] call DUWS_fnc_opcom_interceptShare)
};
