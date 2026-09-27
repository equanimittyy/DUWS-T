// Locality: server, executed at load by server_fnc_init ([] call compile) so it can define several functions. The force
// grid's sources, its deposit, and the dirty marks that holding writers call. The marks load ahead of every writer and do
// nothing until OPCOM init builds the grid, whose first tick is a dirty-all.
if (!isServer) exitWith {};

// A negative weight takes back an earlier deposit of the same source. Out-of-box cells are never touched: the box
// buffer exceeds every source's reach, so they stay 0.
DUWS_fnc_opcom_deposit = {
    params ["_layer", "_pos", "_weight", "_reach"];
    if (_weight == 0) exitWith {};
    private _cell = OPCOM_GRID_CELL;
    private _w = DUWS_opcom_grid_w;
    DUWS_opcom_box params ["_bMinCx", "_bMinCy", "_bMaxCx", "_bMaxCy"];
    private _scx = (floor ((_pos select 0) / _cell)) min (_w - 1) max 0;
    private _scy = (floor ((_pos select 1) / _cell)) min (_w - 1) max 0;
    private _k = ceil (_reach / _cell);
    for "_cy" from (_scy - _k) max _bMinCy to (_scy + _k) min _bMaxCy do {
        for "_cx" from (_scx - _k) max _bMinCx to (_scx + _k) min _bMaxCx do {
            private _d = _pos distance2D [(_cx + 0.5) * _cell, (_cy + 0.5) * _cell];
            if (_d <= _reach) then {
                private _ci = _cy * _w + _cx;
                _layer set [_ci, (_layer select _ci) + _weight * (1 - _d / _reach)];
            };
        };
    };
};

DUWS_fnc_opcom_gridZeroBox = {
    params ["_layer"];
    private _w = DUWS_opcom_grid_w;
    DUWS_opcom_box params ["_bMinCx", "_bMinCy", "_bMaxCx", "_bMaxCy"];
    for "_cy" from _bMinCy to _bMaxCy do {
        for "_cx" from _bMinCx to _bMaxCx do { _layer set [_cy * _w + _cx, 0] };
    };
    _layer
};

// A writer marks after its write, never before: the grid stage swaps the set out before it reads any holding, so a
// mark that follows the write is always processed on a tick that sees the write.
DUWS_fnc_opcom_gridDirty = {
    params ["_key"];
    if (isNil "DUWS_opcom_gridDirty") exitWith {};
    DUWS_opcom_gridDirty set [_key, true];
};

DUWS_fnc_opcom_gridDirtyAll = { DUWS_opcom_gridDirtyAll = true };

// Each source -> [key, static, layer, pos, weight, reach], or [] where it deposits nothing. Static means only a write
// that marks the key can change its weight.
DUWS_fnc_opcom_gridZone = {
    params ["_zp", "_zs"];
    private _key = [_zp] call fnc_zone_key;
    private _reach = _zs + OPCOM_GRID_SPREAD;
    // Known enemy ground, a territorial fact the commander has for free, read at the true force of whatever the
    // player built on it. The nominal is the floor, for ground holding no garrison.
    if ((WARCOM_zones_controled_by_BLUFOR findIf {(_x distance2D _zp) < 1}) >= 0) exitWith {
        [_key, !([_key] call DUWS_fnc_garrisonHeld), "ene", _zp,
            ([_key] call DUWS_fnc_garrisonForce) max OPCOM_GRID_ZONE_ENEMY_FORCE, _reach]
    };
    // Live men and a deployed centre's statics die between ticks with no ledger write.
    [_key, !([_key] call DUWS_fnc_garrisonHeld) && {_key in DUWS_stowed}, "fri", _zp, [_key] call DUWS_fnc_garrisonForce, _reach]
};

DUWS_fnc_opcom_gridTown = {
    params ["_i"];
    // A neutral town fields no garrison, so it deposits nothing.
    if (((missionNamespace getVariable ["DUWS_townGarrisonTier", []]) param [_i, 0]) < 1) exitWith { [] };
    private _key = [_i] call fnc_town_site_key;
    private _pos = getPos ((missionNamespace getVariable ["civ_locations", []]) select _i);
    private _reach = ((missionNamespace getVariable ["civ_radii", []]) param [_i, 500]) + OPCOM_GRID_SPREAD;
    // A BLUFOR town garrison is enemy ground on the same terms a BLU-held zone is, read at its true force.
    if (([_i] call fnc_town_garrison_ownerAt) isEqualTo "BLU") exitWith {
        [_key, !([_key] call DUWS_fnc_garrisonHeld), "ene", _pos,
            ([_key] call DUWS_fnc_garrisonForce) max OPCOM_GRID_ZONE_ENEMY_FORCE, _reach]
    };
    [_key, !([_key] call DUWS_fnc_garrisonHeld), "fri", _pos, [_key] call DUWS_fnc_garrisonForce, _reach]
};

