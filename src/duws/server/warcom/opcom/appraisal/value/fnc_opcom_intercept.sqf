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
    private _w = DUWS_opcom_grid_w;
    private _c = [_pos] call DUWS_fnc_opcom_w2c;
    private _cx = _c mod _w;
    private _cy = floor (_c / _w);
    DUWS_opcom_box params ["_minCx", "_minCy", "_maxCx", "_maxCy"];
    private _need = 0;
    for "_iy" from ((_cy - OPCOM_NEED_K) max _minCy) to ((_cy + OPCOM_NEED_K) min _maxCy) do {
        for "_ix" from ((_cx - OPCOM_NEED_K) max _minCx) to ((_cx + OPCOM_NEED_K) min _maxCx) do {
            _need = _need + ([_iy * _w + _ix] call DUWS_fnc_opcom_needAt);
        };
    };
    _need * ([_str, ([_pos] call DUWS_fnc_opcom_blockForce) select 0] call DUWS_fnc_opcom_interceptShare)
};
