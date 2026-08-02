// Locality: server -- spawned once from server/server_init.sqf to publish the tables below.
//
// The OPFOR spawn composition framework, shared by zones and by town garrisons. A token names a
// team in DUWS_teamRosters below, or a vehicle class fnc_random_veh understands ("car", "armored",
// "air").
//
// Zones and towns keep separate composition sets -- a town garrison must not field what a zone does,
// or the two stop reading differently on the ground -- but share the token vocabulary, the category
// map and the spawner here, so a new team is added in one place rather than two.

// Token to category, for the tokens that are not teams. Categories exist because a zone's radius
// scales its garrison unevenly: more ground needs proportionally more infantry to cover it and does
// not need more aircraft.
// A team carries its own category on its row, so what is left here is the vehicle vocabulary and
// the building-occupation token. Row order is load-bearing: DUWS_zoneRadiusMult's columns are that
// order, and a category's position in this table is how the multiplier for it is found.
// --DUWS-UNITCOMP BEGIN name="Spawn categories" kind=rule row="category, members..." fields="category, members"--
DUWS_spawnCategories = [
    ["infantry", ["buildings"]],
    ["light",    ["car"]],
    ["armour",   ["armored"]],
    ["air",      ["air"]]
];
// --DUWS-UNITCOMP END--

// A team's category comes off its own row; every other token is looked up in the map above. An
// unlisted token is a vehicle classname a faction file named directly, which DUWS_fnc_zoneSpawnOne
// hands to fnc_random_veh. Those scale as "light" -- a multiplier of one everywhere -- rather than
// being dropped or guessed at, so a mod's own class still spawns and never at three times the count.
//
// The answer is checked against the map before it is returned, and that check is not defensive
// padding: DUWS_fnc_zoneSpawnList finds a multiplier by the category's *position* in the map, so a
// name that is not in it resolves to index 0 -- the radius ceiling column -- and the zone would try
// to field a hundred thousand groups. A team's category is editable, so this is reachable.
DUWS_fnc_spawnCategory = {
    params ["_token"];
    private _row = [_token] call DUWS_fnc_teamRow;
    private _cat = if (_row isEqualTo []) then {
        private _i = DUWS_spawnCategories findIf { _token in (_x select 1) };
        if (_i < 0) then { "light" } else { (DUWS_spawnCategories select _i) select 0 }
    } else {
        _row select 2
    };
    if (DUWS_spawnCategories findIf { (_x select 0) isEqualTo _cat } < 0) then {
        ["WARN", "ZONES", format ["%1 is filed under %2, which is not a category; scaling it as light",
            _token, _cat]] call fnc_log;
        _cat = "light";
    };
    _cat
};

// How many groups of each category a zone fields per entry in its tier composition.
//
// POSITIONALLY LOCKED to DUWS_spawnCategories above: one multiplier per category, in that order,
// after the radius ceiling. Reordering either table without the other silently scales armour by the
// air column, which is a balance change with nothing in the log to show for it.
// Row order is the lookup order: the first ceiling a radius falls under wins, and the last row is a
// band rather than an else so the table reads in one direction.
// --DUWS-UNITCOMP BEGIN name="Zone radius multipliers" kind=rule row="ceiling, infantry, light, armour, air" fields="radius ceiling, infantry, light, armour, air"--
DUWS_zoneRadiusMult = [
    [101,  1, 1, 0, 0],
    [251,  1, 1, 1, 0],
    [501,  2, 1, 1, 0],
    [1001, 2, 1, 1, 1],
    [1501, 2, 1, 2, 1],
    [1e11, 3, 1, 2, 1]
];
// --DUWS-UNITCOMP END--

// What a zone of each tier fields before its radius multiplies each category, indexed tier-1.
// Absolute, not cumulative: a tier is the whole garrison, so what a tier IV zone is can be read off
// one row instead of assembled from four.
// --DUWS-UNITCOMP BEGIN name="Zone tiers" kind=composition rowname="Tier %1" row="tier I..IV"--
DUWS_zoneSpawnTiers = [
    ["patrol", "team", "car"],
    ["patrol", "team", "wpteam", "car", "armored"],
    ["sniper", "patrol", "team", "wpteam", "car", "armored"],
    ["sniper", "patrol", "patrol", "team", "wpteam", "car", "armored", "air"]
];
// --DUWS-UNITCOMP END--

