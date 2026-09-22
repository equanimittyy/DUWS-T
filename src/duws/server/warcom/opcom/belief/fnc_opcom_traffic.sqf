// Locality: server, [] call'd at load. The traffic layer: the believed BLUFOR force last seen crossing each cell, halving
// every OPCOM_TRAFFIC_HALFLIFE (opcom_plan.md §Need and cover fields). Decayed lazily on read, never in a per-cell sweep.
if (!isServer) exitWith {};

// Keeps the larger of what the cell still holds and this sighting, so a route used every trip stays lit.
DUWS_fnc_opcom_trafficStamp = {
    params ["_pos", "_str"];
    if (isNil "DUWS_opcom_grid_traffic") exitWith {};
    private _c = [_pos] call DUWS_fnc_opcom_w2c;
    if (_str > ([_c] call DUWS_fnc_opcom_trafficAt)) then {
        DUWS_opcom_grid_traffic set [_c, _str];
        DUWS_opcom_grid_trafficTick set [_c, DUWS_opcom_tick];
    };
};

DUWS_fnc_opcom_trafficAt = {
    params ["_c"];
    (DUWS_opcom_grid_traffic select _c) * 0.5 ^ ((DUWS_opcom_tick - (DUWS_opcom_grid_trafficTick select _c)) / OPCOM_TRAFFIC_HALFLIFE)
};
