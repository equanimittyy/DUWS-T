// Locality: server, [] call'd at load. The cover field and the Value a new standalone hardpoint or minefield adds to it
// (opcom_plan.md §Need and cover fields). Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

// Siting and on-truck builds count, as they do against an asset's cap, or the siting pass sends a second truck to the
// ground the first is still driving to.
DUWS_fnc_opcom_coverCountsSweep = {
    private _pos = (DUWS_hardpoints select { (_x select 3) isEqualTo "opfor" }) apply { _x select 1 };
    { _pos pushBack (_x select 3) } forEach DUWS_opcom_buildsPending;
    {
        (_x getOrDefault ["errand", []]) params [["_kind", ""], ["_to", []]];
        if (_kind in ["build", "mine"]) then { _pos pushBack _to };
    } forEach DUWS_opcom_taskings;
    private _w = DUWS_opcom_grid_w;
    DUWS_opcom_box params ["_minCx", "_minCy", "_maxCx", "_maxCy"];
    private _n = createHashMap;
    {
        private _c = [_x] call DUWS_fnc_opcom_w2c;
        private _cx = _c mod _w;
        private _cy = floor (_c / _w);
        for "_iy" from ((_cy - OPCOM_BLOCK_K) max _minCy) to ((_cy + OPCOM_BLOCK_K) min _maxCy) do {
            for "_ix" from ((_cx - OPCOM_BLOCK_K) max _minCx) to ((_cx + OPCOM_BLOCK_K) min _maxCx) do {
                private _i = _iy * _w + _ix;
                _n set [_i, (_n getOrDefault [_i, 0]) + 1];
            };
        };
    } forEach _pos;
    _n
};

DUWS_fnc_opcom_coverCounts = { ["coverCounts", DUWS_fnc_opcom_coverCountsSweep] call DUWS_fnc_opcom_tickCached };

DUWS_fnc_opcom_coverAt = {
    params ["_c"];
    1 - 0.5 ^ ((call DUWS_fnc_opcom_coverCounts) getOrDefault [_c, 0])
};

// A new hardpoint adds half of what each cell in its reach still lacks, so one beside others earns little.
DUWS_fnc_opcom_coverValue = {
    params ["_at"];
    private _w = DUWS_opcom_grid_w;
    private _c = [_at] call DUWS_fnc_opcom_w2c;
    private _cx = _c mod _w;
    private _cy = floor (_c / _w);
    DUWS_opcom_box params ["_minCx", "_minCy", "_maxCx", "_maxCy"];
    private _sum = 0;
    for "_iy" from ((_cy - OPCOM_BLOCK_K) max _minCy) to ((_cy + OPCOM_BLOCK_K) min _maxCy) do {
        for "_ix" from ((_cx - OPCOM_BLOCK_K) max _minCx) to ((_cx + OPCOM_BLOCK_K) min _maxCx) do {
            private _i = _iy * _w + _ix;
            _sum = _sum + ([_i] call DUWS_fnc_opcom_needAt) * 0.5 * (1 - ([_i] call DUWS_fnc_opcom_coverAt));
        };
    };
    _sum
};
