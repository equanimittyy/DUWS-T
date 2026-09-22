// Locality: server, [] call'd at load. OPCOM's asset hardpoints -- radio tower, OP, mortar pit, battery: what each costs,
// how many may stand, and where the ones standing or on their way are.
if (!isServer) exitWith {};

DUWS_opcom_assetPrice = createHashMapFromArray [
    ["RADIO", OPCOM_AP_TOWER], ["OP", OPCOM_AP_OP], ["MORTAR", OPCOM_AP_MORTAR], ["ARTY", OPCOM_AP_ARTY]
];

// OP carries no cap.
DUWS_opcom_assetCap = createHashMapFromArray [
    ["RADIO", AOI_OPFOR_TOWER_CAP], ["MORTAR", OPCOM_CAP_MORTAR], ["ARTY", OPCOM_CAP_ARTY]
];

// Siting and on-truck assets count too, or two trucks fill a cap's last slot or carry two posts to one spot.
DUWS_fnc_opcom_assetsOf = {
    params ["_type"];
    private _out = [];
    { if ((_x select 2) isEqualTo _type && {(_x select 3) isEqualTo "opfor"}) then { _out pushBack (_x select 1) } } forEach DUWS_hardpoints;
    { if ((_x select 1) isEqualTo _type) then { _out pushBack (_x select 3) } } forEach DUWS_opcom_buildsPending;
    {
        (_x getOrDefault ["errand", []]) params [["_kind", ""], ["_to", []], ["_t", ""]];
        if (_kind isEqualTo "build" && {_t isEqualTo _type}) then { _out pushBack _to };
    } forEach DUWS_opcom_taskings;
    _out
};

DUWS_fnc_opcom_assetOpen = {
    params ["_type"];
    (DUWS_hardpointTier getOrDefault [_type, 99]) <= WARCOM_opfor_tier
        && {count ([_type] call DUWS_fnc_opcom_assetsOf) < (DUWS_opcom_assetCap getOrDefault [_type, 1e9])}
};