// Priced off the type's layout, so a row weighs the same deployed or stowed; it stands until cleared.
DUWS_fnc_opcom_gridHp = {
    params ["_row"];
    _row params ["_key", "_pos", "_type", "_side"];
    if (_side isNotEqualTo "opfor") exitWith { [] };
    [_key, true, "fri", _pos, [_type] call DUWS_fnc_hpForce, OPCOM_GRID_SPREAD]
};

DUWS_fnc_opcom_gridSources = {
    private _out = zone_meta_array apply { [_x select 1, _x select 2] call DUWS_fnc_opcom_gridZone };
    { _out pushBack ([_forEachIndex] call DUWS_fnc_opcom_gridTown) } forEach (missionNamespace getVariable ["DUWS_townGarrisonTier", []]);
    { _out pushBack ([_x] call DUWS_fnc_opcom_gridHp) } forEach DUWS_hardpoints;
    _out select { _x isNotEqualTo [] }
};

// Found by scanning its kind's list, so the cost follows the marks, not a per-tick pass over the map.
DUWS_fnc_opcom_gridSourceOf = {
    params ["_key"];
    if ((_key select [0, 5]) isEqualTo "zone_") exitWith {
        private _i = zone_meta_array findIf { ([_x select 1] call fnc_zone_key) isEqualTo _key };
        if (_i < 0) then { [] } else { [(zone_meta_array select _i) select 1, (zone_meta_array select _i) select 2] call DUWS_fnc_opcom_gridZone }
    };
    if ((_key select [0, 5]) isEqualTo "town_") exitWith {
        private _i = -1;
        for "_t" from 0 to (count (missionNamespace getVariable ["DUWS_townGarrisonTier", []]) - 1) do {
            if (([_t] call fnc_town_site_key) isEqualTo _key) exitWith { _i = _t };
        };
        if (_i < 0) then { [] } else { [_i] call DUWS_fnc_opcom_gridTown }
    };
    private _i = DUWS_hardpoints findIf { (_x select 0) isEqualTo _key };
    if (_i < 0) then { [] } else { [DUWS_hardpoints select _i] call DUWS_fnc_opcom_gridHp }
};

// Belief and taskings change every tick, so they are never cached.
DUWS_fnc_opcom_gridMobile = {
    params ["_fri", "_ene"];
    // An expired stamp is already gone from the arrays.
    {
        private _age = DUWS_opcom_tick - (DUWS_opcom_belief_time select _forEachIndex);
        private _decay = ((OPCOM_BELIEF_EXPIRE - _age) / (OPCOM_BELIEF_EXPIRE - OPCOM_BELIEF_FRESH)) max 0 min 1;
        [_ene, _x, (DUWS_opcom_belief_str select _forEachIndex) * _decay, OPCOM_GRID_SPREAD] call DUWS_fnc_opcom_deposit;
    } forEach DUWS_opcom_belief_pos;
    // A tasking's group is in no holdings scan, so this is where its force enters the grid at all -- except a standing
    // defender, which its zone's live garrison force already holds.
    {
        private _ef = _x get "effForce";
        if (_ef > 0 && {!([_x] call DUWS_fnc_opcom_defenderStanding)}) then { [_fri, _x get "pos", _ef, OPCOM_GRID_SPREAD] call DUWS_fnc_opcom_deposit };
    } forEach (missionNamespace getVariable ["DUWS_opcom_taskings", []]);
};

// Every source from scratch, cache bypassed. Run by the grid stage right after it publishes: the task step moves
// taskings after the stage, so a check run anywhere else reads them where the published grid did not.
DUWS_fnc_opcom_gridDrift = {
    params ["_caller"];
    private _fri = [+DUWS_opcom_grid_fri] call DUWS_fnc_opcom_gridZeroBox;
    private _ene = [+DUWS_opcom_grid_ene] call DUWS_fnc_opcom_gridZeroBox;
    {
        _x params ["", "", "_layer", "_pos", "_weight", "_reach"];
        [[_fri, _ene] select (_layer isEqualTo "ene"), _pos, _weight, _reach] call DUWS_fnc_opcom_deposit;
    } forEach (call DUWS_fnc_opcom_gridSources);
    [_fri, _ene] call DUWS_fnc_opcom_gridMobile;
    private _worst = {
        params ["_built", "_published"];
        private _gap = 0;
        private _at = 0;
        {
            private _d = abs (_x - (_published select _forEachIndex));
            if (_d > _gap) then { _gap = _d; _at = _forEachIndex };
        } forEach _built;
        format ["%1 at %2", _gap, ([_at] call DUWS_fnc_opcom_c2w) apply { round _x }]
    };
    private _line = format ["grid drift: fri %1, ene %2 (a missed dirty mark reads above 0.05)",
        [_fri, DUWS_opcom_grid_fri] call _worst, [_ene, DUWS_opcom_grid_ene] call _worst];
    ["INFO", "OPCOM", _line] call fnc_log;
    _line remoteExec ["hint", _caller];
};
