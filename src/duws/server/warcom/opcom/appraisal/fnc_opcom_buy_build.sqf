// Locality: server, [] call'd at load. The Build actions: a hardpoint in a zone's own slots, a standalone hardpoint, an
// asset or a minefield trucked out to the band cell the siting pass chose (fnc_opcom_siting).
if (!isServer) exitWith {};

DUWS_fnc_opcom_hpPrice = {
    params ["_type"];
    OPCOM_AP_HARDPOINT getOrDefault [_type, 0]
};

DUWS_fnc_opcom_zoneBuildTargets = {
    params ["_type"];
    if ((DUWS_hardpointTier getOrDefault [_type, 99]) > WARCOM_opfor_tier) exitWith { [] };
    private _out = [];
    {
        _x params ["_zk", "_zs", "", "_worth", "_exp", "_tier"];
        private _standing = { (_x select 4) isEqualTo _zk } count DUWS_hardpoints;
        private _pending = { (_x select 2) isEqualTo _zk } count DUWS_opcom_buildsPending;
        if ((([_zk, _zs] call fnc_hardpoint_zone_cap) - _standing - _pending) > 0) then {
            _out pushBack [[_zk, _type], [_type] call DUWS_fnc_opcom_hpPrice,
                format ["Build %1 at %2", DUWS_hardpointName getOrDefault [_type, _type], [_zk] call DUWS_fnc_opcom_zoneLabel],
                [_worth, _exp, [_type] call DUWS_fnc_hpForce, "zone", _tier] call DUWS_fnc_opcom_holdValue];
        };
    } forEach (call DUWS_fnc_opcom_zonesOpen);
    _out
};

DUWS_fnc_opcom_standaloneBuildTargets = {
    params ["_type"];
    if ((DUWS_hardpointTier getOrDefault [_type, 99]) > WARCOM_opfor_tier) exitWith { [] };
    private _st = ["STANDALONE"] call DUWS_fnc_opcom_siteTruck;
    if (_st isEqualTo []) exitWith { [] };
    _st params ["_at", "_v", "_truck"];
    [[[_type, _at, _truck select 0], ceil (([_type] call DUWS_fnc_opcom_hpPrice) + (_truck select 1)),
        format ["Build %1 at %2", DUWS_hardpointName getOrDefault [_type, _type], mapGridPosition _at], _v]]
};

DUWS_fnc_opcom_assetTargets = {
    params ["_type"];
    if !([_type] call DUWS_fnc_opcom_assetOpen) exitWith { [] };
    private _st = [_type] call DUWS_fnc_opcom_siteTruck;
    if (_st isEqualTo []) exitWith { [] };
    _st params ["_at", "_v", "_truck"];
    [[[_type, _at, _truck select 0], ceil ((DUWS_opcom_assetPrice get _type) + (_truck select 1)),
        format ["Build %1 at %2", DUWS_hardpointName getOrDefault [_type, _type], mapGridPosition _at], _v]]
};

// One 50 m square for now; the size rides the target, so a deeper belt is a wider candidate, not a new action.
DUWS_fnc_opcom_mineBuildTargets = {
    params ["_variant"];
    if ((DUWS_hardpointTier getOrDefault ["MINEFIELD", 99]) > WARCOM_opfor_tier) exitWith { [] };
    private _st = ["MINE"] call DUWS_fnc_opcom_siteTruck;
    if (_st isEqualTo []) exitWith { [] };
    _st params ["_at", "_v", "_truck"];
    private _size = [1, 1];
    [[[_variant, _size, _at, _truck select 0],
        ceil (OPCOM_AP_MINEFIELD * (_size select 0) * (_size select 1) + (_truck select 1)),
        format ["Lay %1 mines at %2", _variant, mapGridPosition _at], _v]]
};

// The price rides in the errand, so a build that finds no ground refunds it in full, truck included.
DUWS_fnc_opcom_standaloneBuildRun = {
    params ["_target", "_price"];
    _target params ["_type", "_at", "_src"];
    [_src, _at, ["build", _at, _type, _price]] call DUWS_fnc_opcom_supplyRun
};

DUWS_fnc_opcom_zoneBuildRun = {
    params ["_target", "_price"];
    _target params ["_zk", "_type"];
    [_type, _zk, [], _price] call DUWS_fnc_opcom_build
};

DUWS_fnc_opcom_mineBuildRun = {
    params ["_target", "_price"];
    _target params ["_variant", "_size", "_at", "_src"];
    [_src, _at, ["mine", _at, [_variant, _size], _price]] call DUWS_fnc_opcom_supplyRun
};
