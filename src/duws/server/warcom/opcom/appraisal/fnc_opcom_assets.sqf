// Locality: server, [] call'd at load. OPCOM's hardpoints: what an asset costs, how many of each type may stand, and
// where the ones standing or on their way are.
if (!isServer) exitWith {};

DUWS_opcom_assetPrice = createHashMapFromArray [
    ["RADIO", OPCOM_AP_TOWER], ["OP", OPCOM_AP_OP], ["MORTAR", OPCOM_AP_MORTAR], ["ARTY", OPCOM_AP_ARTY]
];

// Flat, unlike the per-zone caps: the guns' cap is the resident AI's.
DUWS_opcom_assetCap = createHashMapFromArray [
    ["RADIO", AOI_OPFOR_TOWER_CAP], ["MORTAR", OPCOM_CAP_MORTAR], ["ARTY", OPCOM_CAP_ARTY]
];

// Siting and on-truck builds count too, or two trucks fill a cap's last slot or carry two posts to one spot.
// -> [type -> [position, ...], mix key -> count]. A minefield's mix key carries its variant, so the mix and the caps
// weigh AT and AP apart; a civilian job's field has no variant on record and stays out of both.
DUWS_fnc_opcom_hpSweep = {
    private _byType = createHashMap;
    private _byMix = createHashMap;
    private _add = {
        params ["_type", "_pos", ["_variant", ""]];
        private _l = _byType getOrDefault [_type, []];
        _l pushBack _pos;
        _byType set [_type, _l];
        private _mk = [_type, format ["%1_%2", _type, _variant]] select (_variant isNotEqualTo "");
        _byMix set [_mk, (_byMix getOrDefault [_mk, 0]) + 1];
    };
    {
        if ((_x select 3) isEqualTo "opfor") then {
            [_x select 2, _x select 1, DUWS_opcom_mineVariants getOrDefault [_x select 0, ""]] call _add;
        };
    } forEach DUWS_hardpoints;
    { [_x select 1, _x select 3] call _add } forEach DUWS_opcom_buildsPending;
    {
        (_x getOrDefault ["errand", []]) params [["_kind", ""], ["_to", []], ["_t", ""]];
        if (_kind isEqualTo "build") then { [_t, _to] call _add };
        if (_kind isEqualTo "mine") then { ["MINEFIELD", _to, _t select 0] call _add };
    } forEach DUWS_opcom_taskings;
    [_byType, _byMix]
};

DUWS_fnc_opcom_assetsOf = {
    params ["_type"];
    ((["hardpoints", DUWS_fnc_opcom_hpSweep] call DUWS_fnc_opcom_tickCached) select 0) getOrDefault [_type, []]
};

DUWS_fnc_opcom_hpMix = {
    params ["_key"];
    private _row = ["hpMix"] call DUWS_fnc_opcom_archetypeTable;
    [_row, (["hardpoints", DUWS_fnc_opcom_hpSweep] call DUWS_fnc_opcom_tickCached) select 1, _key, keys _row]
        call DUWS_fnc_opcom_mixFactor
};

DUWS_fnc_opcom_hpCap = {
    params ["_type"];
    DUWS_opcom_assetCap getOrDefault [_type, ceil ((OPCOM_CAP_HP_TYPE_PER_ZONE getOrDefault [_type, 1e9]) * count zone_meta_array)]
};

DUWS_fnc_opcom_hpOpen = {
    params ["_type", ["_mixKey", ""]];
    if (_mixKey isEqualTo "") then { _mixKey = _type };
    (["hardpoints", DUWS_fnc_opcom_hpSweep] call DUWS_fnc_opcom_tickCached) params ["_hps", "_byMix"];
    private _all = 0;
    { _all = _all + count _y } forEach _hps;
    (DUWS_hardpointTier getOrDefault [_type, 99]) <= WARCOM_opfor_tier
        && {(_byMix getOrDefault [_mixKey, 0]) < ([_mixKey] call DUWS_fnc_opcom_hpCap)}
        && {_all < OPCOM_CAP_HP_PER_ZONE * count zone_meta_array}
};
