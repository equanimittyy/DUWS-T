// Locality: server -- createVehicle and fnc_static_place run where the composition is built and the
// faction globals are authoritative. Definitions only; the callers are the dev spawner now, and the
// zone siting loop and OPCOM later.
//
// A hardpoint is a composition placed onto a heading. The prefabs place their rows at fixed offsets;
// a hardpoint rotates the whole layout about its centre, so a heading turns the cover with the core
// rather than turning the core inside a fixed ring. The prefab split is reused: props are
// ground-snapped, then weapon rows go through fnc_static_place, which resolves the vanilla placeholder
// to _side's own gun and writes the absolute height a weapon row carries.

// [_ox, _oy, _dir] call fnc_hardpoint_rotate -> [x, y] rotated onto heading _dir (clockwise like
// setDir; +Y is the layout's facing). Pure, so the rotation is unit-tested.
fnc_hardpoint_rotate = {
    params ["_ox", "_oy", "_dir"];
    [_ox * cos _dir + _oy * sin _dir, _oy * cos _dir - _ox * sin _dir]
};

// [_type, _pos, _dir, _side, _key] call fnc_hardpoint_build -> [objects]
//   _type  "MG" / "AT" / ... / "MINEFIELD"; the suffix of DUWS_hardpointComp_<type>
//   _pos   [x, y]; the layout centre
//   _dir   heading in degrees the layout faces
//   _side  "opfor" / "blufor"; which faction the guns resolve to
//   _key   composition key the objects are filed under for teardown
//   _variant  "AT" / "AP"; MINEFIELD only, ignored by every other type
fnc_hardpoint_build = {
    params ["_type", "_pos", ["_dir", 0], ["_side", "opfor"], ["_key", "world"], ["_variant", "AT"]];
    private _px = _pos select 0;
    private _py = _pos select 1;

    // The minefield is generated, not composed -- it has no fence to place. -1 dimensions let the
    // generator size the field from the variant's own profile.
    if (_type isEqualTo "MINEFIELD") exitWith {
        [[_px, _py], _dir, _variant, -1, -1, -1, -1, _key] call fnc_hardpoint_minefield
    };

    private _rows = missionNamespace getVariable ["DUWS_hardpointComp_" + _type, []];
    if (_rows isEqualTo []) exitWith {
        ["WARN", "HARDPOINT", format ["no composition for type %1", _type]] call fnc_log;
        []
    };

    private _placed = [];
    // Props first: a weapon row's Z is an absolute height fnc_static_place writes, and the ground pass
    // here would stamp it to terrain like a prop. Props are frozen invulnerable cover, as the prefabs
    // place them -- except the radio mast, left live below; the gun is what the player destroys.
    {
        _x params ["_class", "_ox", "_oy", "_oz", "_rowDir", ["_isWeapon", false]];
        if (_isWeapon) then { continue };
        private _off = [_ox, _oy, _dir] call fnc_hardpoint_rotate;
        private _wp = [_px + (_off select 0), _py + (_off select 1), 0];
        private _obj = createVehicle [_class, _wp, [], 0, "CAN_COLLIDE"];
        [_obj, _key] call fnc_duws_keep;
        _obj setPosATL _wp;
        _obj setDir (_rowDir + _dir);
        // The radio mast alone is left simulated and damageable, so the player clears the tower by
        // destroying it; fnc_hardpoint_stream reads the mast, not the roster. Every other prop stays
        // frozen and invulnerable.
        private _isMast = _type isEqualTo "RADIO" && {_class isEqualTo DUWS_radioMastClass};
        _obj enableSimulationGlobal _isMast;
        _obj allowDamage _isMast;
        _placed pushBack _obj;
    } forEach _rows;

    // Weapons second. fnc_static_place adds the row's own offset to the origin it is handed, so the
    // rotated offset is folded into the origin and the row passed with a zeroed X/Y.
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
// _teamToken names the loose defenders' team in DUWS_teamRosters -- "team" for the regular six, "" for
// none, or an array of tokens for a site fielding several groups -- resolved to classnames here rather
// than passed as a list, so the token is what the site stores and a re-raise draws fresh teams from. The
// emplacement is manned regardless of it: a gun
// without a gunner is scenery, not a defence, so every gun takes a crewman whether or not any loose
// defender does. Side-generic via DUWS_fnc_teamRoster's side prefix and the <side>_SOLDIER_X gun-crew
// global, so the dev tool's OPFOR and BLUFOR spawns each field their own men.
//
// Two kinds of gun, crewed two ways. A static weapon goes through DUWS_fnc_manStatics, the path a
// zone mans its emplacements with -- it thaws the frozen gun, drops it to settle on the ground and
// seats a gunner, because a static is placed frozen and sometimes on a bunker roof. Artillery is a
// vehicle, already sitting on its tracks, so it skips the drop: its gunner is moved straight in and
// the piece is thawed so OPCOM can task it. artilleryScanner is the config flag the faction
// auto-detect reads to call a vehicle artillery, so a modded battery is caught the same way.
//
// The loose garrison patrols close, not dug in: this is the radius fnc_apply_posture works its circuit
// off, kept tight so the men hold the emplacement's approaches rather than roaming the whole zone.
#define HP_GARRISON_PATROL_R 100
fnc_hardpoint_garrison = {
    params ["_objs", "_pos", ["_side", "opfor"], ["_key", "world"], ["_teamToken", ""]];
    private _sideObj = [EAST, WEST] select (_side isEqualTo "blufor");
    private _soldier = missionNamespace getVariable [format ["%1_SOLDIER_X", _side],
        ["O_Soldier_F", "B_Soldier_F"] select (_side isEqualTo "blufor")];
    private _men = [];

    // Static guns first, always crewed: one man per gun, dropped and settled.
    private _guns = _objs select { !isNull _x && {alive _x} && {_x isKindOf "StaticWeapon"} };
    if (count _guns > 0) then {
        private _sp = _pos findEmptyPosition [0, 30, _soldier];
        if (count _sp == 0) then { _sp = _pos };
        private _crew = [_sp, _sideObj, (_guns apply { _soldier }), [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
        _crew deleteGroupWhenEmpty true;
        [_guns, _crew, _key] call DUWS_fnc_manStatics;
        _men append (units _crew);
    };

    // Artillery vehicles: a gunner straight in, no drop, and thawed so the battery can fire.
    private _arty = _objs select { !isNull _x && {alive _x} && {!(_x isKindOf "StaticWeapon")}
        && {getNumber (configFile >> "CfgVehicles" >> typeOf _x >> "artilleryScanner") isEqualTo 1} };
    if (count _arty > 0) then {
        private _sp = _pos findEmptyPosition [0, 30, _soldier];
        if (count _sp == 0) then { _sp = _pos };
        private _crew = [_sp, _sideObj, (_arty apply { _soldier }), [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
        _crew deleteGroupWhenEmpty true;
        {
            _x enableSimulationGlobal true;
            ((units _crew) param [_forEachIndex, objNull]) moveInGunner _x;
        } forEach _arty;
        _men append (units _crew);
    };

    // Then the loose defenders, each on a close patrol around the emplacement rather than dug in -- the
    // gun holds the position while the teams work its approaches. The token is one team or a list of
    // them (a radio tower fields several); an empty or unknown token in the list places no one.
    private _tokens = if (_teamToken isEqualType "") then { [_teamToken] } else { _teamToken };
    {
        private _garrison = [_x, _side] call DUWS_fnc_teamRoster;
        if (count _garrison > 0) then {
            // Spawned out toward the patrol ring, not on the emplacement: at the centre they land among
            // the bunker, bags and gun and snag on them before the circuit can pull them clear. The
            // fallback stays off-centre for the same reason -- a bearing off _pos, never _pos itself.
            private _sp = _pos findEmptyPosition [30, 70, _garrison select 0];
            if (count _sp == 0) then { _sp = _pos getPos [45, random 360] };
            private _grp = [_sp, _sideObj, _garrison, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
            _grp deleteGroupWhenEmpty true;
            [_grp, "closepatrol", _pos, HP_GARRISON_PATROL_R] call fnc_apply_posture;
            _men append (units _grp);
        };
    } forEach _tokens;

    _men
};

// [_type, _pos, _dir, _side, _key] call fnc_hardpoint_spawn -> [objects, men]
//
// Build plus man: the composition, a gunner on every static gun, then the type's loose garrison. The
// garrison is the type's, read from DUWS_hardpointGarrison, so every placer -- the zone loop, the dev
// tool, OPCOM -- fields the same defenders for a type without being told. Sleeps (the drop-and-settle
// in DUWS_fnc_manStatics), so it must run scheduled.
fnc_hardpoint_spawn = {
    params ["_type", "_pos", ["_dir", 0], ["_side", "opfor"], ["_key", "world"], ["_variant", "AT"]];
    private _objs = [_type, _pos, _dir, _side, _key, _variant] call fnc_hardpoint_build;
    private _men = [_objs, _pos, _side, _key, DUWS_hardpointGarrison getOrDefault [_type, ""]] call fnc_hardpoint_garrison;
    [_objs, _men]
};

#define HP_CAP_STEP 250
#define HP_SITE_SPACING 50
#define HP_TYPE_DRAWS 18     // draws spent hunting a spot for one rolled type before it is dropped
#define HP_POOL_ENOUGH 4     // stop drawing once this many viable spots are in hand, then pick among them
#define HP_ROAD_SNAP 120     // roadblock: a draw is pulled to the nearest road within this, else discarded
#define HP_AOI_LOCAL_R 2000  // AoI band pass: the local search radius around each emplacement's anchor

// [_type, _fnCand, _anchor, _rejectInZone] call fnc_hardpoint_best_ground -> [_cand, _facts, _radialDir] | []
//
// Hunt the best ground a single named type can hold. Draw candidates from _fnCand (given _anchor as
// _this), survey each, drop any inside HP_SITE_SPACING of a nest already down, and keep only those the
// type scores above zero on -- LOS and field of fire included, via fnc_hardpoint_score. Stop once a few
// viable spots are in hand or the draw budget (HP_TYPE_DRAWS) is spent, then weighted-pick by score so the
// type's best ground is likeliest without being the only answer. [] when no draw held it.
//
// Roadblock is snapped to a nearby road first (it vetoes off one); _rejectInZone drops a snap that crossed
// into a zone, which the standalone passes want (zone roadblocks sit on the zone's own road) and the zone
// pass does not. Ground only -- no spawn, no registry -- so it is the shared core of both the undirected
// slate roll (fnc_hardpoint_lay) and the directed fnc_hardpoint_spawn_sited.
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
            private _road = [_c, HP_ROAD_SNAP] call BIS_fnc_nearestRoad;
            if (isNull _road) then { continue };
            private _rp = getPosASL _road;
            _c = [_rp select 0, _rp select 1, 0];
            if (_rejectInZone && {[_c] call fnc_aoi_in_any_zone}) then { continue };
        };
        private _f = [_c] call fnc_hardpoint_survey;
        if ((_f select 8) < HP_SITE_SPACING) then { continue };  // spaced off the nests already down
        private _s = [_f, _type] call fnc_hardpoint_score;
        if (_s <= 0) then { continue };  // this ground cannot hold the type
        _pool pushBack [_c, _f, _rdir];
        _pool pushBack _s;
    };
    if (_pool isEqualTo []) exitWith { [] };
    selectRandomWeighted _pool
};

// [_type, _fnCand, _key, _regZoneKey, _anchor, _side] call fnc_hardpoint_spawn_sited -> [_objs, _men] | []
//
// Directed smart-spawn: hunt the best ground a named type can hold among _fnCand's draws (survey + score,
// LOS and field of fire included), face it, spawn it and file it under _key. Returns [] if no draw held
// the type. This is the tail fnc_hardpoint_lay runs per rolled type; a caller that already knows the type
// it wants -- OPCOM reinforcing a specific gap with a specific weapon -- calls here instead of rolling a
// slate. _regZoneKey files the row under a parent zone ("" = standalone, which also gates the roadblock
// snap out of zone interiors). Runs spawned: fnc_hardpoint_spawn sleeps in the crew drop.
fnc_hardpoint_spawn_sited = {
    params ["_type", "_fnCand", "_key", ["_regZoneKey", ""], ["_anchor", []], ["_side", "opfor"]];
    private _best = [_type, _fnCand, _anchor, _regZoneKey isEqualTo ""] call fnc_hardpoint_best_ground;
    if (_best isEqualTo []) exitWith { [] };
    _best params ["_cand", "_facts", "_radialDir"];
    // A roadblock faces along its road; overwatch nests face down the slope they overlook; the rest keep
    // the radial the draw carried.
    private _dir = [_type, _facts select 10, _facts select 11, _radialDir, _facts select 12] call fnc_hardpoint_facing;
    private _res = [_type, _cand, _dir, _side, _key] call fnc_hardpoint_spawn;
    [_key, _type, _cand, _res select 1, _side, _regZoneKey, _dir] call fnc_hardpoint_register;
    _res
};

// [_count, _keyPrefix, _regZoneKey, _fnCand] call fnc_hardpoint_lay -> hardpoints placed.
//
// The shared placement loop behind both the zone pass and the AoI band pass: they differ only in
// where a candidate comes from, so that is the one thing passed in. _fnCand is code returning
// [_pos, _radialDir] for a draw, or [] to skip it (an off-band or in-zone sample). _fnReset, if given,
// is called once per emplacement before its draws and its result is handed to every _fnCand call as
// _this: the AoI pass uses it to fix one local search anchor per hardpoint, so the draws stay in a
// single neighbourhood the survey can compare. The zone pass omits it (anchor []) and ignores _this.
//
// Type first, ground second. The whole slate of types is rolled up front from the pass's weight map
// (the zone or standalone DUWS_hardpointWeight*, picked by _regZoneKey below) -- MG common, AA and
// roadblock rarer -- so the realised mix is the weights, not what the terrain favours. Each rolled type
// is then handed to fnc_hardpoint_spawn_sited, which hunts and scores the best ground it can hold
// (fnc_hardpoint_best_ground) and places it, so terrain decides only WHERE a type lands, never WHICH is
// placed. The old order did the reverse -- pick the best-scoring spot, then roll a type there -- which
// let high ground (that MG and AT score huge on) win nearly every site and starved the flat-ground type
// (AA) and the road-gated one (roadblock). A type that finds no ground in its draw budget is dropped and
// logged, never swapped for another -- swapping is the terrain skew this order removes. OPs, minefields
// and the fire-support types are in no map, OPCOM's to place, never rolled here. _radialDir is the outward
// "toward the approach" bearing fnc_hardpoint_facing hands the flat types, while the overwatch nests
// face their own fall line. _regZoneKey files each row under a parent zone ("" = standalone). Every
// emplacement carries the type's own garrison from fnc_hardpoint_spawn on top of any gun's crew.
//
// _fnTick, if given, is called with the running placed count after each placement -- a batch pass with
// no per-zone sub-unit to report between (the AoI band) can still tick the generation banner.
//
// Runs spawned: fnc_hardpoint_spawn sleeps in the crew drop, so build-out cannot call it inline.
fnc_hardpoint_lay = {
    params ["_count", "_keyPrefix", "_regZoneKey", "_fnCand", ["_fnTick", {}], ["_fnReset", {[]}]];
    // Zone rings and standalone emplacements roll different type mixes: the map's keys are the roll set,
    // its values the base weights. Standalone ground (the AoI band, OPCOM's solo builds) fields AA and
    // more roadblocks; a zone's ring does not. The zoneKey is the discriminator already threaded here.
    private _weights = if (_regZoneKey isEqualTo "") then { DUWS_hardpointWeightSolo } else { DUWS_hardpointWeightZone };
    // Flattened [type, weight, ...] for selectRandomWeighted; the roll reads base weight alone, no ground.
    private _typeRoll = [];
    { _typeRoll pushBack _x; _typeRoll pushBack (_weights get _x) } forEach (keys _weights);
    // The whole slate of types up front, before any terrain is read, so the realised mix is the weights.
    private _slate = [];
    for "_i" from 1 to _count do { _slate pushBack (selectRandomWeighted _typeRoll) };

    private _placed = 0;
    private _tally = createHashMap;
    {
        private _type = _x;
        // One anchor per emplacement: the AoI pass fixes a local search neighbourhood here; other passes
        // return [] and their candidate blocks ignore it. The hunt, facing and spawn are
        // fnc_hardpoint_spawn_sited; this loop only rolls the type, keys it and tallies what landed. The
        // key is formed from the running placed count, so a dropped type consumes no index.
        private _anchor = call _fnReset;
        private _key = format ["%1_%2", _keyPrefix, _placed];
        private _res = [_type, _fnCand, _key, _regZoneKey, _anchor] call fnc_hardpoint_spawn_sited;
        if (_res isEqualTo []) then {
            // No ground for this type in the draw budget -- dropped, not swapped: a swap is the terrain
            // skew the type-first order removes. A roadblock in roadless country is the usual cause.
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

// [_zonePos] call fnc_hardpoint_threat_bearing -> a compass bearing to bias a zone's depth emplacements
// toward: the mean direction from the zone to BLU HQ (once placed) and the nearest two other zones -- the
// corridors a front forms along. Averaged as unit vectors so bearings blend rather than arithmetic-mean
// (which wraps wrong across 0/360). Random when there is nothing to key on (no HQ, one lone zone) or the
// bearings cancel, so a degenerate map still places depth, just uniformly.
fnc_hardpoint_threat_bearing = {
    params ["_zonePos"];
    private _bearings = [];
    if !(PosOfBLUHQ isEqualTo []) then { _bearings pushBack (_zonePos getDir PosOfBLUHQ) };
    private _others = (zone_meta_array apply { _x select 1 }) select { (_x distance2D _zonePos) > 1 };
    _others = [_others, [], { _x distance2D _zonePos }, "ASCEND"] call BIS_fnc_sortBy;
    { _bearings pushBack (_zonePos getDir _x) } forEach (_others select [0, 2]);
    if (_bearings isEqualTo []) exitWith { random 360 };
    private _bx = 0;
    private _by = 0;
    { _bx = _bx + sin _x; _by = _by + cos _x } forEach _bearings;
    if (_bx == 0 && {_by == 0}) exitWith { random 360 };
    _bx atan2 _by
};

// [_zonePos, _radius, _zoneKey, _count, _fnTick, _depth] call fnc_hardpoint_site_zone
//
// A zone's deliberate emplacements, replacing the old random fortification ring. The zone's radius caps
// how many it can hold (bigger zone, more ground and room to cover it); a random ring count up to that
// cap is laid at campaign start, then _depth (1-2) more as defence in depth. The stored cap is the ring
// cap plus the depth, so OPCOM tops the whole set back up toward it later.
//
// The ring is drawn from anywhere in the zone, faced radially out. The depth positions are biased toward
// the threat bearing -- BLU HQ and the nearest zones, where the player will push from -- within a ~120 deg
// arc at mid-to-outer radius, so the zone reads as layered toward the fight. A bias, not a front: OPFOR
// has no intel at hour zero, so the ring still rings the whole zone and the depth only leans.
//
// Idempotent per zone -- the stored cap is the guard -- so a rebuild through fnc_createZone lays no second
// set. Runs spawned, via fnc_hardpoint_lay's crew drop. _fnTick climbs the generation banner per gun; the
// depth pass offsets it past the ring's plan so the count does not jump backwards between the two.
fnc_hardpoint_site_zone = {
    params ["_zonePos", "_radius", "_zoneKey", ["_count", -1], ["_fnTick", {}], ["_depth", -1]];
    if (!isNil { missionNamespace getVariable (format ["DUWS_hpCap_%1", _zoneKey]) }) exitWith {};
    private _cap = (round (_radius / HP_CAP_STEP)) max 1;
    // Counts arrive pre-rolled from fnc_hardpoint_plan_counts so the banner can total every emplacement up
    // front; a standalone call (no plan) rolls its own against the cap.
    if (_count < 0) then { _count = round (random _cap) };
    if (_depth < 0) then { _depth = 1 + floor random 2 };
    // Ceiling includes the depth, so a cleared depth emplacement is topped up like a ring one.
    missionNamespace setVariable [format ["DUWS_hpCap_%1", _zoneKey], _cap + _depth];

    private _placed = 0;
    if (_count > 0) then {
        _placed = [_count, format ["hp_%1", _zoneKey], _zoneKey, {
            private _c = [_zonePos, 0, _radius, 6, 0, 0.35, 0] call BIS_fnc_findSafePos;
            [_c, _zonePos getDir _c]
        }, _fnTick] call fnc_hardpoint_lay;
    };

    // Depth pass: draw into a wedge toward the threat bearing, at mid-to-outer radius. _realTick and
    // _ringN are captured under names fnc_hardpoint_lay does not use: the wrapper runs inside lay's scope,
    // where _fnTick already means the wrapper itself (referencing it would recurse) and _count already
    // means lay's own count (the depth count, not this ring's) -- so both must be aliased out here.
    private _depthPlaced = 0;
    if (_depth > 0) then {
        private _threat = [_zonePos] call fnc_hardpoint_threat_bearing;
        private _realTick = _fnTick;
        private _ringN = _count;
        private _depthTick = { (_this + _ringN) call _realTick };
        _depthPlaced = [_depth, format ["hpd_%1", _zoneKey], _zoneKey, {
            private _ang = _threat + (random 120) - 60;
            private _bp = _zonePos getPos [_radius * (0.4 + random 0.6), _ang];
            private _c = [_bp, 0, _radius * 0.35, 6, 0, 0.35, 0] call BIS_fnc_findSafePos;
            [_c, _zonePos getDir _c]
        }, _depthTick] call fnc_hardpoint_lay;
    };

    ["INFO", "HARDPOINT", format ["%1 sited %2/%3 ring + %4/%5 depth (cap %6)",
        _zoneKey, _placed, _count, _depthPlaced, _depth, _cap + _depth]] call fnc_log;
};

// The band pass's local-search sampler, shared by the campaign-start pass and OPCOM's band build so
// both hunt ground the same cheap way: one fixed anchor per emplacement, then draws confined to its
// neighbourhood rather than scattered across every zone's band.
//
// [] call fnc_hardpoint_band_anchor -> [_pos, _radialDir, _zoneCentre] or []. One valid in-band
// anchor; bandPos returns [] on a missed draw, so retry a handful of times rather than dropping the
// whole hardpoint to a single unlucky roll. Handed to fnc_hardpoint_lay as its per-emplacement reset.
fnc_hardpoint_band_anchor = {
    private _a = [];
    for "_i" from 1 to 8 do { _a = call DUWS_fnc_aoi_bandPos; if !(_a isEqualTo []) exitWith {} };
    _a
};

// _anchor call fnc_hardpoint_band_cand -> [_pos, _radialDir] or []. A draw within HP_AOI_LOCAL_R of
// the anchor, gated like the band (OPFOR-positive, outside every zone) and faced outward from the
// anchor's source zone. _this is the anchor fnc_hardpoint_lay carries in from the reset above; a
// missed or in-zone sample returns [] to skip.
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

// [] call fnc_hardpoint_site_aoi
//
// The campaign-start band pass: `x` standalone combat hardpoints spread through the OPFOR-positive
// area of influence, `x = count serv_zones_array` (the authoritative post-generation count). Anchors
// are drawn uniformly across the band via fnc_hardpoint_band_anchor/_cand -- the war has not started,
// so there is no front to weight toward and no intel to act on; where the enemy fortifies with intent
// is OPCOM's later builds, not hour zero.
//
// Runs spawned, like the zone pass: fnc_hardpoint_spawn sleeps in the crew drop.
fnc_hardpoint_site_aoi = {
    params [["_fnTick", {}]];
    private _count = count serv_zones_array;
    if (_count <= 0) exitWith {};
    private _placed = [_count, "hpaoi", "", fnc_hardpoint_band_cand, _fnTick, fnc_hardpoint_band_anchor] call fnc_hardpoint_lay;
    ["INFO", "HARDPOINT", format ["AoI band pass sited %1/%2 standalone hardpoints", _placed, _count]] call fnc_log;
};

// [_n] call fnc_hardpoint_seed_radio -> radio towers placed.
//
// Stands _n OPFOR radio towers in the band. A tower is placed deliberately, so this does not roll a
// type through fnc_hardpoint_lay: for each mast it samples a pool of band positions from
// DUWS_fnc_aoi_bandPos, drops any inside another tower's AoI or too close to an emplacement, and
// stands the "RADIO" hardpoint on the best-scoring hilltop of what survives -- so masts neither share
// ground nor nest coverage, and each crowns the highest crest in its pool. Each
// raises DUWS_opforRadioLevel through fnc_hardpoint_register's recount and projects AOI_TOWER_REACH of
// coverage. A global sequence keys the towers, so a campaign-start seed and OPCOM's later raises never
// collide. Runs spawned: fnc_hardpoint_spawn sleeps in the crew drop.
#define HP_RADIO_SPACING 250
#define HP_RADIO_SAMPLES 6
fnc_hardpoint_seed_radio = {
    params [["_n", 2], ["_fnTick", {}]];
    private _placed = 0;
    private _tries = 0;
    while { _placed < _n && {_tries < _n * 12} } do {
        _tries = _tries + 1;

        // Stand the mast on the best hilltop in a sampled pool, not the first band draw that clears: a
        // tower wants a crest that reaches. Each candidate is surveyed once (the survey serves both the
        // spacing gate and the RADIO score), and the top spot is kept. A draw inside another tower's AoI
        // -- within AOI_TOWER_REACH of a standing RADIO, checked live so nested coverage never forms --
        // or too close to an emplacement is dropped before scoring.
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
        (["RADIO", _c, _rdir, "opfor", _key] call fnc_hardpoint_spawn) params ["_objs", "_men"];
        [_key, "RADIO", _c, _men, "opfor", "", _rdir] call fnc_hardpoint_register;
        _placed = _placed + 1;
        _placed call _fnTick;
    };
    ["INFO", "HARDPOINT", format ["seeded %1/%2 OPFOR radio towers", _placed, _n]] call fnc_log;
};

// [_radioN] call fnc_hardpoint_plan_counts -> [_zoneCounts, _depthCounts, _total]
//
// Rolls every campaign-start emplacement before any is laid, so the generation banner totals real
// hardpoints (zone ring + depth + band) up front instead of counting zones. Per-zone ring count is
// round(random cap) under the same radius cap fnc_hardpoint_site_zone stores; the depth count is a flat
// 1-2. Both are returned so that pass lays the same numbers this total promised; the band adds count
// serv_zones_array plus the radio count, which the caller rolls (fnc_hardpoint_seed_radio must be handed
// the same value). Here, not in WARCOM init, so the cap formula is not duplicated away from HP_CAP_STEP.
fnc_hardpoint_plan_counts = {
    params ["_radioN"];
    private _zoneCounts = [];
    private _depthCounts = [];
    private _total = (count serv_zones_array) + _radioN;
    {
        _x params ["", "", "_hpSize"];
        private _cap = (round (_hpSize / HP_CAP_STEP)) max 1;
        private _n = round (random _cap);
        private _d = 1 + floor random 2;
        _zoneCounts pushBack _n;
        _depthCounts pushBack _d;
        _total = _total + _n + _d;
    } forEach zone_meta_array;
    [_zoneCounts, _depthCounts, _total]
};
