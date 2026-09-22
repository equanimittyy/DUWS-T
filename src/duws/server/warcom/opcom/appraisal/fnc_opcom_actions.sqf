// Locality: server, [] call'd at load. The action list the pick stage (fnc_opcom_pick) draws from.
// DUWS_opcom_actions row: [id, class, targets, execute, arg].
//   arg call targets -> [[target, price, label, value, pWin], ...], the action's legal targets now. `arg` is the
//     row's fixed argument, the hardpoint type or mine variant for a build row and [] elsewhere. Runs inside isNil,
//     so it never suspends. `value` is the AP the target returns; omitting it scores the action break-even until its
//     category is appraised. `pWin` is the odds a unit sent into contact wins it, so only an order that fights for
//     its target carries one -- a buy stocks ground OPCOM already holds and leaves it out.
//   [target, price] call execute -> true when the action landed; the pick charges the price only then.
if (!isServer) exitWith {};

DUWS_opcom_aiMode = "off";
DUWS_opcom_pickOnce = "";
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

// Cached for the tick: every row asks for the same sweeps and the same band sample, and the store cannot move under
// them -- the pick reads in one unscheduled pass and executes afterwards.
DUWS_opcom_tickCache = createHashMap;
DUWS_fnc_opcom_tickCached = {
    params ["_key", "_fn"];
    private _row = DUWS_opcom_tickCache getOrDefault [_key, []];
    if ((_row param [0, -1]) isEqualTo DUWS_opcom_tick) exitWith { _row select 1 };
    private _v = call _fn;
    DUWS_opcom_tickCache set [_key, [DUWS_opcom_tick, _v]];
    _v
};

DUWS_fnc_opcom_zonesOpenSweep = {
    private _out = [];
    {
        _x params ["", "_zp", "_zs"];
        private _zk = [_zp] call fnc_zone_key;
        if (!([_zk] call fnc_zone_bluforHeld) && {!([_zk] call DUWS_fnc_opcom_siteContested)}) then {
            _out pushBack [_zk, _zs, _zp, _x select 3, [_zp] call DUWS_fnc_opcom_exposure, [_zk] call fnc_zone_tier];
        };
    } forEach zone_meta_array;
    _out
};

DUWS_fnc_opcom_zonesOpen = { ["zonesOpen", DUWS_fnc_opcom_zonesOpenSweep] call DUWS_fnc_opcom_tickCached };

// The force the step restores, 0 with nothing to buy. Drives the step's gain only -- it costs OPCOM_AP_REINFORCE
// whatever it buys back. The step takes random unlocked lost tokens, so it reads their average.
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
        _x params ["_zk", "", "", "_worth", "_exp", "_tier"];
        private _force = [_zk] call DUWS_fnc_opcom_reinforceForce;
        if (_force > 0) then {
            _out pushBack [_zk, OPCOM_AP_REINFORCE, format ["Reinforce %1", [_zk] call DUWS_fnc_opcom_zoneLabel],
                [_worth, _exp, _force, "zone", _tier] call DUWS_fnc_opcom_holdValue];
        };
    } forEach (call DUWS_fnc_opcom_zonesOpen);
    _out
};

DUWS_fnc_opcom_zoneFortifyTargets = {
    private _top = count DUWS_zoneSpawnTiers;
    private _mult = (round (missionNamespace getVariable ["enemyunitMultiplier", 1])) max 1;
    private _out = [];
    {
        _x params ["_zk", "", "", "_worth", "_exp", "_tier"];
        if (_tier < _top) then {
            private _owed = [
                [[_tier] call DUWS_fnc_zoneSpawnList, _mult] call DUWS_fnc_scaleComposition,
                [[_tier + 1] call DUWS_fnc_zoneSpawnList, _mult] call DUWS_fnc_scaleComposition
            ] call DUWS_fnc_spawnDiff;
            private _force = [_owed select { !([_x] call DUWS_fnc_tokenLocked) }] call DUWS_fnc_tokenListForce;
            _out pushBack [_zk, OPCOM_AP_FORTIFY,
                format ["Fortify %1 to tier %2", [_zk] call DUWS_fnc_opcom_zoneLabel, _tier + 1],
                [_worth, _exp, _force, "zone", _tier] call DUWS_fnc_opcom_holdValue];
        };
    } forEach (call DUWS_fnc_opcom_zonesOpen);
    _out
};

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

DUWS_fnc_opcom_townLabel = {
    params ["_i"];
    text ((missionNamespace getVariable ["civ_locations", []]) select _i)
};

DUWS_fnc_opcom_townPos = {
    params ["_i"];
    ([[_i] call fnc_town_site_key] call fnc_site_at) getOrDefault ["pos", []]
};

