// Locality: server, [] call'd at load. The Build actions: a hardpoint in a zone's own slots, a standalone hardpoint, an
// asset or a minefield trucked out to the band cell the siting pass chose (fnc_opcom_siting).
if (!isServer) exitWith {};

DUWS_fnc_opcom_hpPrice = {
    params ["_type"];
    OPCOM_AP_HARDPOINT getOrDefault [_type, 0]
};

DUWS_fnc_opcom_zoneSlotsUsed = {
    params ["_zk"];
    ({ (_x select 4) isEqualTo _zk } count DUWS_hardpoints) + ({ (_x select 2) isEqualTo _zk } count DUWS_opcom_buildsPending)
};

DUWS_fnc_opcom_zoneBuildTargets = {
    params ["_type"];
    if !([_type] call DUWS_fnc_opcom_hpOpen) exitWith { [] };
    private _mix = [_type] call DUWS_fnc_opcom_hpMix;
    private _out = [];
    {
        _x params ["_zk", "_zs", "", "_worth", "_exp", "_tier"];
        if (([_zk, _zs] call fnc_hardpoint_zone_cap) > ([_zk] call DUWS_fnc_opcom_zoneSlotsUsed)) then {
            _out pushBack [[_zk, _type], [_type] call DUWS_fnc_opcom_hpPrice,
                format ["Build %1 at %2", DUWS_hardpointName getOrDefault [_type, _type], [_zk] call DUWS_fnc_opcom_zoneLabel],
                _mix * ([_worth, _exp, [_type] call DUWS_fnc_hpForce, _tier] call DUWS_fnc_opcom_holdValue)];
        };
    } forEach (call DUWS_fnc_opcom_zonesOpen);
    _out
};

DUWS_fnc_opcom_standaloneBuildTargets = {
    params ["_type"];
    if !([_type] call DUWS_fnc_opcom_hpOpen && {["build", _type] call DUWS_fnc_opcom_supplyOpen}) exitWith { [] };
    private _site = ["STANDALONE"] call DUWS_fnc_opcom_siteFor;
    if (_site isEqualTo []) exitWith { [] };
    _site params ["_at", "_v"];
    private _label = format ["Build %1 at %2", DUWS_hardpointName getOrDefault [_type, _type], mapGridPosition _at];
    ([_at, _v * ([_type] call DUWS_fnc_opcom_hpMix), [_type] call DUWS_fnc_opcom_hpPrice] call DUWS_fnc_opcom_truckOffers)
        apply { _x params ["_src", "_price", "_tv", "_c"]; [[_type, _at, _src], _price, _label, _tv, 1, _c] }
};

DUWS_fnc_opcom_assetTargets = {
    params ["_type"];
    if !([_type] call DUWS_fnc_opcom_hpOpen && {["build", _type] call DUWS_fnc_opcom_supplyOpen}) exitWith { [] };
    private _site = [_type] call DUWS_fnc_opcom_siteFor;
    if (_site isEqualTo []) exitWith { [] };
    _site params ["_at", "_v"];
    private _label = format ["Build %1 at %2", DUWS_hardpointName getOrDefault [_type, _type], mapGridPosition _at];
    ([_at, _v, DUWS_opcom_assetPrice get _type] call DUWS_fnc_opcom_truckOffers)
        apply { _x params ["_src", "_price", "_tv", "_c"]; [[_type, _at, _src], _price, _label, _tv, 1, _c] }
};

// Fixed depth, length rolled per field, both in 50 m squares. The roll rides the target, so the price the
// pick weighs is the price of the belt it would actually lay.
DUWS_fnc_opcom_mineBuildTargets = {
    params ["_variant"];
    private _mixKey = format ["MINEFIELD_%1", _variant];
    if !(["MINEFIELD", _mixKey] call DUWS_fnc_opcom_hpOpen && {["mine"] call DUWS_fnc_opcom_supplyOpen}) exitWith { [] };
    private _site = ["MINE"] call DUWS_fnc_opcom_siteFor;
    if (_site isEqualTo []) exitWith { [] };
    _site params ["_at", "_v"];
    private _lo = round (OPCOM_MINE_LEN_MIN / DUWS_mineSquare);
    private _hi = round (OPCOM_MINE_LEN_MAX / DUWS_mineSquare);
    private _size = [_lo + floor random (_hi - _lo + 1), round (OPCOM_MINE_DEPTH / DUWS_mineSquare)];
    private _label = format ["Lay %1 mines at %2", _variant, mapGridPosition _at];
    ([_at, _v * ([_mixKey] call DUWS_fnc_opcom_hpMix),
        OPCOM_AP_MINEFIELD * (_size select 0) * (_size select 1)] call DUWS_fnc_opcom_truckOffers)
        apply { _x params ["_src", "_price", "_tv", "_c"]; [[_variant, _size, _at, _src], _price, _label, _tv, 1, _c] }
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
