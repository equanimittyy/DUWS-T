// Locality: server -- fnc_static_place reads faction globals that live only there.
// The whole layout rotates about its centre, not the core inside a fixed ring, so cover stays aligned with the guns.

// Clockwise like setDir; +Y is the layout's facing.
fnc_hardpoint_rotate = {
    params ["_ox", "_oy", "_dir"];
    [_ox * cos _dir + _oy * sin _dir, _oy * cos _dir - _ox * sin _dir]
};

fnc_hardpoint_build = {
    params ["_type", "_pos", ["_dir", 0], ["_side", "opfor"], ["_key", "world"], ["_variant", "AT"]];
    private _px = _pos select 0;
    private _py = _pos select 1;

    // -1 dimensions take the variant's default field shape.
    if (_type isEqualTo "MINEFIELD") exitWith {
        [[_px, _py], _dir, _variant, -1, -1, -1, -1, _key] call fnc_hardpoint_minefield
    };

    private _rows = [_type] call fnc_hardpoint_comp;
    if (_rows isEqualTo []) exitWith {
        ["WARN", "HARDPOINT", format ["no composition for type %1", _type]] call fnc_log;
        []
    };

    // Weapon rows are placed below, not here, so their absolute Z survives rather than being stamped to terrain.
    private _placed = [_rows, [_px, _py], _key, [_dir, [], "all"]] call fnc_composition_place;
    // The mast stays destructible: wrecking it is how the player takes the tower.
    if (_type isEqualTo "RADIO") then {
        {
            if (typeOf _x isEqualTo DUWS_radioMastClass) then {
                _x enableSimulationGlobal true;
                _x allowDamage true;
            };
        } forEach _placed;
    };

    // fnc_static_place adds the row's offset to the origin, so the rotated offset rides the origin and X/Y is zeroed.
    {
        if !(_x param [5, false]) then { continue };
        _x params ["_wc", "_wox", "_woy", "_woz", "_wdir"];
        private _off = [_wox, _woy, _dir] call fnc_hardpoint_rotate;
        private _wrow = [_wc, 0, 0, _woz, _wdir + _dir, true];
        _placed pushBack ([_wrow, [_px + (_off select 0), _py + (_off select 1)], _side, _key, "world"] call fnc_static_place);
    } forEach _rows;

    _placed
};

