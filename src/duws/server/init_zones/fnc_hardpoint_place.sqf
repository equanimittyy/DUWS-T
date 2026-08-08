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

// [_count, _keyPrefix, _regZoneKey, _fnCand, _fnTick, _fnReset, _weights] call fnc_hardpoint_lay -> hardpoints placed.
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
    params ["_count", "_keyPrefix", "_regZoneKey", "_fnCand", ["_fnTick", {}], ["_fnReset", {[]}], ["_weights", []]];
    // Zone rings and standalone emplacements roll different type mixes: the map's keys are the roll set,
    // its values the base weights. Standalone ground (the AoI band, OPCOM's solo builds) fields AA and
    // more roadblocks; a zone's ring does not. The zoneKey is the discriminator already threaded here.
    // A scenario pass (a flank line, the AA net, the roadblock net) hands its own single-purpose map and
    // skips that choice; [] means "unset, pick by zoneKey" for the callers that do not care.
    if (_weights isEqualTo []) then {
        _weights = if (_regZoneKey isEqualTo "") then { DUWS_hardpointWeightSolo } else { DUWS_hardpointWeightZone };
    };
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

// [_zonePos] call fnc_hardpoint_threat_bearing -> a compass bearing to bias a zone's flank emplacements
// toward: the mean direction from the zone to BLU HQ (once placed) and the nearest two other zones -- the
// corridors a front forms along. The frontline leans into this bearing, the backline into its reverse.
// Averaged as unit vectors so bearings blend rather than arithmetic-mean
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

