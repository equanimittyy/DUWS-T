// Locality: server, [] call'd at load. The need field a standalone build and a minefield are valued on
// (opcom_plan.md §Need and cover fields). Its holdings and band base read slow state, so they are cached and rebuilt in a
// spawned thread only when that state changes; the cache is swapped whole, so a reader never sees half a build.
if (!isServer) exitWith {};

// Weights fall by Chebyshev ring and are normalised over the block's land inside the box, so the whole amount lands
// even at a coast or the box edge.
DUWS_fnc_opcom_spread = {
    params ["_layer", "_c", "_amount"];
    private _w = DUWS_opcom_grid_w;
    private _cx = _c mod _w;
    private _cy = floor (_c / _w);
    DUWS_opcom_box params ["_minCx", "_minCy", "_maxCx", "_maxCy"];
    private _cells = [];
    private _sum = 0;
    for "_iy" from ((_cy - OPCOM_BLOCK_K) max _minCy) to ((_cy + OPCOM_BLOCK_K) min _maxCy) do {
        for "_ix" from ((_cx - OPCOM_BLOCK_K) max _minCx) to ((_cx + OPCOM_BLOCK_K) min _maxCx) do {
            private _i = _iy * _w + _ix;
            if (DUWS_opcom_grid_land select _i) then {
                private _wt = OPCOM_BLOCK_K + 1 - ((abs (_ix - _cx)) max (abs (_iy - _cy)));
                _cells pushBack [_i, _wt];
                _sum = _sum + _wt;
            };
        };
    };
    if (_sum == 0) exitWith {};
    { _x params ["_i", "_wt"]; _layer set [_i, (_layer select _i) + _amount * _wt / _sum] } forEach _cells;
};

// Every input of the holdings, the band and exposure: one missing here leaves the field stale after it changes.
DUWS_fnc_opcom_needSig = {
    [
        +WARCOM_zones_controled_by_BLUFOR,
        +(missionNamespace getVariable ["Array_of_FOBpos", []]),
        DUWS_opcom_hqKnown,
        (missionNamespace getVariable ["civ_town_rep", []]) apply { ([0, -1] select (_x <= -10)) + ([0, 1] select (_x >= 10)) },
        (DUWS_hardpoints select { (_x select 3) isEqualTo "opfor" }) apply { _x select 0 }
    ]
};

// Scheduled and slow on purpose: the band test runs the area of influence over every land cell in the box.
DUWS_fnc_opcom_needBuild = {
    private _w = DUWS_opcom_grid_w;
    private _need = DUWS_opcom_grid_land apply { 0 };
    {
        _x params ["", "_zp", "_zs", "_worth"];
        if !([[_zp] call fnc_zone_key] call fnc_zone_bluforHeld) then {
            [_need, [_zp] call DUWS_fnc_opcom_w2c, _worth * ([_zp] call DUWS_fnc_opcom_exposure)] call DUWS_fnc_opcom_spread;
        };
    } forEach zone_meta_array;
    {
        if (_x <= -10) then {
            private _pos = [_forEachIndex] call DUWS_fnc_opcom_townPos;
            [_need, [_pos] call DUWS_fnc_opcom_w2c, ([_forEachIndex] call DUWS_fnc_opcom_townWorth) * ([_pos] call DUWS_fnc_opcom_exposure)] call DUWS_fnc_opcom_spread;
        };
    } forEach (missionNamespace getVariable ["civ_town_rep", []]);
    {
        private _price = DUWS_opcom_assetPrice getOrDefault [_x select 2, 0];
        if (_price > 0 && {(_x select 3) isEqualTo "opfor"}) then {
            [_need, [_x select 1] call DUWS_fnc_opcom_w2c, _price] call DUWS_fnc_opcom_spread;
        };
    } forEach DUWS_hardpoints;

    private _worths = zone_meta_array apply { _x select 3 };
    private _base = if (_worths isEqualTo []) then { 0 } else {
        ((_worths call BIS_fnc_arithmeticMean) / ((2 * OPCOM_BLOCK_K + 1) ^ 2)) / OPCOM_NEED_BASE_RATIO
    };
    private _band = [];
    DUWS_opcom_box params ["_minCx", "_minCy", "_maxCx", "_maxCy"];
    for "_cy" from _minCy to _maxCy do {
        for "_cx" from _minCx to _maxCx do {
            private _i = _cy * _w + _cx;
            private _p = [(_cx + 0.5) * OPCOM_GRID_CELL, (_cy + 0.5) * OPCOM_GRID_CELL, 0];
            if ((DUWS_opcom_grid_land select _i) && {([_p] call fnc_aoi_field_at) > 0} && {!([_p] call fnc_aoi_in_any_zone)}) then {
                _band pushBack _i;
                _need set [_i, (_need select _i) + _base * ([_p] call DUWS_fnc_opcom_exposure)];
            };
        };
    };
    DUWS_opcom_needStatic = _need;
    DUWS_opcom_bandCells = _band;
};

// A change landing mid-build leaves the stored signature stale, so the next tick after the build rebuilds.
DUWS_fnc_opcom_needRefresh = {
    if (DUWS_opcom_needBuilding) exitWith {};
    private _sig = call DUWS_fnc_opcom_needSig;
    if (_sig isEqualTo DUWS_opcom_needSig) exitWith {};
    DUWS_opcom_needSig = _sig;
    DUWS_opcom_needBuilding = true;
    [] spawn {
        private _t = diag_tickTime;
        call DUWS_fnc_opcom_needBuild;
        DUWS_opcom_needBuilding = false;
        ["DEBUG", "OPCOM", format ["need field rebuilt: %1 band cells in %2 s", count DUWS_opcom_bandCells, (diag_tickTime - _t) toFixed 1]] call fnc_log;
    };
};

DUWS_fnc_opcom_needAt = {
    params ["_c"];
    if !(DUWS_opcom_grid_land select _c) exitWith { 0 };
    (DUWS_opcom_needStatic select _c) + ([_c] call DUWS_fnc_opcom_trafficAt) * OPCOM_AP_PER_FORCE * OPCOM_TRAFFIC_SHARE
};
