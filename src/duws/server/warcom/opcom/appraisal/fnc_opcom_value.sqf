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

// Whether a unit sent into contact wins it -- an attacking order's term, never a buy's: a garrison purchase stocks
// ground OPCOM already holds, and its site is gated on being uncontested anyway.
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

// What the holding fields at its own current tier. Measured against the top tier instead, a small zone's refill
// read as a few percent of a zone it will never be, and every buy scored a fraction of what it was worth.
DUWS_opcom_tierForceMemo = createHashMap;
DUWS_fnc_opcom_tierForce = {
    params ["_kind", "_tier"];
    private _key = format ["%1_%2", _kind, _tier];
    private _f = DUWS_opcom_tierForceMemo getOrDefault [_key, -1];
    if (_f < 0) then {
        private _list = if (_kind isEqualTo "zone") then {
            private _mult = (round (missionNamespace getVariable ["enemyunitMultiplier", 1])) max 1;
            [[_tier] call DUWS_fnc_zoneSpawnList, _mult] call DUWS_fnc_scaleComposition
        } else {
            [_tier] call DUWS_fnc_townSpawnList
        };
        _f = ([_list] call DUWS_fnc_tokenListForce) max 1;
        DUWS_opcom_tierForceMemo set [_key, _f];
    };
    _f
};

// Exposure arrives measured: a holding's is the same for every action on it, so the sweep reads it once.
DUWS_fnc_opcom_holdValue = {
    params ["_worth", "_exposure", "_force", "_kind", "_tier"];
    _worth * _exposure * ((_force / ([_kind, _tier] call DUWS_fnc_opcom_tierForce)) min 1)
};

// Sea counts on neither side of the share, so a coastal post is judged on the ground it can watch.
DUWS_fnc_opcom_opUnwatched = {
    params ["_c", "_ops"];
    private _w = DUWS_opcom_grid_w;
    private _cx = _c mod _w;
    private _cy = floor (_c / _w);
    private _others = _ops apply { [_x mod _w, floor (_x / _w)] };
    (missionNamespace getVariable ["DUWS_opcom_box", [0, 0, _w - 1, _w - 1]]) params ["_minCx", "_minCy", "_maxCx", "_maxCy"];
    private _land = 0;
    private _free = 0;
    for "_iy" from ((_cy - OP_OBSERVE_K) max _minCy) to ((_cy + OP_OBSERVE_K) min _maxCy) do {
        for "_ix" from ((_cx - OP_OBSERVE_K) max _minCx) to ((_cx + OP_OBSERVE_K) min _maxCx) do {
            if (DUWS_opcom_grid_land select (_iy * _w + _ix)) then {
                _land = _land + 1;
                if ((_others findIf { ((abs ((_x select 0) - _ix)) max (abs ((_x select 1) - _iy))) <= OP_OBSERVE_K }) < 0) then {
                    _free = _free + 1;
                };
            };
        };
    };
    if (_land == 0) exitWith { 0 };
    _free / _land
};

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

DUWS_fnc_opcom_opValue = {
    params ["_at"];
    OPCOM_AP_OP * ([[_at] call DUWS_fnc_opcom_w2c, (["OP"] call DUWS_fnc_opcom_assetsOf) apply { [_x] call DUWS_fnc_opcom_w2c }] call DUWS_fnc_opcom_opUnwatched)
};

// Not w2c: it clamps an off-box point onto an edge cell and would read that cell's land.
DUWS_fnc_opcom_landAt = {
    params ["_pos"];
    private _cx = floor ((_pos select 0) / OPCOM_GRID_CELL);
    private _cy = floor ((_pos select 1) / OPCOM_GRID_CELL);
    DUWS_opcom_box params ["_minCx", "_minCy", "_maxCx", "_maxCy"];
    _cx >= _minCx && {_cx <= _maxCx} && {_cy >= _minCy} && {_cy <= _maxCy} && {DUWS_opcom_grid_land select (_cy * DUWS_opcom_grid_w + _cx)}
};

