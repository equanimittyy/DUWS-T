// Locality: server -- createVehicle and fnc_static_place need the authoritative faction globals, which live only there.
// A hardpoint rotates the whole layout (cover + core) about its centre rather than turning the core inside a fixed ring, so cover stays aligned with the guns on any heading.

// [_ox, _oy, _dir] call fnc_hardpoint_rotate -> [x, y] rotated onto heading _dir (clockwise like
// setDir; +Y is the layout's facing). Pure, so the rotation is unit-tested.
fnc_hardpoint_rotate = {
    params ["_ox", "_oy", "_dir"];
    [_ox * cos _dir + _oy * sin _dir, _oy * cos _dir - _ox * sin _dir]
};

// [_type, _pos, _dir, _side, _key] call fnc_hardpoint_build -> [objects]
//   _type is the suffix of DUWS_hardpointComp_<type> ("MG"/"AT"/.../"MINEFIELD"); _variant ("AT"/"AP") only matters for MINEFIELD.
fnc_hardpoint_build = {
    params ["_type", "_pos", ["_dir", 0], ["_side", "opfor"], ["_key", "world"], ["_variant", "AT"]];
    private _px = _pos select 0;
    private _py = _pos select 1;

    // The minefield is generated, not composed -- it has no fence to place. -1 dimensions let the
    // generator size the field from the variant's own profile.
    if (_type isEqualTo "MINEFIELD") exitWith {
        [[_px, _py], _dir, _variant, -1, -1, -1, -1, _key] call fnc_hardpoint_minefield
    };

    private _rows = [_type] call fnc_hardpoint_comp;
    if (_rows isEqualTo []) exitWith {
        ["WARN", "HARDPOINT", format ["no composition for type %1", _type]] call fnc_log;
        []
    };

    // Props go through the shared placer frozen and hardened, offsets rotated by _dir, never tilted. Weapon rows
    // are skipped here and placed below instead, so their absolute Z survives rather than being stamped to terrain like a prop.
    private _placed = [_rows, [_px, _py], _key, [_dir, [], "all"]] call fnc_composition_place;
    // The radio mast alone stays simulated/damageable so the player can destroy the tower; fnc_hardpoint_stream reads
    // the mast, not the roster. The placer hardened every prop, so this undoes it on the mast only (a no-op for other types).
    if (_type isEqualTo "RADIO") then {
        {
            if (typeOf _x isEqualTo DUWS_radioMastClass) then {
                _x enableSimulationGlobal true;
                _x allowDamage true;
            };
        } forEach _placed;
    };

    // Weapons second: fnc_static_place adds the row's own offset to the origin, so the rotated offset is folded
    // into the origin here and the row is passed with a zeroed X/Y to avoid applying it twice.
    {
        if !(_x param [5, false]) then { continue };
        _x params ["_wc", "_wox", "_woy", "_woz", "_wdir"];
        private _off = [_wox, _woy, _dir] call fnc_hardpoint_rotate;
        private _wrow = [_wc, 0, 0, _woz, _wdir + _dir, true];
        _placed pushBack ([_wrow, [_px + (_off select 0), _py + (_off select 1)], _side, _key, "world"] call fnc_static_place);
    } forEach _rows;

    _placed
};