// -> [[source, pos, cost], ...]: an idle truck at 0, an open zone's hire at the hire price.
DUWS_fnc_opcom_truckSourcesSweep = {
    private _out = [];
    {
        if ("supply" in (_x get "flags") && {DUWS_opcom_tick >= (_x get "hold")} && {[_x] call DUWS_fnc_opcom_drawable}) then {
            _out pushBack [["truck", _x get "id"], _x get "pos", 0];
        };
    } forEach DUWS_opcom_taskings;
    private _comp = (DUWS_opcom_recruitMenu get "truck") select 0;
    private _hire = OPCOM_AP_UNIT getOrDefault ["truck", 0];
    // A zero price is an unpriced row, not a free truck; an empty class is a faction that cannot field one yet.
    if (_hire > 0 && {([_comp select 0, "OPF"] call DUWS_fnc_tokenClass) isNotEqualTo ""}) then {
        {
            _x params ["_zk"];
            _out pushBack [["hire", _zk], ([_zk] call fnc_site_at) get "pos", _hire];
        } forEach (call DUWS_fnc_opcom_zonesOpen);
    };
    _out
};

DUWS_fnc_opcom_truckSources = { ["truckSources", DUWS_fnc_opcom_truckSourcesSweep] call DUWS_fnc_opcom_tickCached };

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
        private _tier = _x;
        if (_tier < 1 || {_i in _busy} || {[[_i] call fnc_town_site_key] call DUWS_fnc_opcom_siteContested}) then { continue };
        private _force = [[_i] call DUWS_fnc_townStrengthKey] call DUWS_fnc_opcom_reinforceForce;
        if (_force <= 0) then { continue };
        private _pos = [_i] call DUWS_fnc_opcom_townPos;
        private _truck = [_sources, _pos] call DUWS_fnc_opcom_truckFor;
        if (_truck isEqualTo []) then { continue };
        _out pushBack [[_i, _truck select 0], ceil (OPCOM_AP_REINFORCE + (_truck select 1)),
            format ["Reinforce %1", [_i] call DUWS_fnc_opcom_townLabel],
            [[_i] call DUWS_fnc_opcom_townWorth, [_pos] call DUWS_fnc_opcom_exposure, _force, "town", _tier] call DUWS_fnc_opcom_holdValue];
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
        if (_tier < 1 || {_tier >= _top} || {_i in _busy} || {[[_i] call fnc_town_site_key] call DUWS_fnc_opcom_siteContested}) then { continue };
        private _pos = [_i] call DUWS_fnc_opcom_townPos;
        private _truck = [_sources, _pos] call DUWS_fnc_opcom_truckFor;
        if (_truck isEqualTo []) then { continue };
        private _owed = [[_tier] call DUWS_fnc_townSpawnList, [_tier + 1] call DUWS_fnc_townSpawnList] call DUWS_fnc_spawnDiff;
        private _force = [_owed select { !([_x] call DUWS_fnc_tokenLocked) }] call DUWS_fnc_tokenListForce;
        _out pushBack [[_i, _truck select 0], ceil (OPCOM_AP_FORTIFY + (_truck select 1)),
            format ["Fortify %1 to tier %2", [_i] call DUWS_fnc_opcom_townLabel, _tier + 1],
            [[_i] call DUWS_fnc_opcom_townWorth, [_pos] call DUWS_fnc_opcom_exposure, _force, "town", _tier] call DUWS_fnc_opcom_holdValue];
    } forEach (missionNamespace getVariable ["DUWS_townGarrisonTier", []]);
    _out
};

