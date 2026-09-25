// Locality: server, [] call'd at load. The need field a standalone build and a minefield are valued on
// (opcom_plan.md §Need and cover fields). Its holdings and band base read slow state, so they are cached and rebuilt in a
// spawned thread only when that state changes, and a hardpoint build re-spreads only the deposits over them. Each
// layer is swapped whole, so a reader never sees half a build.
if (!isServer) exitWith {};

// Weights fall by Chebyshev ring and are normalised over the block's land inside the box, so the whole amount lands
// even at a coast or the box edge.
DUWS_fnc_opcom_spread = {
    params ["_layer", "_c", "_amount"];
    private _w = DUWS_opcom_grid_w;
    private _cx = _c mod _w;
    private _cy = floor (_c / _w);
    private _cells = [];
    private _sum = 0;
    {
        if (DUWS_opcom_grid_land select _x) then {
            private _wt = OPCOM_NEED_K + 1 - ((abs ((_x mod _w) - _cx)) max (abs (floor (_x / _w) - _cy)));
            _cells pushBack [_x, _wt];
            _sum = _sum + _wt;
        };
    } forEach ([_c, OPCOM_NEED_K] call DUWS_fnc_opcom_blockCells);
    if (_sum == 0) exitWith {};
    { _x params ["_i", "_wt"]; _layer set [_i, (_layer select _i) + _amount * _wt / _sum] } forEach _cells;
};

// Every input of the band, the holdings and exposure: one missing here leaves the field stale after it changes. The
// area of influence reads no hardpoint but a radio tower, so any other build leaves this signature as it was.
DUWS_fnc_opcom_bandSig = {
    [
        +WARCOM_zones_controled_by_BLUFOR,
        +(missionNamespace getVariable ["Array_of_FOBpos", []]),
        DUWS_opcom_hqKnown,
        (missionNamespace getVariable ["civ_town_rep", []]) apply { ([0, -1] select (_x <= -10)) + ([0, 1] select (_x >= 10)) },
        (DUWS_hardpoints select { (_x select 2) isEqualTo "RADIO" }) apply { _x select 0 }
    ]
};

DUWS_fnc_opcom_depositSig = {
    (DUWS_hardpoints select { (_x select 3) isEqualTo "opfor" }) apply { _x select 0 }
};

// Scheduled and slow on purpose: the band test runs the area of influence over every land cell in the box.
DUWS_fnc_opcom_needBandBuild = {
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

    private _worths = zone_meta_array apply { _x select 3 };
    private _base = if (_worths isEqualTo []) then { 0 } else {
        ((_worths call BIS_fnc_arithmeticMean) / ((2 * OPCOM_NEED_K + 1) ^ 2)) / OPCOM_NEED_BASE_RATIO
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
    DUWS_opcom_needBase = _need;
    DUWS_opcom_bandCells = _band;
};

DUWS_fnc_opcom_needDepositBuild = {
    private _need = +DUWS_opcom_needBase;
    {
        private _price = DUWS_opcom_assetPrice getOrDefault [_x select 2, 0];
        if (_price > 0 && {(_x select 3) isEqualTo "opfor"}) then {
            [_need, [_x select 1] call DUWS_fnc_opcom_w2c, _price] call DUWS_fnc_opcom_spread;
        };
    } forEach DUWS_hardpoints;
    DUWS_opcom_needStatic = _need;
    // Patrol samples its destinations here: ground the field lights is the ground worth looking at.
    private _lit = [];
    { if (_x > 0) then { _lit pushBack _forEachIndex } } forEach _need;
    DUWS_opcom_needCells = _lit;
};

// A change landing mid-build leaves the stored signature stale, so the next tick after the build refreshes again.
DUWS_fnc_opcom_needRefresh = {
    if (DUWS_opcom_needBuilding) exitWith {};
    private _band = call DUWS_fnc_opcom_bandSig;
    private _deposit = call DUWS_fnc_opcom_depositSig;
    if (_band isNotEqualTo DUWS_opcom_bandSig) exitWith {
        private _why = [];
        // In DUWS_fnc_opcom_bandSig's part order.
        {
            if ((_band select _forEachIndex) isNotEqualTo (DUWS_opcom_bandSig param [_forEachIndex, []])) then { _why pushBack _x };
        } forEach ["zones", "fobs", "hq", "towns", "radios"];
        DUWS_opcom_bandSig = _band;
        DUWS_opcom_depositSig = _deposit;
        DUWS_opcom_needBuilding = true;
        [_why joinString ","] spawn {
            params ["_why"];
            private _t = diag_tickTime;
            private _f = diag_frameNo;
            call DUWS_fnc_opcom_needBandBuild;
            call DUWS_fnc_opcom_needDepositBuild;
            DUWS_opcom_needBuilding = false;
            ["DEBUG", "OPCOM", format ["need field rebuilt (%1): %2 band cells in %3 s over %4 frames",
                _why, count DUWS_opcom_bandCells, (diag_tickTime - _t) toFixed 1, diag_frameNo - _f]] call fnc_log;
        };
    };
    if (_deposit isEqualTo DUWS_opcom_depositSig) exitWith {};
    DUWS_opcom_depositSig = _deposit;
    private _t = diag_tickTime;
    call DUWS_fnc_opcom_needDepositBuild;
    ["DEBUG", "OPCOM", format ["need deposits re-spread: %1 hardpoints in %2 ms", count _deposit, round ((diag_tickTime - _t) * 1000)]] call fnc_log;
};

DUWS_fnc_opcom_needAt = {
    params ["_c"];
    if !(DUWS_opcom_grid_land select _c) exitWith { 0 };
    (DUWS_opcom_needStatic select _c) + ([_c] call DUWS_fnc_opcom_trafficAt) * OPCOM_AP_PER_FORCE * OPCOM_TRAFFIC_SHARE
};