// Added when more than two players are in the session. Appended after the radius multiply rather
// than before it, so co-op scaling stays a flat handful of groups instead of being multiplied into
// the largest zones as well.
// --DUWS-UNITCOMP BEGIN name="Zone co-op extra" kind=composition rowname="Tier %1" row="tier I..IV"--
DUWS_zoneCoopExtra = [
    [],
    ["patrol"],
    ["patrol", "armored"],
    ["patrol", "team"]
];
// --DUWS-UNITCOMP END--

// A zone's spawn list: its tier composition, each entry repeated as many times as its category's
// radius multiplier asks for, then the co-op extra. Takes the tier and the radius rather than
// reading either, so the sizing is testable without the engine.
DUWS_fnc_zoneSpawnList = {
    params ["_tier", "_size", ["_coop", false]];
    private _t = (((round _tier) max 1) min (count DUWS_zoneSpawnTiers)) - 1;
    private _i = DUWS_zoneRadiusMult findIf { _size < (_x select 0) };
    if (_i < 0) exitWith { [] };
    private _row = DUWS_zoneRadiusMult select _i;

    private _out = [];
    {
        private _token = _x;
        private _cat = [_token] call DUWS_fnc_spawnCategory;
        private _ci = DUWS_spawnCategories findIf { (_x select 0) isEqualTo _cat };
        // Offset by one: the row's first element is the radius ceiling, not a multiplier.
        private _n = _row param [_ci + 1, 1];
        for "_k" from 1 to _n do { _out pushBack _token };
    } forEach (DUWS_zoneSpawnTiers select _t);

    if (_coop) then { _out append (DUWS_zoneCoopExtra select _t) };
    _out
};

// What is missing from _have to make it _want, counting duplicates: two patrols wanted against one
// already standing yields one patrol. This is what makes absolute composition lists workable for a
// garrison that can be upgraded mid-fight -- reinforcement raises the difference and lands beside
// the survivors, where re-raising the whole list would double the town.
DUWS_fnc_spawnDiff = {
    params ["_have", "_want"];
    private _pool = +_have;
    private _out = [];
    {
        private _i = _pool find _x;
        if (_i < 0) then { _out pushBack _x } else { _pool deleteAt _i };
    } forEach _want;
    _out
};

// Raises a token list and hands back the groups it made, in order. The one place a composition
// becomes men, shared by the zone band and the town garrison: the stagger, the search flag and the
// building-occupation token are rules about raising a garrison, not about which kind of ground is
// raising one.
//
// Staggered, not batched: each token raises a group, and firing a whole composition in one frame is
// what the per-call sleep this replaces existed to avoid. None after the last.
//
// Returns groups rather than appending to a caller's roster, so a caller that keeps one appends
// after. Nothing reads a zone's roster meaningfully while its band is still placing -- the capture
// test refuses on the missing peak, and the peak is taken after this returns.
DUWS_fnc_raiseGarrison = {
    params ["_tokens", "_pos", "_radius"];
    private _grps = [];
    {
        private _grp = if (_x == "buildings") then {
            // The zone benchmark a town's tier IV climbs to -- fnc_createopfortified holds up to
            // eight buildings at three men each. It carries its own search and loot passes, unlike
            // everything below: flagging these men again would roll a second time against the same
            // bodies and quietly raise the rate this garrison pays out at.
            [_pos, _radius, 8, 3] call fnc_garrisonBuildings
        } else {
            private _g = [_x, _pos, _radius] call DUWS_fnc_zoneSpawnOne;
            // Flagged where the group is raised, so the two cannot drift: every spawner here already
            // carried the loot pass and none of them carried this one, which once left the 50 %
            // garrison rate firing on side-mission garrisons and nowhere else.
            if (!isNull _g) then { [_g, "garrison"] call fnc_search_flag_group };
            _g
        };
        if (!isNull _grp) then {
            // Marked as somebody's garrison. A zone and a town each stream their own out by roster,
            // which is the rule -- but a side mission's teardown deletes by radius and has no way to
            // tell whose men it is standing among, and a mission that lands on a town disc used to
            // take that town's garrison with it. The town then measured its survivors against its
            // baseline, recorded a mauling nobody inflicted, and came back thinned every visit
            // after. The vehicle carries the flag too, or deleting it takes its crew regardless.
            {
                _x setVariable ["DUWS_garrisonUnit", true];
                if (vehicle _x != _x) then { (vehicle _x) setVariable ["DUWS_garrisonUnit", true] };
            } forEach units _grp;
            _grps pushBack _grp;
        };
        if (_forEachIndex < (count _tokens) - 1) then { sleep 5 };
    } forEach _tokens;
    _grps
};