// Sampled: every cell of a 20 km disc against the area of influence would overrun the pick's unscheduled pass.
DUWS_fnc_opcom_gunShare = {
    params ["_at", "_reach", "_others"];
    private _step = _reach / 5;
    private _n = 0;
    private _free = 0;
    for "_i" from -5 to 5 do {
        for "_j" from -5 to 5 do {
            if (_i * _i + _j * _j <= 25) then {
                _n = _n + 1;
                private _p = [(_at select 0) + _i * _step, (_at select 1) + _j * _step, 0];
                if ([_p] call DUWS_fnc_opcom_landAt
                    && {(_others findIf { (_x distance2D _p) <= _reach }) < 0}
                    && {[_p] call fnc_aoi_opfor_covers}) then { _free = _free + 1 };
            };
        };
    };
    _free / _n
};

// Own type only: a pit answers contact in seconds, a battery shells across the map, so neither does the other's job.
DUWS_fnc_opcom_gunValue = {
    params ["_type", "_at"];
    private _reach = [OPCOM_ARTY_REACH, OPCOM_MORTAR_REACH] select (_type isEqualTo "MORTAR");
    (DUWS_opcom_assetPrice get _type) * ([_at, _reach, [_type] call DUWS_fnc_opcom_assetsOf] call DUWS_fnc_opcom_gunShare)
};

DUWS_fnc_opcom_towerReach = {
    params ["_at", "_towns", "_others"];
    private _sum = 0;
    {
        _x params ["_pos", "_worth", "_covered"];
        if (!_covered && {(_pos distance2D _at) <= AOI_TOWER_REACH} && {(_others findIf { (_x distance2D _pos) <= AOI_TOWER_REACH }) < 0}) then {
            _sum = _sum + _worth;
        };
    } forEach _towns;
    _sum
};

DUWS_fnc_opcom_defendAt = {
    params ["_dist"];
    if (_dist <= OPCOM_DEFEND_NEAR) exitWith { 1 };
    if (_dist >= OPCOM_DEFEND_FAR) exitWith { OPCOM_DEFEND_FLOOR };
    1 - (1 - OPCOM_DEFEND_FLOOR) * (_dist - OPCOM_DEFEND_NEAR) / (OPCOM_DEFEND_FAR - OPCOM_DEFEND_NEAR)
};

// Standing defenses only: a tasking drives away tomorrow.
DUWS_fnc_opcom_defend = {
    params ["_pos"];
    private _near = OPCOM_DEFEND_FAR;
    {
        _x params ["", "_zp", "_zs"];
        if !([[_zp] call fnc_zone_key] call fnc_zone_bluforHeld) then { _near = _near min (((_pos distance2D _zp) - _zs) max 0) };
    } forEach zone_meta_array;
    { if ((_x select 3) isEqualTo "opfor") then { _near = _near min (_pos distance2D (_x select 1)) } } forEach DUWS_hardpoints;
    [_near] call DUWS_fnc_opcom_defendAt
};

// The amplifier every tower adds stays out: it reads the same at every site, so it ranks nothing.
DUWS_fnc_opcom_towerValue = {
    params ["_at"];
    private _towns = [];
    {
        private _pos = [_forEachIndex] call DUWS_fnc_opcom_townPos;
        _towns pushBack [_pos, [_forEachIndex] call DUWS_fnc_opcom_townWorth, [_pos] call fnc_aoi_opfor_covers];
    } forEach (missionNamespace getVariable ["civ_town_rep", []]);
    ([_at, _towns, ["RADIO"] call DUWS_fnc_opcom_assetsOf] call DUWS_fnc_opcom_towerReach) * ([_at] call DUWS_fnc_opcom_defend)
};

// Skewed to a neutral town: one near -10 turns anyway on the free drift, and a step barely moves one near +10.
DUWS_fnc_opcom_rapportValue = {
    params ["_worth", "_rep"];
    _worth * ((1 - (abs _rep) / 10) max 0.1) * OPCOM_RAPPORT_STEP / 10
};

// Straight-line, not the route: planning a route per candidate would not fit the pick's unscheduled pass.
DUWS_fnc_opcom_delay = {
    params ["_dist", "_ticksPerCell"];
    0.5 ^ ((_dist / OPCOM_GRID_CELL) * _ticksPerCell / OPCOM_VALUE_HALFLIFE)
};
