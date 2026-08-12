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

    private _rows = [_type] call fnc_hardpoint_comp;
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
// _looseOnly skips the gun and artillery crewing and places only the loose defenders. A resident battery
// (mortar, artillery) keeps its crew pinned on the pieces across a garrison stow, so the raise that brings
// its defenders back must not re-crew guns that were never emptied. The battery files crew and loose men
// under separate site rosters (crew on a driven occupant, loose on the streamed one), so a garrison stow
// collects the loose roster through fnc_site_collect and never reaches the crew.
#define HP_GARRISON_PATROL_R 100
fnc_hardpoint_garrison = {
    params ["_objs", "_pos", ["_side", "opfor"], ["_key", "world"], ["_teamToken", ""], ["_looseOnly", false]];
    private _sideObj = [EAST, WEST] select (_side isEqualTo "blufor");
    private _soldier = missionNamespace getVariable [format ["%1_SOLDIER_X", _side],
        ["O_Soldier_F", "B_Soldier_F"] select (_side isEqualTo "blufor")];
    private _men = [];

    // Emplacement defenders must actually see the player. spawnGroup's overall-skill roll leaves spotting
    // to the difficulty curve, which reads low enough here that a nest gets walked up on before it reacts.
    // Force max detection (distance + reaction) on every defender; aiming stays on the skill roll, so they
    // spot without becoming an aimbot.
    private _maxSpot = { { _x setSkill ["spotDistance", 1]; _x setSkill ["spotTime", 1] } forEach _this };

    // Static guns first, always crewed: one man per gun, dropped and settled.
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

    // Artillery vehicles: a gunner straight in, no drop, and thawed so the battery can fire.
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

    // Then the loose defenders. Each holds the posture its token names (DUWS_fnc_tokenPosture): a bare
    // token defaults to a close patrol around the emplacement -- the gun holds the position while the
    // teams work its approaches -- and a posture-prefixed token (widepatrol:team) screens wider instead.
    // The token is one team or a list of them (a radio tower fields several); an empty or unknown token
    // in the list places no one.
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
            (units _grp) call _maxSpot;
            [_grp, [_x] call DUWS_fnc_tokenPosture, _pos, HP_GARRISON_PATROL_R] call fnc_apply_posture;
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
        if ((_f select 8) < HP_SITE_SPACING) then { continue };  // spaced off the nests already down
        private _s = [_f, _type] call fnc_hardpoint_score;
        if (_s <= 0) then { continue };  // this ground cannot hold the type
        _pool pushBack [_c, _f, _rdir];
        _pool pushBack _s;
    };
    if (_pool isEqualTo []) exitWith { [] };
    selectRandomWeighted _pool
};

// [_type, _fnCand, _key, _regZoneKey, _anchor, _side] call fnc_hardpoint_spawn_sited -> [_objs, []] | []
//
// Directed smart-spawn: hunt the best ground a named type can hold among _fnCand's draws (survey + score,
// LOS and field of fire included), face it, build it and file it under _key. Returns [] if no draw held
// the type. This is the tail fnc_hardpoint_lay runs per rolled type; a caller that already knows the type
// it wants -- OPCOM reinforcing a specific gap with a specific weapon -- calls here instead of rolling a
// slate. _regZoneKey files the row under a parent zone ("" = standalone, which also gates the roadblock
// snap out of zone interiors).
//
// Build, then register -- register decides whether to crew now or stow: a hardpoint out of a player's reach
// is stowed uncrewed and only re-crewed when someone approaches, so campaign start never pays the
// drop-and-settle for emplacements nobody is near. Runs spawned: register sleeps in the crew drop when it
// does crew one inline.
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
// emplacement carries the type's own garrison, fielded by fnc_hardpoint_register when it crews (or by the
// raise that later crews it), on top of any gun's crew.
//
// _fnTick, if given, is called with the running placed count after each placement -- a batch pass with
// no per-zone sub-unit to report between (the AoI band) can still tick the generation banner.
//
// Runs spawned: fnc_hardpoint_register sleeps in the crew drop when it crews one inline, so build-out
// cannot call it inline.
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

// The band anchors a flank emplacement samples before keeping the one the flank wants; a lean toward HQ,
// not a hard cut, so nests still scatter through the band rather than lining one contour.
#define HP_FLANK_SAMPLES 5