// Every team the OPFOR side fields, and everything about one that is not a rule of raising it.
// A row is self-describing on purpose: a team added here is spawnable without touching code, which
// is what makes the composition tool able to add one at all.
//
// Roles are named rather than referenced: a faction table that omits a role leaves its global
// undefined, and an undefined name inside an array literal is not something the spawner can test
// for afterwards -- BIS_fnc_spawnGroup takes the nil and quietly raises a group one man short.
// Named, it resolves to "" and fnc_opforRoles drops it.
//
// The three roster columns are the shape every one of these teams already had: a core repeated by
// the enemy multiplier, a tail added once so a x5 setting fields one marksman rather than five, and
// at most one leader, at the front, for the same reason.
//
// behaviour -- what fnc_spawn_team does with the group once it stands:
//   route  a fixed circuit of three search-and-destroy waypoints, one of them at a building, then
//          CYCLE. Combat mode YELLOW, so it engages what it finds without abandoning the circuit
//   wander bis_fnc_taskPatrol's own random patrol around the centre
//   none   nothing: the caller places the group and gives it orders itself, as the fortification
//          garrison does with taskDefend after scattering it on a ring
// category -- which radius multiplier scales it. Held here rather than in the category map below,
// so adding a team is one row rather than two edits that can disagree.
// --DUWS-UNITCOMP BEGIN name="OPFOR teams" kind=team row="team, behaviour, category, core, added once, leader" fields="team, behaviour, category, core (multiplied), added once, leader" prefix=opfor_--
DUWS_teamRosters = [
    ["patrol", "route", "infantry", ["opfor_SOLDIER_X", "opfor_AR_SOLDIER_X"], [], ""],
    ["team", "route", "infantry", ["opfor_AR_SOLDIER_X", "opfor_GL_SOLDIER_X"], ["opfor_MARK_SOLDIER_X", "opfor_LAT_SOLDIER_X"], "opfor_TL_SOLDIER_X"],
    ["sniper", "route", "infantry", ["opfor_SNIPER_SOLDIER_X", "opfor_SNIPER_SOLDIER_X"], [], ""],
    ["wpteam", "wander", "infantry", ["opfor_SOLDIER_X"], ["opfor_AA_SOLDIER_X", "opfor_AT_SOLDIER_X", "opfor_SPECOPS_MEDIC_X"], "opfor_TL_SOLDIER_X"],
    ["fortified", "none", "infantry", ["opfor_AR_SOLDIER_X", "opfor_AT_SOLDIER_X", "opfor_GL_SOLDIER_X", "opfor_SPECOPS_MEDIC_X"], [], "opfor_SL_SOLDIER_X"]
];
// --DUWS-UNITCOMP END--

// The row behind a token, or [] when nothing claims it -- which is how the spawn path tells a team
// from a vehicle classname a faction file named directly.
DUWS_fnc_teamRow = {
    params ["_token"];
    private _i = DUWS_teamRosters findIf { (_x select 0) isEqualTo _token };
    if (_i < 0) then { [] } else { DUWS_teamRosters select _i }
};

// A team's men, in spawn order. The multiplier is clamped here rather than at the call sites, and
// never written back: the setup menu broadcasts enemyunitMultiplier once, so a spawner that
// corrected the global would corrupt every later build on that machine with nothing to re-broadcast
// a repair.
// _strength is attrition, and it is applied to the multiplied men before the leader joins them, so
// a section ground down still has one rather than sometimes losing it to a coin flip.
// An unknown token yields nothing rather than a fallback group -- the caller named a team that does
// not exist, and inventing men for it would hide the typo behind a garrison that spawns.
DUWS_fnc_teamRoster = {
    params ["_token", ["_mult", 1], ["_strength", 1]];
    private _row = [_token] call DUWS_fnc_teamRow;
    if (_row isEqualTo []) exitWith { [] };
    _row params ["", "", "", "_core", "_once", "_leader"];
    private _men = [];
    for "_k" from 1 to (_mult max 1) do { _men append _core };
    _men append _once;
    if (_strength < 1) then { _men = [_men, _strength] call fnc_zone_thin };
    private _names = [];
    if (_leader != "") then { _names pushBack _leader };
    _names append _men;
    [_names apply { missionNamespace getVariable [_x, ""] }] call fnc_opforRoles
};