// Tokens resolve here, not at the caller, so a re-raise draws fresh teams from what the site stores. Every gun is
// crewed whatever the token: an unmanned gun is scenery. _looseOnly re-raises a resident battery's patrol while its
// crew stays on the guns.
#define HP_GARRISON_PATROL_R 100  // tight, so the patrol holds the approaches instead of roaming the zone
fnc_hardpoint_garrison = {
    params ["_objs", "_pos", ["_side", "opfor"], ["_key", "world"], ["_teamToken", ""], ["_looseOnly", false]];
    private _sideObj = [EAST, WEST] select (_side isEqualTo "blufor");
    private _soldier = missionNamespace getVariable [format ["%1_SOLDIER_X", _side],
        ["O_Soldier_F", "B_Soldier_F"] select (_side isEqualTo "blufor")];
    private _men = [];

    // The difficulty curve's spotting lets a player walk up on a nest; max the spot skills only, never aim.
    private _maxSpot = { { _x setSkill ["spotDistance", 1]; _x setSkill ["spotTime", 1] } forEach _this };

    private _guns = _objs select { !isNull _x && {alive _x} && {_x isKindOf "StaticWeapon"} };
    if (!_looseOnly && {count _guns > 0}) then {
        private _sp = _pos findEmptyPosition [0, 30, _soldier];
        if (count _sp == 0) then { _sp = _pos };
        private _crew = [_sp, _sideObj, (_guns apply { _soldier }), [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
        _crew deleteGroupWhenEmpty true;
        (units _crew) call _maxSpot;
        [_guns, _crew] call DUWS_fnc_manStatics;
        _men append (units _crew);
    };

    // Artillery sits on its tracks, so its gunner moves straight in; artilleryScanner also catches a modded battery.
    private _arty = _objs select { !isNull _x && {alive _x} && {!(_x isKindOf "StaticWeapon")}
        && {getNumber (configFile >> "CfgVehicles" >> typeOf _x >> "artilleryScanner") isEqualTo 1} };
    if (!_looseOnly && {count _arty > 0}) then {
        private _sp = _pos findEmptyPosition [0, 30, _soldier];
        if (count _sp == 0) then { _sp = _pos };
        private _crew = [_sp, _sideObj, (_arty apply { _soldier }), [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
        _crew deleteGroupWhenEmpty true;
        (units _crew) call _maxSpot;
        // Seat before the thaw: a turret only wakes on that transition with a gunner already aboard.
        {
            ((units _crew) param [_forEachIndex, objNull]) moveInGunner _x;
            _x enableSimulationGlobal true;
        } forEach _arty;
        _men append (units _crew);
    };

    private _tokens = (if (_teamToken isEqualType "") then { [_teamToken] } else { _teamToken }) select { _x isNotEqualTo "" };
    {
        // Off-centre: men spawned at the emplacement snag on its bunker and bags.
        private _sp = _pos findEmptyPosition [30, 70, _soldier];
        if (count _sp == 0) then { _sp = _pos getPos [45, random 360] };
        private _grp = [_x, _pos, HP_GARRISON_PATROL_R, [_x] call DUWS_fnc_tokenPosture, _sp, _side] call fnc_spawn_team;
        if (!isNull _grp) then {
            (units _grp) call _maxSpot;
            _men append (units _grp);
        };
    } forEach _tokens;

    _men
};

#define HP_CAP_STEP 250
#define HP_SITE_SPACING 50
#define HP_TYPE_DRAWS 18
#define HP_POOL_ENOUGH 4
#define HP_ROAD_SNAP 120
#define HP_AOI_LOCAL_R 2000

// A weighted pick, not the single best, so a type's likeliest ground isn't its only ground. _rejectInZone keeps a
// standalone road snap out of a zone, whose own ring already holds its roads.
fnc_hardpoint_best_ground = {
    params ["_type", "_fnCand", ["_anchor", []], ["_rejectInZone", false]];
    private _pool = [];
    private _draws = 0;
    while { _draws < HP_TYPE_DRAWS && {(count _pool) < HP_POOL_ENOUGH * 2} } do {
        _draws = _draws + 1;
        private _draw = _anchor call _fnCand;
        if (_draw isEqualTo []) then { continue };
        _draw params ["_c", "_rdir"];
        if (_type isEqualTo "ROADBLOCK") then {
            // Main road first: a block earns more astride the arteries the enemy resupplies on.
            private _mains = (_c nearRoads HP_ROAD_SNAP) select { toUpper ((getRoadInfo _x) param [0, ""]) isEqualTo "MAIN ROAD" };
            private _road = objNull;
            private _bestD = 1e9;
            { private _d = _c distance2D _x; if (_d < _bestD) then { _bestD = _d; _road = _x } } forEach _mains;
            if (isNull _road) then { _road = [_c, HP_ROAD_SNAP] call BIS_fnc_nearestRoad };
            if (isNull _road) then { continue };
            private _rp = getPosASL _road;
            _c = [_rp select 0, _rp select 1, 0];
            if (_rejectInZone && {[_c] call fnc_aoi_in_any_zone}) then { continue };
        };
        private _f = [_c] call fnc_hardpoint_survey;
        if ((_f select 8) < HP_SITE_SPACING) then { continue };
        private _s = [_f, _type] call fnc_hardpoint_score;
        if (_s <= 0) then { continue };
        _pool pushBack [_c, _f, _rdir];
        _pool pushBack _s;
    };
    if (_pool isEqualTo []) exitWith { [] };
    selectRandomWeighted _pool
};

// Must run scheduled: fnc_hardpoint_register can crew inline, which sleeps in the crew drop.
fnc_hardpoint_spawn_at = {
    params ["_type", "_pos", "_key", ["_regZoneKey", ""], ["_radialDir", 0], ["_side", "opfor"], ["_facts", []]];
    if (_facts isEqualTo []) then { _facts = [_pos] call fnc_hardpoint_survey };
    private _dir = [_type, _facts select 10, _facts select 11, _radialDir, _facts select 12] call fnc_hardpoint_facing;
    private _objs = [_type, _pos, _dir, _side, _key] call fnc_hardpoint_build;
    if (_objs isEqualTo []) exitWith { [] };
    [_key, _type, _pos, _side, _regZoneKey, _dir] call fnc_hardpoint_register;
    [_objs, []]
};

fnc_hardpoint_spawn_sited = {
    params ["_type", "_fnCand", "_key", ["_regZoneKey", ""], ["_anchor", []], ["_side", "opfor"]];
    private _best = [_type, _fnCand, _anchor, _regZoneKey isEqualTo ""] call fnc_hardpoint_best_ground;
    if (_best isEqualTo []) exitWith { [] };
    _best params ["_cand", "_facts", "_radialDir"];
    [_type, _cand, _key, _regZoneKey, _radialDir, _side, _facts] call fnc_hardpoint_spawn_at
};

// _fnReset runs once per emplacement and its result is every _fnCand draw's _this, so one site's draws share an anchor.
// Type is rolled before ground: scoring ground first let high ground win nearly every site and starved AA and
// roadblock. A type with no ground is dropped, never swapped, since a swap brings that skew back.
fnc_hardpoint_lay = {
    params ["_count", "_keyPrefix", "_regZoneKey", "_fnCand", ["_fnTick", {}], ["_fnReset", {[]}], ["_weights", []]];
    if (_weights isEqualTo []) then {
        _weights = if (_regZoneKey isEqualTo "") then { DUWS_hardpointWeightSolo } else { DUWS_hardpointWeightZone };
    };
    private _typeRoll = [];
    { _typeRoll pushBack _x; _typeRoll pushBack (_weights get _x) } forEach (keys _weights);
    private _slate = [];
    for "_i" from 1 to _count do { _slate pushBack (selectRandomWeighted _typeRoll) };

    private _placed = 0;
    private _tally = createHashMap;
    {
        private _type = _x;
        private _anchor = call _fnReset;
        private _key = format ["%1_%2", _keyPrefix, _placed];
        private _res = [_type, _fnCand, _key, _regZoneKey, _anchor] call fnc_hardpoint_spawn_sited;
        if (_res isEqualTo []) then {
            ["INFO", "HARDPOINT", format ["%1 dropped a %2: no ground it can hold", _keyPrefix, _type]] call fnc_log;
        } else {
            _placed = _placed + 1;
            _tally set [_type, (_tally getOrDefault [_type, 0]) + 1];
            _placed call _fnTick;
        };
    } forEach _slate;

    ["INFO", "HARDPOINT", format ["%1 laid %2/%3 %4", _keyPrefix, _placed, _count, _tally]] call fnc_log;
    _placed
};

// Computed live, not cached, so a tier climb raises the cap without rewriting the stored radius cap.
fnc_hardpoint_zone_cap = {
    params ["_zoneKey", "_radius"];
    private _radiusCap = (round (_radius / HP_CAP_STEP)) max 1;
    _radiusCap + (0 max (([_zoneKey] call fnc_zone_tier) - 1))
};

fnc_hardpoint_zone_cand = {
    params ["_zonePos", "_radius"];
    private _c = [_zonePos, 0, _radius, 6, 0, 0.35, 0] call BIS_fnc_findSafePos;
    [_c, _zonePos getDir _c]
};

fnc_hardpoint_site_zone = {
    params ["_zonePos", "_radius", "_zoneKey", ["_count", -1], ["_fnTick", {}]];
    // The stored cap is the idempotency guard: a rebuild through fnc_createZone lays no second ring.
    if (!isNil { missionNamespace getVariable (format ["DUWS_hpCap_%1", _zoneKey]) }) exitWith {};
    private _cap = [_zoneKey, _radius] call fnc_hardpoint_zone_cap;
    // Pre-rolled by fnc_hardpoint_plan_counts so the banner can total up front.
    if (_count < 0) then { _count = round (random _cap) };
    // Radius cap only: every reader re-adds the tier bonus, so a tier buy leaves it untouched.
    missionNamespace setVariable [format ["DUWS_hpCap_%1", _zoneKey], (round (_radius / HP_CAP_STEP)) max 1];

    private _placed = 0;
    if (_count > 0) then {
        _placed = [_count, format ["hp_%1", _zoneKey], _zoneKey, fnc_hardpoint_zone_cand, _fnTick, { [_zonePos, _radius] }] call fnc_hardpoint_lay;
    };

    ["INFO", "HARDPOINT", format ["%1 sited %2/%3 ring (cap %4)", _zoneKey, _placed, _count, _cap]] call fnc_log;
};

// One fixed anchor per emplacement keeps its draws local rather than scattered over every zone's band.
fnc_hardpoint_band_anchor = {
    private _a = [];
    for "_i" from 1 to 8 do { _a = call DUWS_fnc_aoi_bandPos; if !(_a isEqualTo []) exitWith {} };
    _a
};

fnc_hardpoint_band_cand = {
    // _this is the anchor itself, not [anchor]: params ["_anchor"] would take only its first element.
    private _anchor = _this;
    if (_anchor isEqualTo []) exitWith { [] };
    _anchor params ["_apos", "", "_azone"];
    private _c = [_apos, 0, HP_AOI_LOCAL_R, 8, 0, 0.35, 0] call BIS_fnc_findSafePos;
    if (([_c] call fnc_aoi_field_at) <= 0) exitWith { [] };
    if ([_c] call fnc_aoi_in_any_zone) exitWith { [] };
    [_c, _azone getDir _c]
};

// Few samples, so the HQ bias stays a lean and nests scatter through the band rather than lining one contour.
#define HP_FLANK_SAMPLES 5

// The blocks below read _toHQ up the call stack from inside fnc_hardpoint_lay (SQF dynamic scope).
fnc_hardpoint_site_flank = {
    params ["_count", "_toHQ", ["_fnTick", {}]];
    if (_count <= 0) exitWith { 0 };
    private _prefix = ["hpback", "hpfront"] select _toHQ;
    private _placed = [_count, _prefix, "", {
        private _d = _this call fnc_hardpoint_band_cand;
        if (_d isEqualTo []) exitWith { [] };
        _d params ["_c"];
        private _rdir = if (PosOfBLUHQ isEqualTo []) then { _d select 1 }
            else { [PosOfBLUHQ getDir _c, _c getDir PosOfBLUHQ] select _toHQ };
        [_c, _rdir]
    }, _fnTick, {
        if (PosOfBLUHQ isEqualTo []) exitWith { call fnc_hardpoint_band_anchor };
        private _best = [];
        private _bestD = [-1, 1e12] select _toHQ;
        for "_i" from 1 to HP_FLANK_SAMPLES do {
            private _a = call fnc_hardpoint_band_anchor;
            if (_a isEqualTo []) then { continue };
            private _dist = (_a select 0) distance2D PosOfBLUHQ;
            if ((_toHQ && {_dist < _bestD}) || {!_toHQ && {_dist > _bestD}}) then {
                _bestD = _dist;
                _best = _a;
            };
        };
        _best
    }, DUWS_hardpointWeightNest] call fnc_hardpoint_lay;
    ["INFO", "HARDPOINT", format ["%1 line sited %2/%3 nests", _prefix, _placed, _count]] call fnc_log;
    _placed
};

// A dropped block still consumes its target, so the generation banner total stays honest.
fnc_hardpoint_site_roadblocks = {
    params ["_roadTargets", ["_fnTick", {}]];
    private _count = count _roadTargets;
    if (_count <= 0) exitWith { 0 };
    private _idx = 0;
    private _placed = [_count, "hproad", "", {
        _this params ["_zpos", "_epos"];
        if (_epos isEqualTo []) exitWith {
            private _a = call fnc_hardpoint_band_anchor;
            if (_a isEqualTo []) exitWith { [] };
            [_a select 0, (_a select 0) getDir _zpos]
        };
        private _f = 0.3 + random 0.6;
        private _ex = _epos select 0;
        private _ey = _epos select 1;
        private _p = [_ex + ((_zpos select 0) - _ex) * _f, _ey + ((_zpos select 1) - _ey) * _f, 0];
        private _c = [_p, 0, HP_ROAD_SNAP, 6, 0, 0.35, 0] call BIS_fnc_findSafePos;
        if (([_c] call fnc_aoi_field_at) <= 0) exitWith { [] };
        [_c, _c getDir _epos]  // fnc_hardpoint_facing turns this onto the road
    }, _fnTick, {
        private _t = _roadTargets select _idx;
        _idx = _idx + 1;
        _t
    }, createHashMapFromArray [["ROADBLOCK", 1]]] call fnc_hardpoint_lay;
    ["INFO", "HARDPOINT", format ["roadblock net sited %1/%2", _placed, _count]] call fnc_log;
    _placed
};

// Not rolled through fnc_hardpoint_lay: a tower must keep off another's AoI, so it takes the best of a few samples.
#define HP_RADIO_SPACING 250
#define HP_RADIO_SAMPLES 6
fnc_hardpoint_seed_radio = {
    params [["_n", 2], ["_fnTick", {}]];
    private _placed = 0;
    private _tries = 0;
    while { _placed < _n && {_tries < _n * 12} } do {
        _tries = _tries + 1;

        // Checked live against standing towers, not a cached count, so coverage never nests.
        private _best = [];
        private _bestScore = -1;
        for "_i" from 1 to HP_RADIO_SAMPLES do {
            private _draw = call DUWS_fnc_aoi_bandPos;
            if (_draw isEqualTo []) then { continue };
            private _cand = _draw select 0;
            if ((DUWS_hardpoints findIf {
                (_x select 2) isEqualTo "RADIO" && {(_cand distance2D (_x select 1)) < AOI_TOWER_REACH}
            }) >= 0) then { continue };
            private _f = [_cand] call fnc_hardpoint_survey;
            if ((_f select 8) < HP_RADIO_SPACING) then { continue };
            private _s = [_f, "RADIO"] call fnc_hardpoint_score;
            if (_s > _bestScore) then { _bestScore = _s; _best = _cand };
        };
        if (_best isEqualTo []) then { continue };
        private _c = _best;

        // Global sequence: a campaign-start seed and a later raise never share a key.
        private _seq = missionNamespace getVariable ["DUWS_radioSeq", 0];
        missionNamespace setVariable ["DUWS_radioSeq", _seq + 1];
        private _key = format ["hpradio_%1", _seq];
        private _rdir = random 360;
        ["RADIO", _c, _rdir, "opfor", _key] call fnc_hardpoint_build;
        [_key, "RADIO", _c, "opfor", "", _rdir] call fnc_hardpoint_register;
        _placed = _placed + 1;
        _placed call _fnTick;
    };
    ["INFO", "HARDPOINT", format ["seeded %1/%2 OPFOR radio towers", _placed, _n]] call fnc_log;
};

// Rolls every campaign-start emplacement before any is laid, so the generation banner totals real hardpoints.
#define HP_FLANK_KNEE 6
#define HP_FLANK_SLOPE 0.5
#define HP_ROAD_HQ_P 0.8    // per-zone chance of an HQ approach roadblock
#define HP_ROAD_NBR_P 0.4   // per-zone chance of an off-axis inter-zone roadblock
#define HP_OBS_P 0.5        // per-zone chance of a standalone observation post out in the band
fnc_hardpoint_plan_counts = {
    params ["_radioN"];
    private _zc = count serv_zones_array;
    private _zoneCounts = [];
    private _roadTargets = [];
    private _total = _radioN + _zc;
    private _obs = 0;
    {
        _x params ["", "_zpos", "_hpSize"];
        private _cap = [[_zpos] call fnc_zone_key, _hpSize] call fnc_hardpoint_zone_cap;
        private _n = round (random _cap);
        _zoneCounts pushBack _n;
        _total = _total + _n;
        if (random 1 < HP_OBS_P) then { _obs = _obs + 1 };
    } forEach zone_meta_array;
    _total = _total + _obs;

    // Two passes, not hub-and-spoke: blocks all on HQ-to-zone lines read as an arrow home. The inter-zone pass
    // skips the nearest zone, so a block reads as neither toward HQ nor the obvious hop.
    private _hqSet = !(PosOfBLUHQ isEqualTo []);
    {
        private _zpos = _x select 1;
        private _zi = _forEachIndex;
        if (random 1 < HP_ROAD_HQ_P) then { _roadTargets pushBack [_zpos, if (_hqSet) then { PosOfBLUHQ } else { [] }] };
        if (_zc >= 3) then {
            private _closest = -1;
            private _cd = 1e12;
            {
                if (_forEachIndex != _zi) then {
                    private _d = _zpos distance2D (_x select 1);
                    if (_d < _cd) then { _cd = _d; _closest = _forEachIndex };
                };
            } forEach zone_meta_array;
            private _cands = [];
            {
                if (_forEachIndex != _zi && {_forEachIndex != _closest}) then { _cands pushBack (_x select 1) };
            } forEach zone_meta_array;
            if (count _cands > 0 && {random 1 < HP_ROAD_NBR_P}) then { _roadTargets pushBack [_zpos, selectRandom _cands] };
        };
    } forEach zone_meta_array;
    _total = _total + count _roadTargets;

    // Zones screen each other's flanks as they multiply, so past the knee each extra zone adds only part of one.
    private _fz = if (_zc <= HP_FLANK_KNEE) then { _zc } else { HP_FLANK_KNEE + round ((_zc - HP_FLANK_KNEE) * HP_FLANK_SLOPE) };
    private _lo = floor (_fz / 2);
    private _backline = _lo + floor random (_fz - _lo + 1);
    private _frontline = _lo + floor random (_fz - _lo + 1);
    _total = _total + _backline + _frontline;
    [_zoneCounts, _backline, _frontline, _roadTargets, _obs, _total]
};

fnc_hardpoint_debug = {
    params ["_zoneKey", "_radius"];
    private _tier = [_zoneKey] call fnc_zone_tier;
    private _cap = [_zoneKey, _radius] call fnc_hardpoint_zone_cap;
    private _tierBonus = 0 max (_tier - 1);
    private _radiusCap = _cap - _tierBonus;
    private _live = { (_x select 4) isEqualTo _zoneKey } count DUWS_hardpoints;
    [
        format ["[HARDPOINTS %1]", _zoneKey],
        format ["  ring cap = %1 (radius %2m) + %3 (tier %4) = %5 max", _radiusCap, round _radius, _tierBonus, _tier, _cap],
        format ["  on ground: %1 / %2", _live, _cap]
    ]
};