// [_objs, _pos, _side, _key, _teamToken] call fnc_hardpoint_garrison -> [men]
//
// _teamToken is "team" / "" / an array of tokens, resolved to classnames here (not passed as a list) so a
// re-raise draws fresh teams from what the site stores. Every gun is crewed regardless of the token -- an
// unmanned gun is scenery, not a defence.
//
// Static weapons crew via DUWS_fnc_manStatics (thaw, drop to settle, seat a gunner -- they start frozen,
// sometimes on a roof); artillery is already on its tracks, so its gunner moves straight in and only the
// piece thaws. artilleryScanner is the auto-detect flag that catches a modded battery the same way.
//
// HP_GARRISON_PATROL_R is kept tight so the loose garrison holds the emplacement's approaches instead of
// roaming the zone. _looseOnly places only that patrol. A resident battery's crew stays pinned on the guns
// across a garrison stow -- crew and loose men are filed under separate rosters, so the stow
// (fnc_site_collect) only ever touches the loose one and never re-crews a gun that was never emptied.
#define HP_GARRISON_PATROL_R 100
fnc_hardpoint_garrison = {
    params ["_objs", "_pos", ["_side", "opfor"], ["_key", "world"], ["_teamToken", ""], ["_looseOnly", false]];
    private _sideObj = [EAST, WEST] select (_side isEqualTo "blufor");
    private _soldier = missionNamespace getVariable [format ["%1_SOLDIER_X", _side],
        ["O_Soldier_F", "B_Soldier_F"] select (_side isEqualTo "blufor")];
    private _men = [];

    // spawnGroup's skill roll leaves spotting to the difficulty curve, which reads low enough that a nest gets
    // walked up on before it reacts; force max spotDistance/spotTime only, so defenders spot without becoming an aimbot.
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

    private _arty = _objs select { !isNull _x && {alive _x} && {!(_x isKindOf "StaticWeapon")}
        && {getNumber (configFile >> "CfgVehicles" >> typeOf _x >> "artilleryScanner") isEqualTo 1} };
    if (!_looseOnly && {count _arty > 0}) then {
        private _sp = _pos findEmptyPosition [0, 30, _soldier];
        if (count _sp == 0) then { _sp = _pos };
        private _crew = [_sp, _sideObj, (_arty apply { _soldier }), [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
        _crew deleteGroupWhenEmpty true;
        (units _crew) call _maxSpot;
        {
            _x enableSimulationGlobal true;
            ((units _crew) param [_forEachIndex, objNull]) moveInGunner _x;
        } forEach _arty;
        _men append (units _crew);
    };

    // Each loose defender holds the posture its token names (DUWS_fnc_tokenPosture): closepatrol:team works the
    // emplacement's approaches while the gun holds; widepatrol:team screens wider instead.
    private _tokens = if (_teamToken isEqualType "") then { [_teamToken] } else { _teamToken };
    {
        // Spawn out toward the patrol ring, not the emplacement itself -- at the centre men land among the bunker,
        // bags and gun and snag on them before the patrol circuit clears them; the fallback keeps the same off-centre bearing.
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
#define HP_TYPE_DRAWS 18     // draws spent hunting a spot for one rolled type before it is dropped
#define HP_POOL_ENOUGH 4     // stop drawing once this many viable spots are in hand, then pick among them
#define HP_ROAD_SNAP 120     // roadblock: a draw is pulled to the nearest road within this, else discarded
#define HP_AOI_LOCAL_R 2000  // AoI band pass: the local search radius around each emplacement's anchor

// [_type, _fnCand, _anchor, _rejectInZone] call fnc_hardpoint_best_ground -> [_cand, _facts, _radialDir] | []
//
// Weighted-picks among viable draws (score > 0) rather than taking the single best, so a type's likeliest
// ground isn't its only possible ground. Ground only -- no spawn, no registry -- so this is the shared core
// of both the undirected slate roll (fnc_hardpoint_lay) and the directed fnc_hardpoint_spawn_sited.
//
// _rejectInZone drops a road snap that crossed into a zone: standalone passes want that (zone roadblocks
// sit on the zone's own road already), the zone pass does not.
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
            // Prefer a main road (MSV) within snap range, else any road: a block earns more astride the
            // arteries the enemy resupplies on. getRoadInfo's first field is the road-class string.
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

// [_type, _fnCand, _key, _regZoneKey, _anchor, _side] call fnc_hardpoint_spawn_sited -> [_objs, []] | []
//
// The tail fnc_hardpoint_lay runs per rolled type; a caller that already knows the type it wants (OPCOM
// reinforcing a gap with a specific weapon) calls here directly instead of rolling a slate. _regZoneKey
// files the row under a parent zone ("" = standalone, which also gates the roadblock snap out of zones).
//
// Register decides whether to crew now or stow -- an emplacement out of a player's reach stays uncrewed
// until approached, so campaign start never pays the drop-and-settle for nobody. Runs spawned: register
// sleeps in the crew drop when it crews inline.
fnc_hardpoint_spawn_sited = {
    params ["_type", "_fnCand", "_key", ["_regZoneKey", ""], ["_anchor", []], ["_side", "opfor"]];
    private _best = [_type, _fnCand, _anchor, _regZoneKey isEqualTo ""] call fnc_hardpoint_best_ground;
    if (_best isEqualTo []) exitWith { [] };
    _best params ["_cand", "_facts", "_radialDir"];
    // A roadblock faces along its road; overwatch nests face down the slope they overlook; the rest keep
    // the radial the draw carried.
    private _dir = [_type, _facts select 10, _facts select 11, _radialDir, _facts select 12] call fnc_hardpoint_facing;
    private _objs = [_type, _cand, _dir, _side, _key] call fnc_hardpoint_build;
    if (_objs isEqualTo []) exitWith { [] };  // no composition for the type -- nothing sited
    [_key, _type, _cand, _side, _regZoneKey, _dir] call fnc_hardpoint_register;
    [_objs, []]
};

// [_count, _keyPrefix, _regZoneKey, _fnCand, _fnTick, _fnReset, _weights] call fnc_hardpoint_lay -> hardpoints placed.
//
// Shared placement loop for the zone pass and the AoI band pass -- they differ only in where a candidate
// comes from (_fnCand), so that's the one thing passed in. _fnReset runs once per emplacement and its
// result is handed to every _fnCand call as _this: the AoI pass uses it to fix one local search anchor per
// hardpoint so draws stay comparable; the zone pass omits it.
//
// Type is rolled before ground is hunted, not the reverse: the old order picked the best-scoring spot first
// and rolled a type there, which let high ground (that MG/AT score huge on) win nearly every site and starve
// AA and roadblock. Rolling the whole slate up front from the weight map means terrain decides only WHERE a
// type lands, never WHICH is placed; a type with no ground in its draw budget is dropped and logged, never
// swapped -- swapping is the skew this order removes. Minefields and fire-support types are OPCOM's to
// place and are never rolled here.
//
// Runs spawned: fnc_hardpoint_register sleeps in the crew drop when it crews one inline, so build-out cannot call it inline.
fnc_hardpoint_lay = {
    params ["_count", "_keyPrefix", "_regZoneKey", "_fnCand", ["_fnTick", {}], ["_fnReset", {[]}], ["_weights", []]];
    // Zone rings and standalone ground roll different type mixes (AA and more roadblocks off the zone rings);
    // [] picks by _regZoneKey for callers that don't care, while a scenario pass (flank/AA/roadblock net) hands its own single-purpose map instead.
    if (_weights isEqualTo []) then {
        _weights = if (_regZoneKey isEqualTo "") then { DUWS_hardpointWeightSolo } else { DUWS_hardpointWeightZone };
    };
    // Flattened [type, weight, ...] for selectRandomWeighted; the roll reads base weight alone, no ground.
    private _typeRoll = [];
    { _typeRoll pushBack _x; _typeRoll pushBack (_weights get _x) } forEach (keys _weights);
    private _slate = [];
    for "_i" from 1 to _count do { _slate pushBack (selectRandomWeighted _typeRoll) };

    private _placed = 0;
    private _tally = createHashMap;
    {
        private _type = _x;
        // _key uses the running _placed count, not the loop index, so a dropped type consumes no index slot.
        private _anchor = call _fnReset;
        private _key = format ["%1_%2", _keyPrefix, _placed];
        private _res = [_type, _fnCand, _key, _regZoneKey, _anchor] call fnc_hardpoint_spawn_sited;
        if (_res isEqualTo []) then {
            // A roadblock in roadless country is the usual cause of a drop here.
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

// [_zoneKey, _radius] call fnc_hardpoint_zone_cap -> how many emplacements a zone's ring may hold.
//
// Radius (stepped every HP_CAP_STEP, floored at one) and tier (one more per step above I, OPCOM's bought
// fortification) are the two levers. Read live at every count decision rather than cached, so a zone that
// climbs tier earns a higher ceiling without the stored radius cap being rewritten.
fnc_hardpoint_zone_cap = {
    params ["_zoneKey", "_radius"];
    private _radiusCap = (round (_radius / HP_CAP_STEP)) max 1;
    _radiusCap + (0 max (([_zoneKey] call fnc_zone_tier) - 1))
};

// [_zonePos, _radius, _zoneKey, _count, _fnTick] call fnc_hardpoint_site_zone
//
// A zone's own fortification ring, drawn from anywhere in the zone and faced radially out; layered defence
// around it (nests leaning toward/away from the fight) is the flank passes' job now (fnc_hardpoint_site_flank).
//
// Idempotent per zone -- the stored cap is the guard, so a rebuild through fnc_createZone lays no second set.
// Runs spawned, via fnc_hardpoint_lay's crew drop.
fnc_hardpoint_site_zone = {
    params ["_zonePos", "_radius", "_zoneKey", ["_count", -1], ["_fnTick", {}]];
    if (!isNil { missionNamespace getVariable (format ["DUWS_hpCap_%1", _zoneKey]) }) exitWith {};
    private _cap = [_zoneKey, _radius] call fnc_hardpoint_zone_cap;
    // The count arrives pre-rolled from fnc_hardpoint_plan_counts so the banner can total every emplacement
    // up front; a standalone call (no plan) rolls its own against the tier-boosted cap.
    if (_count < 0) then { _count = round (random _cap) };
    // Store the radius cap alone -- the idempotency guard, and a baseline that survives a tier buy
    // untouched, since every reader re-adds the tier bonus through fnc_hardpoint_zone_cap.
    missionNamespace setVariable [format ["DUWS_hpCap_%1", _zoneKey], (round (_radius / HP_CAP_STEP)) max 1];

    private _placed = 0;
    if (_count > 0) then {
        _placed = [_count, format ["hp_%1", _zoneKey], _zoneKey, {
            private _c = [_zonePos, 0, _radius, 6, 0, 0.35, 0] call BIS_fnc_findSafePos;
            [_c, _zonePos getDir _c]
        }, _fnTick] call fnc_hardpoint_lay;
    };

    ["INFO", "HARDPOINT", format ["%1 sited %2/%3 ring (cap %4)", _zoneKey, _placed, _count, _cap]] call fnc_log;
};

// Shared local-search sampler for the band pass (campaign-start and OPCOM's band build): one fixed anchor
// per emplacement, then draws confined to its neighbourhood rather than scattered across every zone's band.
//
// [] call fnc_hardpoint_band_anchor -> [_pos, _radialDir, _zoneCentre] or []. Retries a handful of times on a
// missed draw (DUWS_fnc_aoi_bandPos can return []) rather than dropping the whole hardpoint to one unlucky roll.
fnc_hardpoint_band_anchor = {
    private _a = [];
    for "_i" from 1 to 8 do { _a = call DUWS_fnc_aoi_bandPos; if !(_a isEqualTo []) exitWith {} };
    _a
};

// _anchor call fnc_hardpoint_band_cand -> [_pos, _radialDir] or []. A draw within HP_AOI_LOCAL_R of the
// anchor, gated like the band (OPFOR-positive, outside every zone) and faced outward from the anchor's source zone.
fnc_hardpoint_band_cand = {
    // _this IS the anchor array itself, not a wrapper -- params would destructure it element-by-element
    // and hand back only its first element, so take it whole.
    private _anchor = _this;
    if (_anchor isEqualTo []) exitWith { [] };
    _anchor params ["_apos", "", ["_azone", []]];
    private _c = [_apos, 0, HP_AOI_LOCAL_R, 8, 0, 0.35, 0] call BIS_fnc_findSafePos;
    if (([_c] call fnc_aoi_field_at) <= 0) exitWith { [] };
    if ([_c] call fnc_aoi_in_any_zone) exitWith { [] };
    [_c, if (_azone isEqualTo []) then { random 360 } else { _azone getDir _c }]
};

// The band anchors a flank emplacement samples before keeping the one the flank wants; a lean toward HQ,
// not a hard cut, so nests still scatter through the band rather than lining one contour.
#define HP_FLANK_SAMPLES 5

// [_count, _toHQ, _fnTick] call fnc_hardpoint_site_flank -> emplacements placed.
//
// A flank line of gun nests weighted by distance to BLU HQ, not tied to any one zone -- same band the
// roadblock and AA nets draw from. _toHQ true is the frontline: biased toward and faced at HQ (a flat-ground
// nest points down the approach; a real slope still wins the fall line via fnc_hardpoint_facing). _toHQ
// false is the backline: biased away, faced away from HQ. Each emplacement samples HP_FLANK_SAMPLES band
// anchors and keeps the nearest (front) or farthest (back) from HQ; no HQ yet falls back to a plain anchor.
//
// _toHQ is read from this scope by the reset/candidate blocks below rather than threaded through lay's
// params -- they run inside fnc_hardpoint_lay but resolve it up the call stack via SQF's dynamic scoping.
fnc_hardpoint_site_flank = {
    params ["_count", "_toHQ", ["_fnTick", {}]];
    if (_count <= 0) exitWith { 0 };
    private _prefix = ["hpback", "hpfront"] select _toHQ;
    private _placed = [_count, _prefix, "", {
        // Same gating as band_cand; only the outward facing is swapped for one keyed to HQ below.
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

// [_roadTargets, _fnTick] call fnc_hardpoint_site_roadblocks -> roadblocks placed.
//
// Each target is [zonePos, endpointPos]: a block sits along endpoint -> zone at a random depth, kept only in
// OPFOR-held ground, snapped to a road by fnc_hardpoint_best_ground and faced back toward its endpoint (HQ
// for the approach pass, the neighbour zone for the inter-zone pass). Endpoint [] (no HQ at plan time) falls
// back to a plain band draw near the zone.
//
// One lay call over the whole pre-expanded target list: the reset hands out the next target per emplacement,
// and a dropped block still consumes its target so the generation banner total stays honest.
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
        [_c, _c getDir _epos]  // facing gets snapped to the nearer road heading downstream, in fnc_hardpoint_facing
    }, _fnTick, {
        private _t = _roadTargets select _idx;
        _idx = _idx + 1;
        _t
    }, createHashMapFromArray [["ROADBLOCK", 1]]] call fnc_hardpoint_lay;
    ["INFO", "HARDPOINT", format ["roadblock net sited %1/%2", _placed, _count]] call fnc_log;
    _placed
};

// [_n] call fnc_hardpoint_seed_radio -> radio towers placed.
//
// Deliberately placed, not rolled through fnc_hardpoint_lay: samples band positions, drops any inside
// another tower's AoI or too close to an emplacement, and stands RADIO on the best-scoring hilltop of what
// survives, so masts neither share ground nor nest coverage. Each raises DUWS_opforRadioLevel (via
// fnc_hardpoint_register) and projects AOI_TOWER_REACH of coverage; a global sequence keys the towers so a
// campaign-start seed and OPCOM's later raises never collide.
#define HP_RADIO_SPACING 250
#define HP_RADIO_SAMPLES 6
fnc_hardpoint_seed_radio = {
    params [["_n", 2], ["_fnTick", {}]];
    private _placed = 0;
    private _tries = 0;
    while { _placed < _n && {_tries < _n * 12} } do {
        _tries = _tries + 1;

        // One survey per candidate serves both the spacing gate and the RADIO score. AoI overlap is checked live
        // against standing RADIO towers (not a cached count), so nested coverage never forms.
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

// [_radioN] call fnc_hardpoint_plan_counts -> [_zoneCounts, _backline, _frontline, _roadTargets, _obs, _total]
//
// Rolls every campaign-start emplacement before any is laid, so the generation banner totals real hardpoints
// up front instead of counting zones. Radio and AA are rolled by the caller and only summed in here, so the
// seed/spawn calls are handed the same numbers. Lives here, not in WARCOM init, so the count formulas aren't
// duplicated away from HP_CAP_STEP.
//
// Flank throttle: nests offset from a zone matter most when it stands alone with open flanks; as zones
// multiply they screen each other, so flat per-zone density just carpets the map. Below HP_FLANK_KNEE the
// flank lines track zone count exactly; above it each extra zone adds only HP_FLANK_SLOPE of a zone to the
// budget, so density per zone falls as the map grows.
//
// Roadblocks roll in two passes, not one hub-and-spoke, because a spray of blocks all on the BLU HQ -> zone
// lines reads as an arrow pointing home. Pass A is the HQ approach block (HP_ROAD_HQ_P); pass B is an
// inter-zone block (HP_ROAD_NBR_P) to a random zone that is NOT the nearest one, so it can't be read as
// "toward HQ" or as the obvious short hop to the neighbour already beside it -- skipped under 3 zones, where
// no such neighbour exists. No HQ yet -> pass A's endpoint is [] and falls back to a band draw at lay time.
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
    // Observation posts are a per-zone coin flip in the band, not a ring gun -- summed here, laid in their own band pass.
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

    private _fz = if (_zc <= HP_FLANK_KNEE) then { _zc } else { HP_FLANK_KNEE + round ((_zc - HP_FLANK_KNEE) * HP_FLANK_SLOPE) };
    private _lo = floor (_fz / 2);
    private _backline = _lo + floor random (_fz - _lo + 1);
    private _frontline = _lo + floor random (_fz - _lo + 1);
    _total = _total + _backline + _frontline;
    [_zoneCounts, _backline, _frontline, _roadTargets, _obs, _total]
};

// [_zoneKey, _radius] call fnc_hardpoint_debug -> the dev readout for a zone's ring cap (radius + tier
// halves) and how many stand against it. Zone-only -- towns raise no ring. Reads fnc_hardpoint_zone_cap and
// the live registry rather than recomputing, so what it prints matches what OPCOM tops the ring up toward.
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
