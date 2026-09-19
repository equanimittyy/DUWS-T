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

// The step buys back random unlocked lost tokens, so it is priced at their average force.
DUWS_fnc_opcom_zoneReinforceTargets = {
    private _out = [];
    {
        _x params ["_zk"];
        private _lost = ([_zk] call DUWS_fnc_garrisonLost) select { !([_x] call DUWS_fnc_tokenLocked) };
        private _n = ([_zk] call DUWS_fnc_garrisonReinforceCount) min count _lost;
        if (_n > 0 && {([_zk] call DUWS_fnc_garrisonStrength) < 1}) then {
            private _price = ceil (_n * ([_lost] call DUWS_fnc_tokenListForce) / (count _lost) * OPCOM_AP_PER_FORCE);
            _out pushBack [_zk, _price, format ["Reinforce %1", [_zk] call DUWS_fnc_opcom_zoneLabel]];
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

DUWS_opcom_actions = [
    ["bank", "bank", { [[[], 0, "Bank"]] }, { true }],
    ["zone_reinforce", "defensive", DUWS_fnc_opcom_zoneReinforceTargets, {
        params ["_zk"];
        ([_zk, "opcom_reinforce"] call fnc_zone_garrison_reinforce) >= 0
    }],
    ["zone_fortify", "defensive", DUWS_fnc_opcom_zoneFortifyTargets, {
        params ["_zk"];
        ([_zk, "opcom_fortify"] call fnc_zone_garrison_fortify) >= 0
    }]
];
