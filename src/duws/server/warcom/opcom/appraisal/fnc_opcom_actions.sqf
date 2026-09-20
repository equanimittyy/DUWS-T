// Locality: server, [] call'd at load. The action list the pick stage (fnc_opcom_pick) draws from.
// DUWS_opcom_actions row: [id, class, targets, execute].
//   call targets -> [[target, price, label], ...], the action's legal targets now. Runs inside isNil, so it never suspends.
//   [target, price] call execute -> true when the action landed; the pick charges the price only then.
if (!isServer) exitWith {};

DUWS_opcom_aiMode = "off";
DUWS_opcom_pickOnce = false;
DUWS_opcom_aiEvents = [];
DUWS_opcom_aiSeq = 0;

// Read by sequence (fnc_debug_opcom_ai), so every watcher sees each line once whenever it polls.
DUWS_fnc_opcom_aiEvent = {
    params ["_text"];
    DUWS_opcom_aiSeq = DUWS_opcom_aiSeq + 1;
    DUWS_opcom_aiEvents pushBack [DUWS_opcom_aiSeq, _text];
    if (count DUWS_opcom_aiEvents > 10) then { DUWS_opcom_aiEvents deleteAt 0 };
};

DUWS_fnc_opcom_zoneLabel = {
    params ["_zk"];
    private _i = zone_namePOS_pairs findIf { ([_x select 1] call fnc_zone_key) isEqualTo _zk };
    if (_i < 0) exitWith { _zk };
    (zone_namePOS_pairs select _i) select 0
};

DUWS_fnc_opcom_zonesOpen = {
    private _out = [];
    {
        _x params ["", "_zp", "_zs"];
        private _zk = [_zp] call fnc_zone_key;
        if (!([_zk] call fnc_zone_bluforHeld) && {!([_zk] call DUWS_fnc_opcom_zoneContested)}) then { _out pushBack [_zk, _zs] };
    } forEach zone_meta_array;
    _out
};

// 0 with nothing to buy. The step buys back random unlocked lost tokens, so it is priced at their average force.
DUWS_fnc_opcom_reinforceForce = {
    params ["_key"];
    private _lost = ([_key] call DUWS_fnc_garrisonLost) select { !([_x] call DUWS_fnc_tokenLocked) };
    private _n = ([_key] call DUWS_fnc_garrisonReinforceCount) min count _lost;
    if (_n <= 0 || {([_key] call DUWS_fnc_garrisonStrength) >= 1}) exitWith { 0 };
    _n * ([_lost] call DUWS_fnc_tokenListForce) / (count _lost)
};

DUWS_fnc_opcom_zoneReinforceTargets = {
    private _out = [];
    {
        _x params ["_zk"];
        private _force = [_zk] call DUWS_fnc_opcom_reinforceForce;
        if (_force > 0) then {
            _out pushBack [_zk, ceil (_force * OPCOM_AP_PER_FORCE), format ["Reinforce %1", [_zk] call DUWS_fnc_opcom_zoneLabel]];
        };
    } forEach (call DUWS_fnc_opcom_zonesOpen);
    _out
};

DUWS_fnc_opcom_zoneFortifyTargets = {
    private _top = count DUWS_zoneSpawnTiers;
    private _mult = (round (missionNamespace getVariable ["enemyunitMultiplier", 1])) max 1;
    private _out = [];
    {
        _x params ["_zk"];
        private _tier = [_zk] call fnc_zone_tier;
        if (_tier < _top) then {
            private _owed = [
                [[_tier] call DUWS_fnc_zoneSpawnList, _mult] call DUWS_fnc_scaleComposition,
                [[_tier + 1] call DUWS_fnc_zoneSpawnList, _mult] call DUWS_fnc_scaleComposition
            ] call DUWS_fnc_spawnDiff;
            private _price = ceil (([_owed select { !([_x] call DUWS_fnc_tokenLocked) }] call DUWS_fnc_tokenListForce) * OPCOM_AP_PER_FORCE);
            _out pushBack [_zk, _price, format ["Fortify %1 to tier %2", [_zk] call DUWS_fnc_opcom_zoneLabel, _tier + 1]];
        };
    } forEach (call DUWS_fnc_opcom_zonesOpen);
    _out
};