// [_zonePos, _radius, _zoneKey, _count, _fnTick] call fnc_hardpoint_site_zone
//
// A zone's own fortification ring, drawn from anywhere in the zone and faced radially out. The zone's
// radius caps how many it can hold (bigger zone, more ground and room to cover it); a random count up to
// that cap is laid at campaign start, and the cap is stored so OPCOM tops the ring back up toward it later.
// The layered defence around the zone -- nests leaning toward and away from the fight -- is the flank
// passes' job now (fnc_hardpoint_site_flank), spread across the map rather than ringed per zone.
//
// Idempotent per zone -- the stored cap is the guard -- so a rebuild through fnc_createZone lays no second
// set. Runs spawned, via fnc_hardpoint_lay's crew drop. _fnTick climbs the generation banner per gun.
fnc_hardpoint_site_zone = {
    params ["_zonePos", "_radius", "_zoneKey", ["_count", -1], ["_fnTick", {}]];
    if (!isNil { missionNamespace getVariable (format ["DUWS_hpCap_%1", _zoneKey]) }) exitWith {};
    private _cap = (round (_radius / HP_CAP_STEP)) max 1;
    // The count arrives pre-rolled from fnc_hardpoint_plan_counts so the banner can total every emplacement
    // up front; a standalone call (no plan) rolls its own against the cap.
    if (_count < 0) then { _count = round (random _cap) };
    missionNamespace setVariable [format ["DUWS_hpCap_%1", _zoneKey], _cap];

    private _placed = 0;
    if (_count > 0) then {
        _placed = [_count, format ["hp_%1", _zoneKey], _zoneKey, {
            private _c = [_zonePos, 0, _radius, 6, 0, 0.35, 0] call BIS_fnc_findSafePos;
            [_c, _zonePos getDir _c]
        }, _fnTick] call fnc_hardpoint_lay;
    };

    ["INFO", "HARDPOINT", format ["%1 sited %2/%3 ring (cap %4)", _zoneKey, _placed, _count, _cap]] call fnc_log;
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

// [_count, _toHQ, _fnTick] call fnc_hardpoint_site_flank -> emplacements placed.
//
// A flank line of gun nests (MG/AT/GMG, DUWS_hardpointWeightNest) anchored to the zones but standing
// outside their rings, on one side of the fight. _toHQ true is the frontline -- offset toward the threat
// bearing (BLU HQ and the nearest zones, where the player pushes from) and faced at HQ, so a flat-ground
// nest points down the approach the player drives in on; a real slope still wins the fall line, overwatch
// beating a nominal bearing (fnc_hardpoint_facing). _toHQ false is the backline -- the far side, threat
// bearing reversed, faced radially out. Each emplacement draws a fresh random zone, so the count spreads
// across the map rather than ringing one zone. Standalone rows ("") -- these are AoI emplacements keyed to
// a zone's geometry, not part of its own ring cap, so a cleared one is not something OPCOM tops the zone up
// for. Runs spawned, like the zone pass: fnc_hardpoint_spawn sleeps in the crew drop.
//
// _toHQ is read from this scope by the reset and candidate blocks below -- they run inside fnc_hardpoint_lay
// but resolve it up the call stack (SQF dynamic scope), so it need not be threaded through lay's params.
fnc_hardpoint_site_flank = {
    params ["_count", "_toHQ", ["_fnTick", {}]];
    if (_count <= 0) exitWith { 0 };
    if (zone_meta_array isEqualTo []) exitWith { 0 };
    private _prefix = ["hpback", "hpfront"] select _toHQ;
    private _placed = [_count, _prefix, "", {
        // _this is the reset's anchor: [zoneCentre, radius, bearing].
        _this params ["_zc", "_zr", "_bearing"];
        // Frontline hugs the ring's edge on the HQ side (0.9-1.3 R); backline stands further out on the
        // far side (1.0-1.6 R), a deeper second line. A wedge, not a point, so the line reads scattered.
        private _base = [1.0, 0.9] select _toHQ;
        private _span = [0.6, 0.4] select _toHQ;
        private _ang = _bearing + (random 90) - 45;
        private _bp = _zc getPos [_zr * (_base + random _span), _ang];
        private _c = [_bp, 0, _zr * 0.4, 6, 0, 0.35, 0] call BIS_fnc_findSafePos;
        // Frontline prefers to face HQ (radial = candidate -> HQ, which the facing keeps on flat ground);
        // backline faces radially out from its zone. No HQ yet placed falls back to the zone radial.
        private _rdir = if (_toHQ && {!(PosOfBLUHQ isEqualTo [])}) then { _c getDir PosOfBLUHQ } else { _zc getDir _c };
        [_c, _rdir]
    }, _fnTick, {
        (selectRandom zone_meta_array) params ["", "_azc", "_azr"];
        private _b = [_azc] call fnc_hardpoint_threat_bearing;
        if (!_toHQ) then { _b = _b + 180 };
        [_azc, _azr, _b]
    }, DUWS_hardpointWeightNest] call fnc_hardpoint_lay;
    ["INFO", "HARDPOINT", format ["%1 line sited %2/%3 nests", _prefix, _placed, _count]] call fnc_log;
    _placed
};

// [_count, _fnTick] call fnc_hardpoint_site_roadblocks -> roadblocks placed.
//
// Roadblocks spread two ways, chosen per block: on the approaches the player drives in on (a point sampled
// along the line from BLU HQ to a random zone) and at large across the OPFOR band. Either way the block is
// a raw draw; fnc_hardpoint_best_ground snaps it to the nearest road and (standalone "") rejects a snap
// that crossed into a zone, so the block sits on an open road, not a zone interior. A corridor is only
// chosen when both HQ and a zone exist; otherwise the block falls back to a band draw. Standalone rows.
// Runs spawned: fnc_hardpoint_spawn sleeps in the crew drop.
fnc_hardpoint_site_roadblocks = {
    params ["_count", ["_fnTick", {}]];
    if (_count <= 0) exitWith { 0 };
    private _placed = [_count, "hproad", "", {
        // _this is the reset's anchor: ["corridor", zoneCentre] or ["band", bandAnchor].
        _this params ["_mode", "_ref"];
        if (_mode isEqualTo "corridor") exitWith {
            private _f = 0.3 + random 0.6;
            private _hx = PosOfBLUHQ select 0;
            private _hy = PosOfBLUHQ select 1;
            private _p = [_hx + ((_ref select 0) - _hx) * _f, _hy + ((_ref select 1) - _hy) * _f, 0];
            private _c = [_p, 0, HP_ROAD_SNAP, 6, 0, 0.35, 0] call BIS_fnc_findSafePos;
            [_c, 0]  // heading is the road's, resolved by fnc_hardpoint_facing after the snap
        };
        _ref call fnc_hardpoint_band_cand
    }, _fnTick, {
        // Half the blocks aim at a corridor when there is one to aim at; the rest go to the band.
        if (random 1 < 0.5 && {!(PosOfBLUHQ isEqualTo [])} && {!(zone_meta_array isEqualTo [])}) exitWith {
            ["corridor", (selectRandom zone_meta_array) select 1]
        };
        ["band", call fnc_hardpoint_band_anchor]
    }, createHashMapFromArray [["ROADBLOCK", 1]]] call fnc_hardpoint_lay;
    ["INFO", "HARDPOINT", format ["roadblock pass sited %1/%2", _placed, _count]] call fnc_log;
    _placed
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

// [_radioN] call fnc_hardpoint_plan_counts -> [_zoneCounts, _backline, _frontline, _total]
//
// Rolls every campaign-start emplacement before any is laid, so the generation banner totals real
// hardpoints up front instead of counting zones. The six scenarios: per-zone ring (round(random cap)
// under the same radius cap fnc_hardpoint_site_zone stores, returned so that pass lays the same numbers);
// the two flank lines (each a random count between half the zones and all of them); radio (rolled by the
// caller and passed in, since the seed call must be handed the same value); and the AA and roadblock nets,
// each a flat count serv_zones_array the caller derives. The rolled numbers are returned; the deterministic
// ones (radio, AA, roadblocks) are only summed into the total. Here, not in WARCOM init, so the cap and
// count-range formulas are not duplicated away from HP_CAP_STEP.
fnc_hardpoint_plan_counts = {
    params ["_radioN"];
    private _zc = count serv_zones_array;
    private _zoneCounts = [];
    // Radio + AA (_zc) + roadblocks (_zc) are the deterministic passes; sum them straight in.
    private _total = _radioN + _zc + _zc;
    {
        _x params ["", "", "_hpSize"];
        private _cap = (round (_hpSize / HP_CAP_STEP)) max 1;
        private _n = round (random _cap);
        _zoneCounts pushBack _n;
        _total = _total + _n;
    } forEach zone_meta_array;
    // Each flank line: a random count between half the zones (floored) and all of them.
    private _lo = floor (_zc / 2);
    private _backline = _lo + floor random (_zc - _lo + 1);
    private _frontline = _lo + floor random (_zc - _lo + 1);
    _total = _total + _backline + _frontline;
    [_zoneCounts, _backline, _frontline, _total]
};
