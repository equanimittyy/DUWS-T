// Locality: server, [] call'd at load. A per-pick cache for the sweeps every action row asks for.
if (!isServer) exitWith {};

// Every row asks for the same sweeps, and the store cannot move under them: the pick reads in one unscheduled pass and
// executes afterwards.
DUWS_opcom_tickCache = createHashMap;

DUWS_fnc_opcom_tickCacheReset = { DUWS_opcom_tickCache = createHashMap };

DUWS_fnc_opcom_tickCached = {
    params ["_key", "_fn"];
    private _row = DUWS_opcom_tickCache getOrDefault [_key, []];
    if ((_row param [0, -1]) isEqualTo DUWS_opcom_tick) exitWith { _row select 1 };
    private _v = call _fn;
    DUWS_opcom_tickCache set [_key, [DUWS_opcom_tick, _v]];
    _v
};