DUWS_fnc_opcom_unlockedTypes = {
    params ["_weights"];
    (keys _weights) select { (DUWS_hardpointTier getOrDefault [_x, 99]) <= WARCOM_opfor_tier }
};

// A type's force is fixed once the faction is; the pick prices every unlocked type each tick.
DUWS_opcom_hpPrices = createHashMap;
DUWS_fnc_opcom_hpPrice = {
    params ["_type"];
    private _p = DUWS_opcom_hpPrices getOrDefault [_type, -1];
    if (_p < 0) then {
        _p = ceil (([_type] call DUWS_fnc_hpForce) * OPCOM_AP_PER_FORCE);
        DUWS_opcom_hpPrices set [_type, _p];
    };
    _p
};

// Every unlocked type is its own candidate: the weight tables belong in the pick, where the archetype leans (4C.1).
DUWS_fnc_opcom_zoneBuildTargets = {
    private _types = [DUWS_hardpointWeightZone] call DUWS_fnc_opcom_unlockedTypes;
    if (_types isEqualTo []) exitWith { [] };
    private _out = [];
    {
        _x params ["_zk", "_zs"];
        private _standing = { (_x select 4) isEqualTo _zk } count DUWS_hardpoints;
        private _pending = { (_x select 2) isEqualTo _zk } count DUWS_opcom_buildsPending;
        if ((([_zk, _zs] call fnc_hardpoint_zone_cap) - _standing - _pending) > 0) then {
            private _label = [_zk] call DUWS_fnc_opcom_zoneLabel;
            {
                _out pushBack [[_zk, _x], [_x] call DUWS_fnc_opcom_hpPrice,
                    format ["Build %1 at %2", DUWS_hardpointName getOrDefault [_x, _x], _label]];
            } forEach _types;
        };
    } forEach (call DUWS_fnc_opcom_zonesOpen);
    _out
};

DUWS_fnc_opcom_townLabel = {
    params ["_i"];
    text ((missionNamespace getVariable ["civ_locations", []]) select _i)
};

DUWS_fnc_opcom_townPos = {
    params ["_i"];
    ([[_i] call fnc_town_site_key] call fnc_site_at) getOrDefault ["pos", []]
};

// -> [[source, pos, cost], ...]: an idle truck at 0, an open zone's hire at the hire price.
DUWS_fnc_opcom_truckSources = {
    private _out = [];
    {
        if ("supply" in (_x get "flags") && {DUWS_opcom_tick >= (_x get "hold")} && {[_x] call DUWS_fnc_opcom_drawable}) then {
            _out pushBack [["truck", _x get "id"], _x get "pos", 0];
        };
    } forEach DUWS_opcom_taskings;
    private _comp = (DUWS_opcom_recruitMenu get "truck") select 0;
    private _force = [_comp] call DUWS_fnc_tokenListForce;
    if (_force > 0 && {([_comp select 0, "OPF"] call DUWS_fnc_tokenClass) isNotEqualTo ""}) then {
        private _hire = ceil (_force * OPCOM_AP_PER_FORCE);
        {
            _x params ["_zk"];
            _out pushBack [["hire", _zk], ([_zk] call fnc_site_at) get "pos", _hire];
        } forEach (call DUWS_fnc_opcom_zonesOpen);
    };
    _out
};

// -> [source, cost] for the cheapest truck to _dest, or [] with no source.
DUWS_fnc_opcom_truckFor = {
    params ["_sources", "_dest"];
    private _best = [];
    {
        _x params ["_src", "_pos", "_base"];
        private _cost = _base + OPCOM_AP_PER_KM * (_pos distance2D _dest) / 1000;
        if (_best isEqualTo [] || {_cost < (_best select 1)}) then { _best = [_src, _cost] };
    } forEach _sources;
    _best
};