// Called rather than spawned, for the group each one hands back: the capture test counts this
// zone's own garrison, so every unit raised here has to be flagged with the zone it belongs to.
//
// The table decides, not a switch: a token the roster claims is a team and fnc_spawn_team raises it
// whatever it is called, so a team added to the roster spawns without a case being written for it.
// Anything the roster does not claim names a vehicle class instead.
DUWS_fnc_zoneSpawnOne = {
    params ["_token", "_pos", "_size"];
    if !(([_token] call DUWS_fnc_teamRow) isEqualTo []) exitWith {
        [_token, _pos, _size] call fnc_spawn_team
    };
    [OPFOR_Faction_X, _token, _pos, _size] call fnc_random_veh
};

// Spawned by fnc_createzone, which no longer needs a switch to pick a function per band.
fnc_zone_spawn = {
    params ["_spawnPos", "_size", ["_zoneKey", ""], ["_gen", -1]];
    if (_zoneKey == "") then { _zoneKey = [_spawnPos] call fnc_zone_key };
    private _roster = [_zoneKey] call fnc_zone_roster;

    private _tier = [_zoneKey] call fnc_zone_tier;
    private _spawns = [_tier, _size, count (call BIS_fnc_listPlayers) > 2] call DUWS_fnc_zoneSpawnList;
    if (_spawns isEqualTo []) exitWith {
        ["ERROR", "ZONES", format ["no radius band covers %1 for %2", _size, _zoneKey]] call fnc_log;
    };

    // The composition is what the zone fields intact; it deploys at whatever its garrison was ground
    // down to. Without this, breaking a garrison and leaving buys the player nothing -- the same
    // fight is waiting at full strength when they come back.
    _spawns = [_spawns, [_zoneKey] call fnc_zone_strength] call fnc_zone_thin;

    { _roster append (units _x) } forEach ([_spawns, _spawnPos, _size] call DUWS_fnc_raiseGarrison);

    // Settled before the peak is taken. fnc_createopfortified appends to the same roster from its
    // own thread and is normally long finished by here, but nothing enforces that, and a peak taken
    // before its crews are in undercounts the garrison -- which makes the zone quietly cheaper.
    sleep 15;

    // A band still placing when its own zone packs up must not publish anything: the sweep has
    // already deleted what it would be describing, and the capture test reads a stale peak beside
    // empty ground as a garrison wiped.
    if (_gen >= 0 && {([_zoneKey] call fnc_zone_gen) != _gen}) exitWith {
        ["INFO", "ZONES", format ["%1 torn down mid-spawn; garrison peak not published", _zoneKey]] call fnc_log;
    };

    // The strength fnc_zone_capture_ready judges this zone against, and the only place it is set.
    // fnc_zone_garrison_dropped is the only place it is cleared, and states the contract binding
    // the two.
    //
    // Anchored to the men this zone's first completed cycle placed, not to what just deployed: a
    // garrison that comes back at six tenths is still measured against the ten, so the men killed
    // last visit stay killed. Re-basing the peak on the reduced garrison would restore the whole
    // 80%-to-beat every time the zone streamed out, which is the refund attrition exists to stop.
    private _placed = [_zoneKey] call fnc_zone_garrison_count;
    private _baseVar = format ["DUWS_zoneBase_%1", _zoneKey];
    private _baseline = missionNamespace getVariable [_baseVar, 0];
    if (_baseline <= 0) then {
        _baseline = _placed;
        missionNamespace setVariable [_baseVar, _baseline];
    };
    missionNamespace setVariable [format ["DUWS_zonePeak_%1", _zoneKey], _baseline];
    // Men are standing, so the zone has finished mobilising. Cleared beside the peak rather than at
    // the head of the spawn, because the peak is the point at which the garrison is real -- a band
    // still placing has neither, and a torn-down one exits above without publishing either.
    missionNamespace setVariable [format ["DUWS_zoneMobilising_%1", _zoneKey], nil];
    ["INFO", "ZONES", format ["%1 deployed %2 men at tier %3, %4 strength; garrison peak %5",
        _zoneKey, _placed, _tier, [_zoneKey] call fnc_zone_strength, _baseline]] call fnc_log;
};
