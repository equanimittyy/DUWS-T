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
    // place them; the gun is what the player destroys.
    {
        _x params ["_class", "_ox", "_oy", "_oz", "_rowDir", ["_isWeapon", false]];
        if (_isWeapon) then { continue };
        private _off = [_ox, _oy, _dir] call fnc_hardpoint_rotate;
        private _wp = [_px + (_off select 0), _py + (_off select 1), 0];
        private _obj = createVehicle [_class, _wp, [], 0, "CAN_COLLIDE"];
        [_obj, _key] call fnc_duws_keep;
        _obj setPosATL _wp;
        _obj setDir (_rowDir + _dir);
        _obj enableSimulationGlobal false;
        _obj allowDamage false;
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
// none -- resolved to classnames here rather than passed as a list, so the token is what the site
// stores and a re-raise draws a fresh team from. The emplacement is manned regardless of it: a gun
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

    // Then the loose defenders, on a close patrol around the emplacement rather than dug in -- the gun
    // holds the position while the team works its approaches. An empty or unknown token places no one.
    private _garrison = [_teamToken, _side] call DUWS_fnc_teamRoster;
    if (count _garrison > 0) then {
        private _sp = _pos findEmptyPosition [0, 30, _garrison select 0];
        if (count _sp == 0) then { _sp = _pos };
        private _grp = [_sp, _sideObj, _garrison, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
        _grp deleteGroupWhenEmpty true;
        [_grp, "closepatrol", _pos, HP_GARRISON_PATROL_R] call fnc_apply_posture;
        _men append (units _grp);
    };

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

// [_zonePos, _radius, _zoneKey] call fnc_hardpoint_site_zone
//
// A zone's deliberate emplacements, replacing the old random fortification ring. The zone's radius
// caps how many it can hold (bigger zone, more ground to cover and room to cover it); a random count
// up to that cap is laid at campaign start, and the cap is stored so OPCOM can top the zone back up
// toward it later. Each slot goes to the best of a small sampled pool of positions, so terrain and
// mutual support pick the ground rather than chance -- a commanding, interlocking spot over a bare
// one. Its type is then a terrain-weighted roll over the set the loop places -- an MG on a rise, a
// roadblock on a road. That set is intentionally narrow: OPs, minefields and the fire-support types
// are OPCOM's to place, not rolled in at random. Each emplacement is defended by a regular six-man
// team, drawn from the faction's roles, on top of any gun type's own crew.
//
// Runs spawned: fnc_hardpoint_spawn sleeps in the crew drop, so build-out cannot call it inline.
// Idempotent per zone -- the stored cap is the guard -- so a rebuild through fnc_createZone lays no
// second ring.
#define HP_CAP_STEP 250
#define HP_SITE_SPACING 50
#define HP_SITE_SAMPLES 6
fnc_hardpoint_site_zone = {
    params ["_zonePos", "_radius", "_zoneKey"];
    if (!isNil { missionNamespace getVariable (format ["DUWS_hpCap_%1", _zoneKey]) }) exitWith {};
    private _cap = (round (_radius / HP_CAP_STEP)) max 1;
    missionNamespace setVariable [format ["DUWS_hpCap_%1", _zoneKey], _cap];
    private _count = round (random _cap);
    if (_count <= 0) exitWith {
        ["INFO", "HARDPOINT", format ["%1 rolled 0 hardpoints (cap %2)", _zoneKey, _cap]] call fnc_log;
    };

    private _types = ["ROADBLOCK", "MG", "AT", "GMG"];
    private _placed = 0;
    private _tries = 0;
    while { _placed < _count && {_tries < _count * 8} } do {
        _tries = _tries + 1;
        // A slot is filled by the best of a sampled pool, not the first spot that clears. Each draw is
        // anywhere in the zone (on land clear of steep slope and other objects) and is ranked by the
        // best any placeable type scores there -- height, overwatch of the approach, interlock range to
        // the nests already down. Still a weighted roll over the pool, not argmax: better ground is
        // likelier, not certain, so a zone's line of guns is not identical every campaign.
        private _pool = [];
        for "_i" from 1 to HP_SITE_SAMPLES do {
            private _c = [_zonePos, 0, _radius, 6, 0, 0.35, 0] call BIS_fnc_findSafePos;
            private _f = [_c] call fnc_hardpoint_survey;
            // Spaced off what is already down: hpDist (facts[8]) is the distance to the nearest placed
            // hardpoint. A draw on top of one is dropped, not scored.
            if ((_f select 8) < HP_SITE_SPACING) then { continue };
            private _sv = 0;
            { _sv = _sv max (([_f, _x] call fnc_hardpoint_score) * (DUWS_hardpointBaseWeight getOrDefault [_x, 1])) } forEach _types;
            if (_sv <= 0) then { continue };  // no type can hold this spot
            _pool pushBack [_c, _f];
            _pool pushBack _sv;
        };
        if (_pool isEqualTo []) then { continue };
        (selectRandomWeighted _pool) params ["_cand", "_facts"];

        // Type by weighted roll at the chosen spot: each type's base commonness times the ground's
        // score for it (the score is a multiplier, per fnc_hardpoint_score). So flat open ground leans
        // one way and a rise leans MG without either being the only answer.
        private _weighted = [];
        {
            private _s = [_facts, _x] call fnc_hardpoint_score;
            if (_s > 0) then {
                _weighted pushBack _x;
                _weighted pushBack (_s * (DUWS_hardpointBaseWeight getOrDefault [_x, 1]));
            };
        } forEach _types;
        private _best = selectRandomWeighted _weighted;

        // The overwatch nests face down the slope they overlook; the rest face radially out toward the
        // approach. fnc_hardpoint_facing picks between the two off the survey's fall line. Its garrison
        // is the type's, fielded by fnc_hardpoint_spawn from DUWS_hardpointGarrison, not chosen here.
        private _dir = [_best, _facts select 10, _facts select 11, (_zonePos getDir _cand)] call fnc_hardpoint_facing;
        private _key = format ["hp_%1_%2", _zoneKey, _placed];
        ([_best, _cand, _dir, "opfor", _key] call fnc_hardpoint_spawn) params ["_objs", "_men"];
        [_key, _best, _cand, _men, "opfor", _zoneKey] call fnc_hardpoint_register;
        _placed = _placed + 1;
    };
    ["INFO", "HARDPOINT", format ["%1 sited %2/%3 hardpoints (cap %4)", _zoneKey, _placed, _count, _cap]] call fnc_log;
};