// One supply truck per town at a time, so a second never lands a buy on a garrison the first already filled.
DUWS_fnc_opcom_townsSupplied = {
    private _busy = [];
    {
        (_x getOrDefault ["errand", []]) params [["_kind", ""], ["_town", -1]];
        if (_kind in ["reinforce", "fortify", "rapport"]) then { _busy pushBackUnique _town };
    } forEach DUWS_opcom_taskings;
    _busy
};

// -> true if the truck set off. A hire the router refuses is dismissed, so a refused action leaves no unpaid truck.
DUWS_fnc_opcom_supplyRun = {
    params ["_src", "_dest", "_errand"];
    _src params ["_kind", "_ref"];
    private _t = if (_kind isEqualTo "hire") then {
        ["truck", ([_ref] call fnc_site_at) get "pos", _ref, false] call fnc_opcom_recruit
    } else {
        [_ref] call DUWS_fnc_opcom_byId
    };
    if (isNil "_t") exitWith { false };
    private _ok = [_t, "move", _dest, "", _errand] call fnc_opcom_task;
    if (!_ok && {_kind isEqualTo "hire"}) then {
        DUWS_opcom_taskings = DUWS_opcom_taskings - [_t];
        [_ref] call DUWS_fnc_opcom_zoneReserveSync;
    };
    _ok
};

DUWS_fnc_opcom_townReinforceTargets = {
    private _sources = call DUWS_fnc_opcom_truckSources;
    private _busy = call DUWS_fnc_opcom_townsSupplied;
    private _out = [];
    {
        private _i = _forEachIndex;
        if (_x < 1 || {_i in _busy}) then { continue };
        private _force = [[_i] call DUWS_fnc_townStrengthKey] call DUWS_fnc_opcom_reinforceForce;
        if (_force <= 0) then { continue };
        private _truck = [_sources, [_i] call DUWS_fnc_opcom_townPos] call DUWS_fnc_opcom_truckFor;
        if (_truck isEqualTo []) then { continue };
        _out pushBack [[_i, _truck select 0], ceil (_force * OPCOM_AP_PER_FORCE + (_truck select 1)),
            format ["Reinforce %1", [_i] call DUWS_fnc_opcom_townLabel]];
    } forEach (missionNamespace getVariable ["DUWS_townGarrisonTier", []]);
    _out
};

DUWS_fnc_opcom_townFortifyTargets = {
    private _top = count DUWS_townSpawnTiers;
    private _sources = call DUWS_fnc_opcom_truckSources;
    private _busy = call DUWS_fnc_opcom_townsSupplied;
    private _out = [];
    {
        private _i = _forEachIndex;
        private _tier = _x;
        if (_tier < 1 || {_tier >= _top} || {_i in _busy}) then { continue };
        private _truck = [_sources, [_i] call DUWS_fnc_opcom_townPos] call DUWS_fnc_opcom_truckFor;
        if (_truck isEqualTo []) then { continue };
        private _owed = [[_tier] call DUWS_fnc_townSpawnList, [_tier + 1] call DUWS_fnc_townSpawnList] call DUWS_fnc_spawnDiff;
        private _force = [_owed select { !([_x] call DUWS_fnc_tokenLocked) }] call DUWS_fnc_tokenListForce;
        _out pushBack [[_i, _truck select 0], ceil (_force * OPCOM_AP_PER_FORCE + (_truck select 1)),
            format ["Fortify %1 to tier %2", [_i] call DUWS_fnc_opcom_townLabel, _tier + 1]];
    } forEach (missionNamespace getVariable ["DUWS_townGarrisonTier", []]);
    _out
};

DUWS_fnc_opcom_rapportTargets = {
    private _sources = call DUWS_fnc_opcom_truckSources;
    private _busy = call DUWS_fnc_opcom_townsSupplied;
    private _out = [];
    {
        private _i = _forEachIndex;
        if (_x <= -15 || {_x >= 10} || {_i in _busy}) then { continue };
        private _pos = [_i] call DUWS_fnc_opcom_townPos;
        if !([_pos] call fnc_aoi_opfor_covers) then { continue };
        private _truck = [_sources, _pos] call DUWS_fnc_opcom_truckFor;
        if (_truck isEqualTo []) then { continue };
        _out pushBack [[_i, _truck select 0], ceil (OPCOM_AP_RAPPORT + (_truck select 1)),
            format ["Rapport at %1", [_i] call DUWS_fnc_opcom_townLabel]];
    } forEach (missionNamespace getVariable ["civ_town_rep", []]);
    _out
};