DUWS_fnc_opcom_rapportTargets = {
    private _sources = call DUWS_fnc_opcom_truckSources;
    private _busy = call DUWS_fnc_opcom_townsSupplied;
    private _out = [];
    {
        private _i = _forEachIndex;
        if (_x <= -15 || {_x >= 10} || {_i in _busy} || {[[_i] call fnc_town_site_key] call DUWS_fnc_opcom_siteContested}) then { continue };
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
    // Worth 0 until land-taxi gives a truck transport demand (4B.3): every supply action hires its own when none idles.
    [[_zk, _price, format ["Recruit a truck at %1", [_zk] call DUWS_fnc_opcom_zoneLabel], 0]]
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
DUWS_fnc_opcom_bandDropDraw = {
    private _band = call DUWS_fnc_aoi_bandPos;
    if (_band isEqualTo []) exitWith { [] };
    // findSafePos answers a 2D point; tasking positions are 3D throughout.
    private _at = +(_band select 0);
    _at set [2, 0];
    private _truck = [call DUWS_fnc_opcom_truckSources, _at] call DUWS_fnc_opcom_truckFor;
    if (_truck isEqualTo []) exitWith { [] };
    [_at, _truck]
};

DUWS_fnc_opcom_bandDrop = { ["bandDrop", DUWS_fnc_opcom_bandDropDraw] call DUWS_fnc_opcom_tickCached };

DUWS_fnc_opcom_standaloneBuildTargets = {
    params ["_type"];
    if ((DUWS_hardpointTier getOrDefault [_type, 99]) > WARCOM_opfor_tier) exitWith { [] };
    private _drop = call DUWS_fnc_opcom_bandDrop;
    if (_drop isEqualTo []) exitWith { [] };
    _drop params ["_at", "_truck"];
    [[[_type, _at, _truck select 0], ceil (([_type] call DUWS_fnc_opcom_hpPrice) + (_truck select 1)),
        format ["Build %1 at %2", DUWS_hardpointName getOrDefault [_type, _type], mapGridPosition _at]]]
};

DUWS_fnc_opcom_assetTargets = {
    params ["_type"];
    if ((DUWS_hardpointTier getOrDefault [_type, 99]) > WARCOM_opfor_tier
        || {([_type] call DUWS_fnc_opcom_hpCount) >= (DUWS_opcom_assetCap getOrDefault [_type, 1e9])}) exitWith { [] };
    private _drop = call DUWS_fnc_opcom_bandDrop;
    if (_drop isEqualTo []) exitWith { [] };
    _drop params ["_at", "_truck"];
    [[[_type, _at, _truck select 0], ceil ((DUWS_opcom_assetPrice get _type) + (_truck select 1)),
        format ["Build %1 at %2", DUWS_hardpointName getOrDefault [_type, _type], mapGridPosition _at]]]
};

// One 50 m square for now; the size rides the target, so a deeper belt is a wider candidate, not a new action.
DUWS_fnc_opcom_mineBuildTargets = {
    params ["_variant"];
    if ((DUWS_hardpointTier getOrDefault ["MINEFIELD", 99]) > WARCOM_opfor_tier) exitWith { [] };
    private _drop = call DUWS_fnc_opcom_bandDrop;
    if (_drop isEqualTo []) exitWith { [] };
    _drop params ["_at", "_truck"];
    private _size = [1, 1];
    [[[_variant, _size, _at, _truck select 0],
        ceil (OPCOM_AP_MINEFIELD * (_size select 0) * (_size select 1) + (_truck select 1)),
        format ["Lay %1 mines at %2", _variant, mapGridPosition _at]]]
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

DUWS_opcom_actions = [
    // Priced at nothing, so its Value doubles as its score: the bar every other action has to clear to be worth buying.
    ["bank", "bank", { [[[], 0, "Bank", OPCOM_BANK_SCORE]] }, { true }],
    ["zone_reinforce", "defensive", DUWS_fnc_opcom_zoneReinforceTargets, {
        params ["_zk"];
        ([_zk, "opcom_reinforce"] call fnc_zone_garrison_reinforce) >= 0
    }],
    ["zone_fortify", "defensive", DUWS_fnc_opcom_zoneFortifyTargets, {
        params ["_zk"];
        ([_zk, "opcom_fortify"] call fnc_zone_garrison_fortify) >= 0
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
    }]
];

// One row per type, never one row offering several: the pick draws an action, so a shared row would decide the type
// for it and leave the archetype nothing to lean on (4C.1).
{
    DUWS_opcom_actions pushBack [format ["zone_build_%1", toLower _x], "defensive",
        DUWS_fnc_opcom_zoneBuildTargets, DUWS_fnc_opcom_zoneBuildRun, [_x]];
} forEach (keys DUWS_hardpointWeightZone);
{
    DUWS_opcom_actions pushBack [format ["standalone_build_%1", toLower _x], "defensive",
        DUWS_fnc_opcom_standaloneBuildTargets, DUWS_fnc_opcom_standaloneBuildRun, [_x]];
} forEach (keys DUWS_hardpointWeightSolo);
{
    _x params ["_type", "_class"];
    DUWS_opcom_actions pushBack [format ["%1_build", toLower _type], _class,
        DUWS_fnc_opcom_assetTargets, DUWS_fnc_opcom_standaloneBuildRun, [_type]];
} forEach [["RADIO", "buildup"], ["OP", "recon"], ["MORTAR", "indirect"], ["ARTY", "indirect"]];
{
    DUWS_opcom_actions pushBack [format ["mine_build_%1", toLower _x], "defensive",
        DUWS_fnc_opcom_mineBuildTargets, DUWS_fnc_opcom_mineBuildRun, [_x]];
} forEach ["AT", "AP"];
