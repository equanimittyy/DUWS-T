// Locality: server. Rebuilds both live force layers from scratch each strategic phase: zero them, then
// deposit every force source once with a linear falloff to its reach edge. A source is a men count at a
// position -- friendly = OPFOR holdings (zone/town garrisons, hardpoints), enemy = BLU-held zones and
// belief. Men-count is the Phase 1 metric: both layers must share it (belief carries only headcount), so
// the force ratio that reads this in Phase 2 is meaningful. The per-source weight is the swap point where
// Phase 2 introduces firepower-weighting on both sides. Each deposit scans only the box around its source
// cell -- never the whole grid, never a pass over allUnits.
if (!isServer) exitWith {};

private _cell = OPCOM_GRID_CELL;
private _w = DUWS_opcom_grid_w;
private _fri = DUWS_opcom_grid_fri;
private _ene = DUWS_opcom_grid_ene;
private _n = _w * _w;
for "_i" from 0 to (_n - 1) do { _fri set [_i, 0]; _ene set [_i, 0] };

private _deposit = {
    params ["_layer", "_pos", "_weight", "_reach"];
    if (_weight <= 0) exitWith {};
    private _scx = (floor ((_pos select 0) / _cell)) min (_w - 1) max 0;
    private _scy = (floor ((_pos select 1) / _cell)) min (_w - 1) max 0;
    private _k = ceil (_reach / _cell);
    for "_cy" from (_scy - _k) max 0 to (_scy + _k) min (_w - 1) do {
        for "_cx" from (_scx - _k) max 0 to (_scx + _k) min (_w - 1) do {
            private _d = _pos distance2D [(_cx + 0.5) * _cell, (_cy + 0.5) * _cell];
            if (_d <= _reach) then {
                private _ci = _cy * _w + _cx;
                _layer set [_ci, (_layer select _ci) + _weight * (1 - _d / _reach)];
            };
        };
    };
};

// OPFOR's own force is what it has standing. A live site counts its living infantry -- alive roster men
// whose source token is a team, so a casualty drops the weight that tick; a stowed site (no men on the
// ground) falls back to the ledger's surviving-token men, left whole-token for redeploy and the map bar.
// Crew are excluded both ways (a vehicle token owes no men), so the counts match until Phase 2 weights vehicles.
private _garrisonMen = {
    params ["_key"];
    if ([_key] call DUWS_fnc_garrisonHeld) exitWith {
        { alive _x && {!(([(group _x) getVariable ["DUWS_srcToken", ""]] call DUWS_fnc_teamRow) isEqualTo [])} } count ([_key] call fnc_site_roster)
    };
    [[_key] call DUWS_fnc_garrisonSurviving] call DUWS_fnc_tokenListMen
};

// Zones: OPFOR-held deposit their garrison men to friendly; BLU-held are known enemy ground (a
// territorial fact the commander has for free), so they deposit a nominal baseline even unsighted.
{
    _x params ["", "_zp", "_zs"];
    private _key = format ["zone_%1_%2", round (_zp select 0), round (_zp select 1)];
    if ((WARCOM_zones_controled_by_BLUFOR findIf {(_x distance2D _zp) < 1}) >= 0) then {
        [_ene, _zp, OPCOM_GRID_ZONE_ENEMY_MEN, _zs + OPCOM_GRID_SPREAD] call _deposit;
    } else {
        [_fri, _zp, [_key] call _garrisonMen, _zs + OPCOM_GRID_SPREAD] call _deposit;
    };
} forEach zone_meta_array;

// Banded towns: tier is 1 only where the town is OPFOR-banded, 0 elsewhere -- a neutral or BLU town
// fields no OPFOR garrison and deposits nothing.
private _locs  = missionNamespace getVariable ["civ_locations", []];
private _radii = missionNamespace getVariable ["civ_radii", []];
{
    if (_x >= 1) then {
        private _key = [_forEachIndex] call fnc_town_site_key;
        [_fri, getPos (_locs select _forEachIndex), [_key] call _garrisonMen, (_radii param [_forEachIndex, 500]) + OPCOM_GRID_SPREAD] call _deposit;
    };
} forEach (missionNamespace getVariable ["DUWS_townGarrisonTier", []]);

// Standing OPFOR hardpoints, a nominal crew each (Phase 2 reads real crew / weapon power).
{
    if ((_x select 3) isEqualTo "opfor") then { [_fri, _x select 1, OPCOM_GRID_HP_MEN, OPCOM_GRID_SPREAD] call _deposit };
} forEach DUWS_hardpoints;

// Belief: each surviving stamp deposits its headcount scaled by age decay (an expired stamp is already
// gone from the arrays). Covers a sighted player, a discovered HQ and a discovered FOB alike.
{
    private _age = DUWS_opcom_tick - (DUWS_opcom_belief_time select _forEachIndex);
    private _decay = ((OPCOM_BELIEF_EXPIRE - _age) / (OPCOM_BELIEF_EXPIRE - OPCOM_BELIEF_FRESH)) max 0 min 1;
    [_ene, _x, (DUWS_opcom_belief_str select _forEachIndex) * _decay, OPCOM_GRID_SPREAD] call _deposit;
} forEach DUWS_opcom_belief_pos;