DUWS_fnc_opcom_recruitSupplyTargets = {
    private _hires = (call DUWS_fnc_opcom_truckSources) select { ((_x select 0) select 0) isEqualTo "hire" };
    if (_hires isEqualTo []) exitWith { [] };
    (selectRandom _hires) params ["_src", "", "_price"];
    private _zk = _src select 1;
    [[_zk, _price, format ["Recruit a truck at %1", [_zk] call DUWS_fnc_opcom_zoneLabel]]]
};

DUWS_opcom_assetPrice = createHashMapFromArray [
    ["RADIO", OPCOM_AP_TOWER], ["OP", OPCOM_AP_OP], ["MORTAR", OPCOM_AP_MORTAR], ["ARTY", OPCOM_AP_ARTY]
];
// OP carries no cap.
DUWS_opcom_assetCap = createHashMapFromArray [
    ["RADIO", AOI_OPFOR_TOWER_CAP], ["MORTAR", OPCOM_CAP_MORTAR], ["ARTY", OPCOM_CAP_ARTY]
];

// Standing, siting and still on a truck, so two trucks cannot both deliver the last slot under a cap.
DUWS_fnc_opcom_hpCount = {
    params ["_type"];
    ({ (_x select 2) isEqualTo _type && {(_x select 3) isEqualTo "opfor"} } count DUWS_hardpoints)
    + ({ (_x select 1) isEqualTo _type } count DUWS_opcom_buildsPending)
    + ({ ((_x getOrDefault ["errand", []]) param [0, ""]) isEqualTo "build" && {((_x get "errand") param [2, ""]) isEqualTo _type} } count DUWS_opcom_taskings)
};

// A random band point with its cheapest truck -> [point, [source, cost]], or [] when the draw or the truck fails.
DUWS_fnc_opcom_bandDrop = {
    private _band = call DUWS_fnc_aoi_bandPos;
    if (_band isEqualTo []) exitWith { [] };
    // findSafePos answers a 2D point; tasking positions are 3D throughout.
    private _at = +(_band select 0);
    _at set [2, 0];
    private _truck = [call DUWS_fnc_opcom_truckSources, _at] call DUWS_fnc_opcom_truckFor;
    if (_truck isEqualTo []) exitWith { [] };
    [_at, _truck]
};

DUWS_fnc_opcom_bandBuildTargets = {
    private _types = [DUWS_hardpointWeightSolo] call DUWS_fnc_opcom_unlockedTypes;
    if (_types isEqualTo []) exitWith { [] };
    private _drop = call DUWS_fnc_opcom_bandDrop;
    if (_drop isEqualTo []) exitWith { [] };
    _drop params ["_at", "_truck"];
    _types apply {
        [[_x, _at, _truck select 0], ceil (([_x] call DUWS_fnc_opcom_hpPrice) + (_truck select 1)),
            format ["Build %1 at %2", DUWS_hardpointName getOrDefault [_x, _x], mapGridPosition _at]]
    }
};

DUWS_fnc_opcom_assetTargets = {
    params ["_types"];
    private _live = _types select {
        (DUWS_hardpointTier getOrDefault [_x, 99]) <= WARCOM_opfor_tier
        && {([_x] call DUWS_fnc_opcom_hpCount) < (DUWS_opcom_assetCap getOrDefault [_x, 1e9])}
    };
    if (_live isEqualTo []) exitWith { [] };
    private _drop = call DUWS_fnc_opcom_bandDrop;
    if (_drop isEqualTo []) exitWith { [] };
    _drop params ["_at", "_truck"];
    _live apply {
        [[_x, _at, _truck select 0], ceil ((DUWS_opcom_assetPrice get _x) + (_truck select 1)),
            format ["Build %1 at %2", DUWS_hardpointName getOrDefault [_x, _x], mapGridPosition _at]]
    }
};

