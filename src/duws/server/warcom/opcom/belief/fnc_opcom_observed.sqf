// Locality: server, executed at load by server_fnc_init ([] call compile) so it can define several functions.
// The observation tracker: the tick each BLUFOR holding was last seen. Nothing is shelled the enemy has not looked
// at, so the gate is a store of its own, stamped once a tick (opcom_plan.md §Indirect-fire hardpoints).
if (!isServer) exitWith {};

DUWS_opcom_observed = createHashMap;

// [[key, pos], ...] -- the BLUFOR holdings a gun may be aimed at.
DUWS_fnc_opcom_bluforSites = {
    private _out = [];
    { _out pushBack [[_x] call fnc_zone_key, _x] } forEach WARCOM_zones_controled_by_BLUFOR;
    { _out pushBack [format ["fob_%1", _forEachIndex], _x] } forEach (missionNamespace getVariable ["Array_of_FOBpos", []]);
    _out
};

DUWS_fnc_opcom_opPostsSweep = {
    (DUWS_hardpoints select { (_x select 2) isEqualTo "OP" && {(_x select 3) isEqualTo "opfor"} }) apply { _x select 1 }
};

// OPs are the artillery's eyes, so killing them blinds the guns.
DUWS_fnc_opcom_opWatches = {
    params ["_pos"];
    ((["opPosts", DUWS_fnc_opcom_opPostsSweep] call DUWS_fnc_opcom_tickCached)
        findIf { ([_x, _pos] call DUWS_fnc_opcom_cellDist) <= OP_OBSERVE_K }) >= 0
};

DUWS_fnc_opcom_observeUpdate = {
    if (isNil "DUWS_opcom_grid_w") exitWith {};
    private _eyes = DUWS_opcom_taskings apply { _x get "pos" };
    {
        _x params ["_key", "_pos"];
        if ((_eyes findIf { (_x distance2D _pos) < OPCOM_OBSERVE_NEAR }) >= 0 || {[_pos] call DUWS_fnc_opcom_opWatches}) then {
            DUWS_opcom_observed set [_key, DUWS_opcom_tick];
        };
    } forEach (call DUWS_fnc_opcom_bluforSites);
};

// Ticks since the holding was last seen; one never seen reads past every horizon.
DUWS_fnc_opcom_observedAge = {
    params ["_key"];
    DUWS_opcom_tick - (DUWS_opcom_observed getOrDefault [_key, -1e9])
};