// [_count, _toHQ, _fnTick] call fnc_hardpoint_site_flank -> emplacements placed.
//
// A flank line of gun nests (MG/AT/GMG, DUWS_hardpointWeightNest) spread through the OPFOR band and weighted
// by distance to BLU HQ, not tied to any one zone -- the same band the roadblock and AA nets draw from.
// _toHQ true is the frontline -- biased toward the HQ side of the band (the forward positions facing where
// the player pushes from) and faced at HQ, so a flat-ground nest points down the approach; a real slope
// still wins the fall line (fnc_hardpoint_facing). _toHQ false is the backline -- biased to the far side,
// faced away from HQ. The bias is a sampled lean: each emplacement draws HP_FLANK_SAMPLES band anchors and
// keeps the one nearest (front) or farthest (back) from HQ, then hunts ground around it like the AoI band
// pass. No HQ placed yet leaves nothing to weight toward, so it falls back to a plain band anchor.
// Standalone rows ("") -- band emplacements, not part of any zone's ring cap. Runs spawned:
// fnc_hardpoint_register sleeps in the crew drop when it crews one inline.
//
// _toHQ is read from this scope by the reset and candidate blocks below -- they run inside fnc_hardpoint_lay
// but resolve it up the call stack (SQF dynamic scope), so it need not be threaded through lay's params.
fnc_hardpoint_site_flank = {
    params ["_count", "_toHQ", ["_fnTick", {}]];
    if (_count <= 0) exitWith { 0 };
    private _prefix = ["hpback", "hpfront"] select _toHQ;
    private _placed = [_count, _prefix, "", {
        // _this is the reset's HQ-weighted band anchor. band_cand hunts a local draw and gates it
        // (OPFOR-positive, outside zones); only its outward facing is swapped for one keyed to HQ.
        private _d = _this call fnc_hardpoint_band_cand;
        if (_d isEqualTo []) exitWith { [] };
        _d params ["_c"];
        // Frontline faces HQ (kept on flat ground by fnc_hardpoint_facing); backline faces away. No HQ yet
        // keeps the band's own outward radial.
        private _rdir = if (PosOfBLUHQ isEqualTo []) then { _d select 1 }
            else { [PosOfBLUHQ getDir _c, _c getDir PosOfBLUHQ] select _toHQ };
        [_c, _rdir]
    }, _fnTick, {
        // Sample a handful of band anchors and keep the one the flank wants: nearest HQ for the frontline,
        // farthest for the backline. No HQ to weight toward -> the first plain band anchor.
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
// Lays the roadblock net rolled in fnc_hardpoint_plan_counts. Each target is [zonePos, endpointPos]: a block
// is a point along endpoint -> zone at a random depth, kept only where the OPFOR field is positive so it
// never lands in friendly ground. fnc_hardpoint_best_ground snaps the draw to a road (main road preferred)
// and rejects a snap that crossed into a zone, so the block sits on an open road, not a zone interior; each
// then faces back along that road toward its endpoint -- HQ for the approach pass, the neighbour zone for the
// inter-zone pass -- so its guns cover the way through. Endpoint [] (no HQ at plan time) -> a plain band draw
// near the zone so the pass still lays. Standalone rows ("").
//
// One lay call over the whole pre-expanded target list, so the generation banner climbs unbroken: the
// per-emplacement reset hands out the next target, and a dropped block (no road it can hold) still consumes
// its target so the banner total stays honest. Runs spawned: fnc_hardpoint_register sleeps in the crew drop
// when it crews one inline.
fnc_hardpoint_site_roadblocks = {
    params ["_roadTargets", ["_fnTick", {}]];
    private _count = count _roadTargets;
    if (_count <= 0) exitWith { 0 };
    private _idx = 0;
    private _placed = [_count, "hproad", "", {
        // _this is the reset's assigned [zonePos, endpointPos]. Draw along endpoint -> zone at a random depth
        // and keep it only in OPFOR-held ground; best_ground then snaps it to a road and faces it back toward
        // the endpoint. No endpoint (no HQ at plan time) -> a band draw near the zone.
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
        if (([_c] call fnc_aoi_field_at) <= 0) exitWith { [] };  // OPFOR-held approach only
        [_c, _c getDir _epos]  // face back toward the endpoint; facing snaps to the road heading nearer it
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
// Stands _n OPFOR radio towers in the band. A tower is placed deliberately, so this does not roll a
// type through fnc_hardpoint_lay: for each mast it samples a pool of band positions from
// DUWS_fnc_aoi_bandPos, drops any inside another tower's AoI or too close to an emplacement, and
// stands the "RADIO" hardpoint on the best-scoring hilltop of what survives -- so masts neither share
// ground nor nest coverage, and each crowns the highest crest in its pool. Each
// raises DUWS_opforRadioLevel through fnc_hardpoint_register's recount and projects AOI_TOWER_REACH of
// coverage. A global sequence keys the towers, so a campaign-start seed and OPCOM's later raises never
// collide. Runs spawned: fnc_hardpoint_register sleeps in the crew drop when it crews one inline.
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
        ["RADIO", _c, _rdir, "opfor", _key] call fnc_hardpoint_build;
        [_key, "RADIO", _c, "opfor", "", _rdir] call fnc_hardpoint_register;
        _placed = _placed + 1;
        _placed call _fnTick;
    };
    ["INFO", "HARDPOINT", format ["seeded %1/%2 OPFOR radio towers", _placed, _n]] call fnc_log;
};

// [_radioN] call fnc_hardpoint_plan_counts -> [_zoneCounts, _backline, _frontline, _roadTargets, _total]
//
// Rolls every campaign-start emplacement before any is laid, so the generation banner totals real
// hardpoints up front instead of counting zones. The passes: per-zone ring (round(random cap) under the
// same radius cap fnc_hardpoint_site_zone stores, returned so that pass lays the same numbers); the
// roadblock net (two passes, below); the two flank lines; radio (rolled by the caller and passed in, since
// the seed call must be handed the same value); and the AA net (one per zone, derived by the caller). Radio
// and AA are only summed into the total. Here, not in WARCOM init, so the count formulas are not duplicated
// away from HP_CAP_STEP.
//
// Flank throttle: gun nests offset from the zones matter most on a small map, where a zone stands alone and
// its flanks are open. As zones multiply they screen each other, so the same per-zone flank density just
// carpets the countryside. Below HP_FLANK_KNEE the flank lines track the zone count exactly (a 4-6 zone game
// is unchanged); above it each extra zone adds only HP_FLANK_SLOPE of a zone to the flank budget, so density
// per zone falls as the map grows. Rings and AA are left per-zone, untouched here.
//
// Roadblocks in two passes, not one hub-and-spoke: a spray of blocks all sat on the BLU HQ -> zone lines
// reads as an arrow pointing home. Pass A places the approach block with probability HP_ROAD_HQ_P (faced at
// HQ); pass B places an inter-zone block with probability HP_ROAD_NBR_P on the line to a random zone that is
// NOT the nearest one -- a longer, off-axis link the player cannot read as "toward HQ". The nearest zone is
// excluded so the link is not the obvious short hop to the neighbour already beside it; under 3 zones no such
// neighbour exists, so pass B is skipped. Each block is handed to fnc_hardpoint_site_roadblocks as a
// [zonePos, endpointPos] target, drawn along endpoint -> zone and faced at the endpoint, so pass A faces HQ
// and pass B faces its neighbour. No HQ yet -> pass A's endpoint is [] and that block falls back to a band
// draw. The list is returned so the banner totals real blocks; the HP_ROAD_HQ_P + HP_ROAD_NBR_P per-zone
// rates land the net at ~1.2x zones, at most one block per pass.
#define HP_FLANK_KNEE 6
#define HP_FLANK_SLOPE 0.5
#define HP_ROAD_HQ_P 0.8    // per-zone chance of an HQ approach roadblock
#define HP_ROAD_NBR_P 0.4   // per-zone chance of an off-axis inter-zone roadblock
fnc_hardpoint_plan_counts = {
    params ["_radioN"];
    private _zc = count serv_zones_array;
    private _zoneCounts = [];
    private _roadTargets = [];
    // Radio + AA (_zc) are the deterministic passes; sum them straight in. Rings roll per zone below.
    private _total = _radioN + _zc;
    {
        _x params ["", "", "_hpSize"];
        private _cap = (round (_hpSize / HP_CAP_STEP)) max 1;
        private _n = round (random _cap);
        _zoneCounts pushBack _n;
        _total = _total + _n;
    } forEach zone_meta_array;

    // Roadblock net, two passes (see header). Endpoints resolved here: HQ for pass A, a random non-closest
    // zone for pass B.
    private _hqSet = !(PosOfBLUHQ isEqualTo []);
    {
        private _zpos = _x select 1;
        private _zi = _forEachIndex;
        // Pass A: the HQ approach block, present with probability HP_ROAD_HQ_P. Endpoint [] with no HQ -> a
        // band draw at lay time.
        if (random 1 < HP_ROAD_HQ_P) then { _roadTargets pushBack [_zpos, if (_hqSet) then { PosOfBLUHQ } else { [] }] };
        // Pass B: an inter-zone block with probability HP_ROAD_NBR_P, to a random zone that is not the nearest.
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

    // Flank lines, throttled above the knee so a big map is not carpeted (see header).
    private _fz = if (_zc <= HP_FLANK_KNEE) then { _zc } else { HP_FLANK_KNEE + round ((_zc - HP_FLANK_KNEE) * HP_FLANK_SLOPE) };
    private _lo = floor (_fz / 2);
    private _backline = _lo + floor random (_fz - _lo + 1);
    private _frontline = _lo + floor random (_fz - _lo + 1);
    _total = _total + _backline + _frontline;
    [_zoneCounts, _backline, _frontline, _roadTargets, _total]
};