// One 50 m square for now; the size rides the target, so a deeper belt is a wider candidate, not a new action.
DUWS_fnc_opcom_mineBuildTargets = {
    if ((DUWS_hardpointTier getOrDefault ["MINEFIELD", 99]) > WARCOM_opfor_tier) exitWith { [] };
    private _drop = call DUWS_fnc_opcom_bandDrop;
    if (_drop isEqualTo []) exitWith { [] };
    _drop params ["_at", "_truck"];
    private _size = [1, 1];
    ["AT", "AP"] apply {
        [[_x, _size, _at, _truck select 0],
            ceil (OPCOM_AP_MINEFIELD * (_size select 0) * (_size select 1) + (_truck select 1)),
            format ["Lay %1 mines at %2", _x, mapGridPosition _at]]
    }
};

// The price rides in the errand, so a build that finds no ground refunds it in full, truck included.
DUWS_fnc_opcom_bandBuildRun = {
    params ["_target", "_price"];
    _target params ["_type", "_at", "_src"];
    [_src, _at, ["build", _at, _type, _price]] call DUWS_fnc_opcom_supplyRun
};

DUWS_opcom_actions = [
    ["bank", "bank", { [[[], 0, "Bank"]] }, { true }],
    ["zone_reinforce", "defensive", DUWS_fnc_opcom_zoneReinforceTargets, {
        params ["_zk"];
        ([_zk, "opcom_reinforce"] call fnc_zone_garrison_reinforce) >= 0
    }],
    ["zone_fortify", "defensive", DUWS_fnc_opcom_zoneFortifyTargets, {
        params ["_zk"];
        ([_zk, "opcom_fortify"] call fnc_zone_garrison_fortify) >= 0
    }],
    ["zone_build", "defensive", DUWS_fnc_opcom_zoneBuildTargets, {
        params ["_target", "_price"];
        _target params ["_zk", "_type"];
        [_type, _zk, [], _price] call DUWS_fnc_opcom_build
    }],
    ["town_reinforce", "defensive", DUWS_fnc_opcom_townReinforceTargets, {
        params ["_target"];
        _target params ["_i", "_src"];
        [_src, [_i] call DUWS_fnc_opcom_townPos, ["reinforce", _i]] call DUWS_fnc_opcom_supplyRun
    }],
    ["town_fortify", "defensive", DUWS_fnc_opcom_townFortifyTargets, {
        params ["_target"];
        _target params ["_i", "_src"];
        [_src, [_i] call DUWS_fnc_opcom_townPos, ["fortify", _i]] call DUWS_fnc_opcom_supplyRun
    }],
    ["rapport", "offensive", DUWS_fnc_opcom_rapportTargets, {
        params ["_target"];
        _target params ["_i", "_src"];
        [_src, [_i] call DUWS_fnc_opcom_townPos, ["rapport", _i]] call DUWS_fnc_opcom_supplyRun
    }],
    ["recruit_supply", "buildup", DUWS_fnc_opcom_recruitSupplyTargets, {
        params ["_zk"];
        private _t = ["truck", ([_zk] call fnc_site_at) get "pos", _zk, false] call fnc_opcom_recruit;
        !isNil "_t"
    }],
    ["band_build", "defensive", DUWS_fnc_opcom_bandBuildTargets, DUWS_fnc_opcom_bandBuildRun],
    ["tower_build", "buildup", { [["RADIO"]] call DUWS_fnc_opcom_assetTargets }, DUWS_fnc_opcom_bandBuildRun],
    ["op_build", "recon", { [["OP"]] call DUWS_fnc_opcom_assetTargets }, DUWS_fnc_opcom_bandBuildRun],
    ["gun_build", "indirect", { [["MORTAR", "ARTY"]] call DUWS_fnc_opcom_assetTargets }, DUWS_fnc_opcom_bandBuildRun],
    ["mine_build", "defensive", DUWS_fnc_opcom_mineBuildTargets, {
        params ["_target", "_price"];
        _target params ["_variant", "_size", "_at", "_src"];
        [_src, _at, ["mine", _at, [_variant, _size], _price]] call DUWS_fnc_opcom_supplyRun
    }]
];
