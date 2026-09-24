// Locality: server, [] call'd at load. The siting pass: which band cell each band build is offered at
// (opcom_plan.md §Asset siting).
if (!isServer) exitWith {};

DUWS_opcom_sites = createHashMap;

// Index of the largest value, -1 for none.
DUWS_fnc_opcom_argMax = {
    private _best = -1;
    { if (_best < 0 || {_x > (_this select _best)}) then { _best = _forEachIndex } } forEach _this;
    _best
};

// Per asset type: its Value, called as [point, type], and how near another of its type it may not stand.
DUWS_opcom_assetSiting = createHashMapFromArray [
    ["RADIO", [DUWS_fnc_opcom_towerValue, AOI_TOWER_REACH]],
    ["OP", [DUWS_fnc_opcom_opValue, 0]],
    ["MORTAR", [DUWS_fnc_opcom_gunValue, OPCOM_GUN_STANDOFF]],
    ["ARTY", [DUWS_fnc_opcom_gunValue, OPCOM_GUN_STANDOFF]]
];

// An asset's Value reads only slow state -- the area of influence and its type's own assets -- and a tower's or a gun's
// runs the area of influence over many points, so a band cell's Value is kept until that state changes and siting
// costs what changed rather than what exists.
DUWS_opcom_siteMemo = createHashMap;

// Scheduled, before the pick's unscheduled pass: each build type takes the best of a few band cells by its own Value,
// so the pick weighs the best spot on offer rather than a random one. -> DUWS_opcom_sites, key -> [point, Value].
DUWS_fnc_opcom_siteAll = {
    params ["_samples"];
    private _sites = createHashMap;
    private _pool = +DUWS_opcom_bandCells;
    private _cells = [];
    for "_k" from 1 to (_samples min count _pool) do { _cells pushBack (_pool deleteAt (floor random count _pool)) };
    if (_cells isEqualTo []) exitWith { DUWS_opcom_sites = _sites };
    private _w = DUWS_opcom_grid_w;
    private _pts = _cells apply { [((_x mod _w) + 0.5) * OPCOM_GRID_CELL, ((floor (_x / _w)) + 0.5) * OPCOM_GRID_CELL, 0] };

    private _cover = _pts apply { [_x] call DUWS_fnc_opcom_coverValue };
    private _i = _cover call DUWS_fnc_opcom_argMax;
    _sites set ["STANDALONE", [_pts select _i, _cover select _i]];
    // A field is worth what it denies, and it denies nothing on ground nobody crosses; cover breaks a tie.
    private _denial = [];
    { _denial pushBack (([_x] call DUWS_fnc_opcom_trafficAt) * 1e3 + (_cover select _forEachIndex)) } forEach _cells;
    _i = _denial call DUWS_fnc_opcom_argMax;
    _sites set ["MINE", [_pts select _i, _cover select _i]];

    {
        private _type = _x;
        _y params ["_valueFn", "_keep"];
        if ([_type] call DUWS_fnc_opcom_hpOpen) then {
            private _others = [_type] call DUWS_fnc_opcom_assetsOf;
            private _stamp = [DUWS_opcom_needSig, _others];
            private _memo = DUWS_opcom_siteMemo getOrDefault [_type, [[], createHashMap]];
            if !((_memo select 0) isEqualTo _stamp) then { _memo = [_stamp, createHashMap]; DUWS_opcom_siteMemo set [_type, _memo] };
            private _vals = [];
            {
                private _p = _x;
                private _v = -1;
                if ((_others findIf { (_x distance2D _p) < _keep }) < 0) then {
                    private _c = _cells select _forEachIndex;
                    _v = (_memo select 1) getOrDefault [_c, -1];
                    if (_v < 0) then {
                        _v = [_p, _type] call _valueFn;
                        (_memo select 1) set [_c, _v];
                    };
                };
                _vals pushBack _v;
            } forEach _pts;
            private _j = _vals call DUWS_fnc_opcom_argMax;
            if ((_vals select _j) >= 0) then { _sites set [_type, [_pts select _j, _vals select _j]] };
        };
    } forEach DUWS_opcom_assetSiting;
    DUWS_opcom_sites = _sites;
};

// -> [point, Value], or [] with no site or the supply cap full.
DUWS_fnc_opcom_siteFor = {
    params ["_key"];
    if (call DUWS_fnc_opcom_supplyFull) exitWith { [] };
    DUWS_opcom_sites getOrDefault [_key, []]
};
