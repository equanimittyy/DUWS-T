// Locality: server, [] call'd at load to define the appraisal helpers -- the terms of the picker's score
// (opcom_plan.md §Appraisal). Value is Army Power, the same unit as the price, so Value / Cost is a plain ratio and
// a zone buy compares against a hardpoint. Read from the pick's unscheduled pass, so nothing here may suspend.
if (!isServer) exitWith {};

// The HQ counts only once revealed, so an unfound base pulls no defense toward itself.
DUWS_fnc_opcom_bluforGroundSweep = {
    private _out = +(missionNamespace getVariable ["WARCOM_zones_controled_by_BLUFOR", []]);
    _out append (missionNamespace getVariable ["Array_of_FOBpos", []]);
    if (missionNamespace getVariable ["DUWS_opcom_hqKnown", false] && {!isNil "PosOfBLUHQ"} && {PosOfBLUHQ isNotEqualTo []}) then {
        _out pushBack PosOfBLUHQ;
    };
    _out
};

DUWS_fnc_opcom_bluforGround = { ["bluforGround", DUWS_fnc_opcom_bluforGroundSweep] call DUWS_fnc_opcom_tickCached };

DUWS_fnc_opcom_exposureAt = {
    params ["_dist"];
    if (_dist <= OPCOM_EXPOSE_NEAR) exitWith { 1 };
    if (_dist >= OPCOM_EXPOSE_FAR) exitWith { OPCOM_EXPOSE_FLOOR };
    1 - (1 - OPCOM_EXPOSE_FLOOR) * (_dist - OPCOM_EXPOSE_NEAR) / (OPCOM_EXPOSE_FAR - OPCOM_EXPOSE_NEAR)
};

DUWS_fnc_opcom_exposure = {
    params ["_pos"];
    private _ground = call DUWS_fnc_opcom_bluforGround;
    if (_ground isEqualTo []) exitWith { OPCOM_EXPOSE_FLOOR };
    private _near = OPCOM_EXPOSE_FAR;
    { _near = _near min (_pos distance2D _x) } forEach _ground;
    [_near] call DUWS_fnc_opcom_exposureAt
};

DUWS_fnc_opcom_blockForce = {
    params ["_pos"];
    private _w = DUWS_opcom_grid_w;
    private _c = [_pos] call DUWS_fnc_opcom_w2c;
    private _cx = _c mod _w;
    private _cy = floor (_c / _w);
    (missionNamespace getVariable ["DUWS_opcom_box", [0, 0, _w - 1, _w - 1]]) params ["_minCx", "_minCy", "_maxCx", "_maxCy"];
    private _fri = 0;
    private _ene = 0;
    for "_iy" from ((_cy - 1) max _minCy) to ((_cy + 1) min _maxCy) do {
        for "_ix" from ((_cx - 1) max _minCx) to ((_cx + 1) min _maxCx) do {
            private _i = _iy * _w + _ix;
            _fri = _fri + (DUWS_opcom_grid_fri select _i);
            _ene = _ene + (DUWS_opcom_grid_ene select _i);
        };
    };
    [_fri, _ene]
};

// Lanchester-square: parity is a coin flip, a 2:1 edge about 0.8. The +1 keeps unopposed ground off a divide by zero.
DUWS_fnc_opcom_pWinAt = {
    params ["_fri", "_ene"];
    private _r = _fri / (_ene + 1);
    (_r ^ 2) / ((_r ^ 2) + 1)
};

DUWS_fnc_opcom_pWin = {
    params ["_pos"];
    if (isNil "DUWS_opcom_grid_w") exitWith { 1 };
    ([_pos] call DUWS_fnc_opcom_blockForce) call DUWS_fnc_opcom_pWinAt
};

DUWS_fnc_opcom_townWorth = {
    params ["_i"];
    ((missionNamespace getVariable ["civ_town_ap", []]) param [_i, 0]) * OPCOM_TOWN_WORTH
};

// The denominator that turns a partial buy into the share of the whole.
DUWS_opcom_fullForceMemo = createHashMap;
DUWS_fnc_opcom_fullForce = {
    params ["_kind"];
    private _f = DUWS_opcom_fullForceMemo getOrDefault [_kind, -1];
    if (_f < 0) then {
        private _list = if (_kind isEqualTo "zone") then {
            private _mult = (round (missionNamespace getVariable ["enemyunitMultiplier", 1])) max 1;
            [[count DUWS_zoneSpawnTiers] call DUWS_fnc_zoneSpawnList, _mult] call DUWS_fnc_scaleComposition
        } else {
            [count DUWS_townSpawnTiers] call DUWS_fnc_townSpawnList
        };
        _f = ([_list] call DUWS_fnc_tokenListForce) max 1;
        DUWS_opcom_fullForceMemo set [_kind, _f];
    };
    _f
};

// Exposure arrives measured: a holding's is the same for every action on it, so the sweep reads it once.
DUWS_fnc_opcom_holdValue = {
    params ["_worth", "_exposure", "_force", "_kind"];
    _worth * _exposure * ((_force / ([_kind] call DUWS_fnc_opcom_fullForce)) min 1)
};
