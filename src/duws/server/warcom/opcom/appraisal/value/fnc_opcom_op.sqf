// Locality: server, [] call'd at load. An observation post's Value: its price x the share of its block no other OP
// watches (opcom_plan.md §Value). Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

// Sea counts on neither side of the share, so a coastal post is judged on the ground it can watch.
DUWS_fnc_opcom_opUnwatched = {
    params ["_c", "_ops"];
    private _w = DUWS_opcom_grid_w;
    private _cx = _c mod _w;
    private _cy = floor (_c / _w);
    private _others = _ops apply { [_x mod _w, floor (_x / _w)] };
    (missionNamespace getVariable ["DUWS_opcom_box", [0, 0, _w - 1, _w - 1]]) params ["_minCx", "_minCy", "_maxCx", "_maxCy"];
    private _land = 0;
    private _free = 0;
    for "_iy" from ((_cy - OP_OBSERVE_K) max _minCy) to ((_cy + OP_OBSERVE_K) min _maxCy) do {
        for "_ix" from ((_cx - OP_OBSERVE_K) max _minCx) to ((_cx + OP_OBSERVE_K) min _maxCx) do {
            if (DUWS_opcom_grid_land select (_iy * _w + _ix)) then {
                _land = _land + 1;
                if ((_others findIf { ((abs ((_x select 0) - _ix)) max (abs ((_x select 1) - _iy))) <= OP_OBSERVE_K }) < 0) then {
                    _free = _free + 1;
                };
            };
        };
    };
    if (_land == 0) exitWith { 0 };
    _free / _land
};

DUWS_fnc_opcom_opValue = {
    params ["_at"];
    OPCOM_AP_OP * ([[_at] call DUWS_fnc_opcom_w2c, (["OP"] call DUWS_fnc_opcom_assetsOf) apply { [_x] call DUWS_fnc_opcom_w2c }] call DUWS_fnc_opcom_opUnwatched)
};
