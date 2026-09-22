// Locality: server, [] call'd at load. A mortar pit's or battery's Value: its price x the share of its reach that is
// OPFOR ground no gun of its type reaches (opcom_plan.md §Value). Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

// Sampled: every cell of a 20 km disc against the area of influence would overrun the pick's unscheduled pass.
DUWS_fnc_opcom_gunShare = {
    params ["_at", "_reach", "_others"];
    private _step = _reach / 5;
    private _n = 0;
    private _free = 0;
    for "_i" from -5 to 5 do {
        for "_j" from -5 to 5 do {
            if (_i * _i + _j * _j <= 25) then {
                _n = _n + 1;
                private _p = [(_at select 0) + _i * _step, (_at select 1) + _j * _step, 0];
                if ([_p] call DUWS_fnc_opcom_landAt
                    && {(_others findIf { (_x distance2D _p) <= _reach }) < 0}
                    && {[_p] call fnc_aoi_opfor_covers}) then { _free = _free + 1 };
            };
        };
    };
    _free / _n
};

// Own type only: a pit answers contact in seconds, a battery shells across the map, so neither does the other's job.
DUWS_fnc_opcom_gunValue = {
    params ["_at", "_type"];
    private _reach = [OPCOM_ARTY_REACH, OPCOM_MORTAR_REACH] select (_type isEqualTo "MORTAR");
    (DUWS_opcom_assetPrice get _type) * ([_at, _reach, [_type] call DUWS_fnc_opcom_assetsOf] call DUWS_fnc_opcom_gunShare)
};
