// Locality: server, [] call'd at load. An observation post's Value: its price x the share of its block no other OP
// watches (opcom_plan.md §Value). Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

// Sea counts on neither side of the share, so a coastal post is judged on the ground it can watch.
DUWS_fnc_opcom_opUnwatched = {
    params ["_c", "_ops"];
    private _w = DUWS_opcom_grid_w;
    private _others = _ops apply { [_x mod _w, floor (_x / _w)] };
    private _land = 0;
    private _free = 0;
    {
        if (DUWS_opcom_grid_land select _x) then {
            _land = _land + 1;
            private _ix = _x mod _w;
            private _iy = floor (_x / _w);
            if ((_others findIf { ((abs ((_x select 0) - _ix)) max (abs ((_x select 1) - _iy))) <= OP_OBSERVE_K }) < 0) then {
                _free = _free + 1;
            };
        };
    } forEach ([_c, OP_OBSERVE_K] call DUWS_fnc_opcom_blockCells);
    if (_land == 0) exitWith { 0 };
    _free / _land
};

DUWS_fnc_opcom_opValue = {
    params ["_at"];
    OPCOM_AP_OP * ([[_at] call DUWS_fnc_opcom_w2c, (["OP"] call DUWS_fnc_opcom_assetsOf) apply { [_x] call DUWS_fnc_opcom_w2c }] call DUWS_fnc_opcom_opUnwatched)
};
