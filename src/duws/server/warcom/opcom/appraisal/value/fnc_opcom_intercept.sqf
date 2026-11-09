// Locality: server, [] call'd at load. A QRF's Value: the need around a sighting cluster x the share of the local
// defense the cluster can overwhelm, cut by OPFOR's recent losses in the cluster's block or to its groups (opcom_plan.md
// §Value). Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

// The group's force as the block reads it, so both sides of the share carry the grid's spread.
DUWS_fnc_opcom_interceptShare = {
    params ["_str", "_fri"];
    ((_str * (call DUWS_fnc_opcom_blockGain)) / (_fri + 1)) min 1
};

DUWS_fnc_opcom_interceptValue = {
    params ["_pos", "_str", "_clusterKeys"];
    private _c = [_pos] call DUWS_fnc_opcom_w2c;
    private _need = 0;
    { _need = _need + ([_x] call DUWS_fnc_opcom_needAt) } forEach ([_c, OPCOM_NEED_K] call DUWS_fnc_opcom_blockCells);
    private _lost = [[_c, 1] call DUWS_fnc_opcom_blockCells, _clusterKeys] call DUWS_fnc_opcom_lossFor;
    _need * ([_str, ([_pos] call DUWS_fnc_opcom_blockForce) select 0] call DUWS_fnc_opcom_interceptShare)
        / (1 + ((_lost - OPCOM_QRF_LOSS_FREE) max 0) / OPCOM_QRF_LOSS_K)
};
