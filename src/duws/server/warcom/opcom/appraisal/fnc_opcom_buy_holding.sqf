// Locality: server, [] call'd at load. The holding buys: reinforce and fortify a zone in place, or truck a reinforce,
// a fortify or a Rapport run out to a town.
if (!isServer) exitWith {};

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

// What the next tier fields over this one, locked tokens included. Kept per kind and tier for the session: the spawn
// filter behind it reads only the faction pools and the asset toggles, fixed before the first pick. The lock check
// moves as AP is earned, so callers apply it.
DUWS_opcom_owedMemo = createHashMap;

DUWS_fnc_opcom_tierOwed = {
    params ["_kind", "_tier"];
    private _key = format ["%1_%2", _kind, _tier];
    private _owed = DUWS_opcom_owedMemo get _key;
    if (isNil "_owed") then {
        _owed = if (_kind isEqualTo "zone") then {
            private _mult = (round (missionNamespace getVariable ["enemyunitMultiplier", 1])) max 1;
            [
                [[_tier] call DUWS_fnc_zoneSpawnList, _mult] call DUWS_fnc_scaleComposition,
                [[_tier + 1] call DUWS_fnc_zoneSpawnList, _mult] call DUWS_fnc_scaleComposition
            ] call DUWS_fnc_spawnDiff
        } else {
            [[_tier] call DUWS_fnc_townSpawnList, [_tier + 1] call DUWS_fnc_townSpawnList] call DUWS_fnc_spawnDiff
        };
        DUWS_opcom_owedMemo set [_key, _owed];
    };
    _owed
};

DUWS_fnc_opcom_zoneFortifyTargets = {
    private _top = count DUWS_zoneSpawnTiers;
    private _out = [];
    {
        _x params ["_zk", "", "", "_worth", "_exp", "_tier"];
        if (_tier < _top) then {
            private _owed = ["zone", _tier] call DUWS_fnc_opcom_tierOwed;
            private _force = [_owed select { !([_x] call DUWS_fnc_tokenLocked) }] call DUWS_fnc_tokenListForce;
            _out pushBack [_zk, OPCOM_AP_FORTIFY,
                format ["Fortify %1 to tier %2", [_zk] call DUWS_fnc_opcom_zoneLabel, _tier + 1],
                [_worth, _exp, _force, "zone", _tier] call DUWS_fnc_opcom_holdValue];
        };
    } forEach (call DUWS_fnc_opcom_zonesOpen);
    _out
};

DUWS_fnc_opcom_zoneReinforceRun = {
    params ["_zk"];
    ([_zk, "opcom_reinforce"] call fnc_zone_garrison_reinforce) >= 0
};

DUWS_fnc_opcom_zoneFortifyRun = {
    params ["_zk"];
    ([_zk, "opcom_fortify"] call fnc_zone_garrison_fortify) >= 0
};

// Each town offer reads [town, its entry in the row's list, its position] and answers [base price, label, Value], or []
// for a town it passes over. Not the player's towns for a garrison buy: a tier is the owner's, and the commander buys
// only for its own ground.
DUWS_fnc_opcom_townReinforceOffer = {
    params ["_i", "_tier", "_pos"];
    if (_tier < 1 || {([_i] call fnc_town_garrison_ownerAt) isEqualTo "BLU"}) exitWith { [] };
    private _force = [[_i] call DUWS_fnc_townStrengthKey] call DUWS_fnc_opcom_reinforceForce;
    if (_force <= 0) exitWith { [] };
    [OPCOM_AP_REINFORCE, format ["Reinforce %1", [_i] call DUWS_fnc_opcom_townLabel],
        [[_i] call DUWS_fnc_opcom_townWorth, [_pos] call DUWS_fnc_opcom_exposure, _force, "town", _tier] call DUWS_fnc_opcom_holdValue]
};

DUWS_fnc_opcom_townFortifyOffer = {
    params ["_i", "_tier", "_pos"];
    if (_tier < 1 || {_tier >= count DUWS_townSpawnTiers} || {([_i] call fnc_town_garrison_ownerAt) isEqualTo "BLU"}) exitWith { [] };
    private _owed = ["town", _tier] call DUWS_fnc_opcom_tierOwed;
    private _force = [_owed select { !([_x] call DUWS_fnc_tokenLocked) }] call DUWS_fnc_tokenListForce;
    [OPCOM_AP_FORTIFY, format ["Fortify %1 to tier %2", [_i] call DUWS_fnc_opcom_townLabel, _tier + 1],
        [[_i] call DUWS_fnc_opcom_townWorth, [_pos] call DUWS_fnc_opcom_exposure, _force, "town", _tier] call DUWS_fnc_opcom_holdValue]
};

DUWS_fnc_opcom_rapportOffer = {
    params ["_i", "_rep", "_pos"];
    if (_rep <= -15 || {_rep >= 10} || {!([_pos] call fnc_aoi_opfor_covers)}) exitWith { [] };
    [OPCOM_AP_RAPPORT, format ["Rapport at %1", [_i] call DUWS_fnc_opcom_townLabel],
        [[_i] call DUWS_fnc_opcom_townWorth, _rep] call DUWS_fnc_opcom_rapportValue]
};

// -> [[[errand, town, truck source], price, label, Value, 1, Cost], ...].
DUWS_fnc_opcom_townTargets = {
    params ["_errand", "_listVar", "_offer"];
    if (call DUWS_fnc_opcom_supplyFull || {_errand isEqualTo "rapport" && {call DUWS_fnc_opcom_rapportFull || {DUWS_opcom_tick < DUWS_opcom_rapportReadyTick}}}) exitWith { [] };
    private _busy = call DUWS_fnc_opcom_townsSupplied;
    private _out = [];
    {
        private _i = _forEachIndex;
        if !(_i in _busy || {[[_i] call fnc_town_site_key] call DUWS_fnc_opcom_siteContested}) then {
            private _pos = [_i] call DUWS_fnc_opcom_townPos;
            private _o = [_i, _x, _pos] call _offer;
            if !(_o isEqualTo []) then {
                _o params ["_base", "_label", "_v"];
                {
                    _x params ["_src", "_price", "_tv", "_c"];
                    _out pushBack [[_errand, _i, _src], _price, _label, _tv, 1, _c];
                } forEach ([_pos, _v, _base] call DUWS_fnc_opcom_truckOffers);
            };
        };
    } forEach (missionNamespace getVariable [_listVar, []]);
    _out
};

DUWS_fnc_opcom_townRun = {
    params ["_target"];
    _target params ["_errand", "_i", "_src"];
    [_src, [_i] call DUWS_fnc_opcom_townPos, [_errand, _i]] call DUWS_fnc_opcom_supplyRun
};
