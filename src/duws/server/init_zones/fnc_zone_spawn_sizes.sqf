// Locality: server -- spawned once from server/server_init.sqf to publish the tables below.
//
// The OPFOR spawn composition framework, shared by zones and by town garrisons. A token names a row
// in DUWS_teamRosters (a team) or in DUWS_spawnVehicles (a vehicle). A token neither table claims is
// a vehicle classname a faction file named directly, and spawns as itself.
//
// Zones and towns keep separate composition sets -- a town garrison must not field what a zone does,
// or the two stop reading differently on the ground -- but share the token vocabulary, the tables
// and the spawner here, so a new team or vehicle is added in one place rather than two.

// The category vocabulary, and nothing more: every token carries its own category on its own row.
// Categories exist because a zone's radius scales its garrison unevenly -- more ground needs
// proportionally more infantry to cover it and does not need more aircraft.
//
// POSITIONALLY LOCKED to DUWS_zoneRadiusMult below: a category's position here is the column its
// multiplier is read from. Reordering either table without the other silently scales armour by the
// air column, which is a balance change with nothing in the log to show for it.
// --DUWS-UNITCOMP BEGIN name="Spawn categories" kind=rule row="category" fields="category"--
DUWS_spawnCategories = [
    ["infantry"],
    ["light"],
    ["armour"],
    ["air"],
    ["fortification"]
];
// --DUWS-UNITCOMP END--

// A token's category comes off its own row in whichever table claims it. A token neither claims is a
// classname a faction file named directly; those scale as "light" -- a multiplier of one everywhere
// -- rather than being dropped or guessed at, so a mod's own class still spawns and never at three
// times the count.
//
// The answer is checked against the vocabulary before it is returned, and that check is not
// defensive padding: DUWS_fnc_zoneSpawnList finds a multiplier by the category's *position*, so a
// name that is not in it resolves to index 0 -- the radius ceiling column -- and the zone would try
// to field a hundred thousand groups. A row's category is editable, so this is reachable.
DUWS_fnc_spawnCategory = {
    params ["_token"];
    private _row = [_token] call DUWS_fnc_teamRow;
    if (_row isEqualTo []) then { _row = [_token] call DUWS_fnc_vehicleRow };
    if (_row isEqualTo []) then { _row = [_token] call DUWS_fnc_specialRow };
    private _cat = if (_row isEqualTo []) then { "light" } else { _row select 2 };
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
// Fortification is one at every radius on purpose: a zone digs in once whatever ground it holds, and
// the mortar pair, the tower posts and the occupied houses are placed against the centre rather than
// spread over the perimeter. Multiplying them would put a second mortar section on a wide zone.
// --DUWS-UNITCOMP BEGIN name="Zone radius multipliers" kind=rule row="ceiling, infantry, light, armour, air, fortification" fields="radius ceiling, infantry, light, armour, air, fortification"--
DUWS_zoneRadiusMult = [
    [101,  1, 1, 0, 0, 1],
    [251,  1, 1, 1, 0, 1],
    [501,  2, 1, 1, 0, 1],
    [1001, 2, 1, 1, 1, 1],
    [1501, 2, 1, 2, 1, 1],
    [1e11, 3, 1, 2, 1, 1]
];
// --DUWS-UNITCOMP END--

// What a zone of each tier fields before its radius multiplies each category, indexed tier-1.
// Absolute, not cumulative: a tier is the whole garrison, so what a tier IV zone is can be read off
// one row instead of assembled from four.
//
// The four fortification tokens sit on every row because the pass they came from ran on every zone
// whatever its tier -- it was a second, separate spawner that no tier table could see, which is why
// a tier I zone and a tier IV zone differed by far less than their rows suggested. What each tier
// should actually buy is now one table's worth of editing rather than a second file.
// --DUWS-UNITCOMP BEGIN name="Zone tiers" kind=composition rowname="Tier %1" row="tier I..IV"--
DUWS_zoneSpawnTiers = [
    ["patrol", "team", "car", "fortified", "mortar", "fortbuildings", "towers"],
    ["patrol", "team", "wpteam", "car", "apc", "fortified", "mortar", "fortbuildings", "towers"],
    ["sniper", "patrol", "team", "wpteam", "car", "apc", "fortified", "mortar", "fortbuildings", "towers"],
    ["sniper", "patrol", "patrol", "team", "wpteam", "car", "tank", "attackheli", "fortified", "mortar", "fortbuildings", "towers"]
];
// --DUWS-UNITCOMP END--

// A zone's spawn list: its tier composition, each entry repeated as many times as its category's
// radius multiplier asks for. Takes the tier and the radius rather than reading either, so the
// sizing is testable without the engine.
//
// Player count does not enter into it. A zone is its tier and its radius -- three levers the player
// can see and the commander can spend against -- and head-count scaling was none of those: it made
// co-op zones harder while leaving co-op towns untouched, which nothing ever chose.
DUWS_fnc_zoneSpawnList = {
    params ["_tier", "_size"];
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
    [_out] call DUWS_fnc_spawnFilter
};

// Drops the tokens this side cannot field right now. Three separate reasons, one answer: the token
// leaves the composition and nothing takes its place.
//
// Substituting is what this replaces and it was never chosen -- it was the shape of an `if` leaking.
// An air slot with attack helicopters switched off fell through to the general vehicle pool, so a
// player who asked for no helicopters got an extra truck per slot instead of a quieter zone.
//
// Runs after the radius expansion and before the strength thin: filtering first thins the force the
// side can actually field, where thinning first reduces a composition and then reduces it again.
DUWS_fnc_spawnFilter = {
    params ["_tokens"];
    _tokens select { ([_x] call DUWS_fnc_tokenClass) != "" }
};

// What attrition does to one token. A composition entry is not a unit -- "patrol" is two men, "team"
// is five, "car" is a vehicle -- so dropping entries at random meant two zones reported at the same
// strength could differ by twenty men, and the bar the readout draws did not mean what it said.
// Attrition is a fraction of *men*, and every token carries its own share of it.
//
// Three answers, and which one a token gets is what it is made of rather than which system raised it:
//
//   _strength  anything that thins from the inside -- a team drops men and keeps its leader, the
//              house pass holds fewer houses, the tower pass mans fewer posts.
//   1          the mortar pair, which is exempt. The tube and its ammunition are one backpack each
//              on two men, so a fraction of a pair is no tube at all: that is a different zone
//              rather than a weaker one.
//   0          a vehicle below half strength, which is dropped whole. There is no partial vehicle --
//              a crew short of a driver is a wreck the player walks past -- so a zone ground below
//              half stops fielding them, which is one rule a player can learn.
DUWS_fnc_tokenStrength = {
    params ["_token", ["_strength", 1]];
    if !(([_token] call DUWS_fnc_teamRow) isEqualTo []) exitWith { _strength };
    private _sp = [_token] call DUWS_fnc_specialRow;
    if !(_sp isEqualTo []) exitWith { [1, _strength] select (_sp select 5) };
    [0, 1] select (_strength >= 0.5)
};

// The composition a site actually raises: every token that still places something. Nothing is
// dropped at random here -- the tokens that survive are the same ones at the same strength every
// time, so a zone the player wore down comes back as the zone they wore down.
DUWS_fnc_thinComposition = {
    params ["_tokens", ["_strength", 1]];
    _tokens select { ([_x, _strength] call DUWS_fnc_tokenStrength) > 0 }
};

// The classname behind a token, or "" when it cannot be fielded. A team is not this function's
// business and answers itself -- fnc_opforRoles already drops the roles a faction leaves undefined.
DUWS_fnc_tokenClass = {
    params ["_token"];
    if !(([_token] call DUWS_fnc_teamRow) isEqualTo []) exitWith { _token };
    if !(([_token] call DUWS_fnc_specialRow) isEqualTo []) exitWith { _token };
    private _row = [_token] call DUWS_fnc_vehicleRow;
    // Not in either table: a faction file named a classname directly, and it stands as itself.
    if (_row isEqualTo []) exitWith { _token };
    _row params ["", "_role", "", "_setting", "_ap"];
    // Missing setting defaults to on: a campaign that predates a new rule fields what it always did
    // rather than quietly losing a category.
    if (_setting != "" && {(missionNamespace getVariable [_setting, 1]) != 1}) exitWith { "" };
    if (_ap > 0 && {(missionNamespace getVariable ["WARCOM_opfor_ap", 0]) < _ap}) exitWith { "" };
    // Drawn per spawn, not held as one value the whole campaign fields at once: two zones raised in
    // the same second should not both put down the identical APC.
    [_role] call fnc_faction_pick
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
    params ["_tokens", "_pos", "_radius", ["_strength", 1]];
    private _grps = [];
    {
        // Attrition reaches every token here, as its own share of the fraction, rather than by
        // taking entries out of the list before it arrives.
        private _tokenStrength = [_x, _strength] call DUWS_fnc_tokenStrength;

        private _special = [_x] call DUWS_fnc_specialRow;
        private _raised = if !(_special isEqualTo []) then {
            // Each placer carries its own search and loot passes, unlike the teams below: flagging
            // these men again would roll a second time against the same bodies and quietly raise the
            // rate this garrison pays out at.
            private _fn = missionNamespace getVariable [_special select 3, {grpNull}];
            ([_pos, _radius] + (_special select 4) + [_tokenStrength]) call _fn
        } else {
            private _g = [_x, _pos, _radius, _tokenStrength] call DUWS_fnc_zoneSpawnOne;
            // Flagged where the group is raised, so the two cannot drift: every spawner here already
            // carried the loot pass and none of them carried this one, which once left the 50 %
            // garrison rate firing on side-mission garrisons and nowhere else.
            if (!isNull _g) then { [_g, "garrison"] call fnc_search_flag_group };
            _g
        };
        // A placer that mans a dozen separate posts hands back a group each; everything else hands
        // back one.
        private _made = if (_raised isEqualType []) then { _raised } else { [_raised] };
        {
            private _grp = _x;
            if (!isNull _grp) then { _grps pushBack _grp };
        } forEach _made;
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
//   digin  scattered on a ring around the centre, then taskDefend over the same ground. A defence
//          stacked on the centre is one the player can fight from a single angle
//   none   nothing: the caller places the group and gives it orders itself
// category -- which radius multiplier scales it. Held here rather than in the category map below,
// so adding a team is one row rather than two edits that can disagree.
// --DUWS-UNITCOMP BEGIN name="OPFOR teams" kind=team row="team, behaviour, category, core, added once, leader" fields="team, behaviour, category, core (multiplied), added once, leader" prefix=opfor_--
DUWS_teamRosters = [
    ["patrol", "route", "infantry", ["opfor_SOLDIER_X", "opfor_AR_SOLDIER_X"], [], ""],
    ["team", "route", "infantry", ["opfor_AR_SOLDIER_X", "opfor_GL_SOLDIER_X"], ["opfor_MARK_SOLDIER_X", "opfor_LAT_SOLDIER_X"], "opfor_TL_SOLDIER_X"],
    ["sniper", "route", "infantry", ["opfor_SNIPER_SOLDIER_X", "opfor_SNIPER_SOLDIER_X"], [], ""],
    ["wpteam", "wander", "infantry", ["opfor_SOLDIER_X"], ["opfor_AA_SOLDIER_X", "opfor_AT_SOLDIER_X", "opfor_SPECOPS_MEDIC_X"], "opfor_TL_SOLDIER_X"],
    ["fortified", "digin", "fortification", ["opfor_AR_SOLDIER_X", "opfor_AT_SOLDIER_X", "opfor_GL_SOLDIER_X", "opfor_SPECOPS_MEDIC_X"], [], "opfor_SL_SOLDIER_X"]
];
// --DUWS-UNITCOMP END--

// The row behind a token, or [] when nothing claims it -- which is how the spawn path tells a team
// from a vehicle from a classname a faction file named directly.
DUWS_fnc_teamRow = {
    params ["_token"];
    private _i = DUWS_teamRosters findIf { (_x select 0) isEqualTo _token };
    if (_i < 0) then { [] } else { DUWS_teamRosters select _i }
};

// Every vehicle the OPFOR side fields, one row each, in the same shape as a team's: what it is
// called, what it fields, which category scales it, and what it requires.
//
// A token names one vehicle and never a bucket to roll in. The pool this replaces weighted four
// trucks alongside three APCs and a tank under the name "armored", so roughly one armour slot in six
// stood a supply truck on an objective -- and a large zone rolled that dip twice. Variety is not
// lost with it: the role below names a faction pool, and fnc_faction_pick draws from that pool as
// each vehicle is placed, so two zones raised in the same second field different APCs. What goes is
// the randomness no table could see -- a bucket the composition named but could not describe.
//
// role -- the faction global holding the classname, named rather than referenced: a faction table
//         that omits a role leaves its global undefined, and an undefined name inside an array
//         literal is not something the spawner can test for afterwards.
// setting -- a campaign setting that must read 1, or "" for a vehicle nothing gates.
// ap -- the Army Power the OPFOR side must have reached, 0 for a vehicle available from the start.
//       Which tokens hang off which rung is a balance decision; the mechanism is the point here.
// --DUWS-UNITCOMP BEGIN name="OPFOR vehicles" kind=team row="token, role, category, setting, ap" fields="token, faction role, category, campaign setting, AP required" prefix=opfor_--
DUWS_spawnVehicles = [
    ["car",        "opfor_ARMED_CAR1_X",    "light",  "",           0],
    ["truck",      "opfor_COVERED_TRUCK_X", "light",  "",           0],
    ["transport",  "opfor_TRANS_TRUCK_X",   "light",  "",           0],
    ["ammo",       "opfor_AMMO_TRUCK_X",    "light",  "",           0],
    ["repair",     "opfor_REPAIR_TRUCK_X",  "light",  "",           0],
    ["apc",        "opfor_APC1_X",          "armour", "",           0],
    ["ifv",        "opfor_APC2_X",          "armour", "",           0],
    ["aa",         "opfor_AA_APC_X",        "armour", "",           0],
    ["tank",       "opfor_MBT_TANK1_X",     "armour", "HeavyArmor", 100],
    ["attackheli", "opfor_ATTACK_HELI_X",   "air",    "AttackHeli", 0],
    ["transheli",  "opfor_TRANS_HELI_X",    "air",    "AttackHeli", 0],
    ["plane",      "opfor_MISC_AIR_X",      "air",    "AttackHeli", 0]
];
// --DUWS-UNITCOMP END--

DUWS_fnc_vehicleRow = {
    params ["_token"];
    private _i = DUWS_spawnVehicles findIf { (_x select 0) isEqualTo _token };
    if (_i < 0) then { [] } else { DUWS_spawnVehicles select _i }
};

// Tokens that are neither a team nor a vehicle: men placed by a rule rather than by a roster. The
// parameters live on the row for the same reason a team's men do -- they were arguments hardcoded
// at one call site, where a second caller wanting different ones had nowhere to say so.
//
// Column 2 is the category in all three tables, which is what lets DUWS_fnc_spawnCategory ask one
// question of whichever row claims the token. Column 3 names the placer, and column 4 is whatever
// that placer's own parameters are; every placer is called as [pos, radius] + params + [strength].
// Column 5 says whether attrition reaches inside the token or leaves it whole.
//
// buildings     -- houses around the centre, the shape a side mission garrisons with.
// fortbuildings -- the same pass with a zone's parameters: it wants five usable building positions
//                  rather than two, stands its men UP rather than AUTO, and takes the buildings
//                  nearest the centre rather than a random spread, so a zone is held from its
//                  middle. Its own row rather than arguments on the one above, because a
//                  composition names what it fields and never how to field it.
// mortar        -- the zone's only indirect fire, and exempt from attrition on its own row: the tube
//                  and its ammunition are one backpack each on two men, so a fraction of a pair
//                  takes the tube away entirely. That changes what the zone is, not how strong.
// towers        -- the guard towers and bunkers already standing on the ground, manned in place.
// --DUWS-UNITCOMP BEGIN name="OPFOR specials" kind=team row="token, places, category, placer, params, thins" fields="token, places, category, placer, parameters, thins"--
DUWS_spawnSpecials = [
    ["buildings",     "houses", "infantry",      "fnc_garrisonBuildings", [8, 3, 2, "AUTO", false], true],
    ["fortbuildings", "houses", "fortification", "fnc_garrisonBuildings", [8, 3, 5, "UP", true],    true],
    ["mortar",        "tube",   "fortification", "fnc_garrisonMortar",    [],                       false],
    ["towers",        "posts",  "fortification", "fnc_garrisonTowers",    [300],                    true]
];
// --DUWS-UNITCOMP END--

DUWS_fnc_specialRow = {
    params ["_token"];
    private _i = DUWS_spawnSpecials findIf { (_x select 0) isEqualTo _token };
    if (_i < 0) then { [] } else { DUWS_spawnSpecials select _i }
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
    // Drawn at the moment the team is raised, so two squads standing up in the same second are not
    // the same five men. The pool behind each role is fnc_faction_pools.
    [_names apply { [_x] call fnc_faction_pick }] call fnc_opforRoles
};

// Called rather than spawned, for the group each one hands back: the capture test counts this
// zone's own garrison, so every unit raised here has to be flagged with the zone it belongs to.
//
// The tables decide, not a switch: a token the team roster claims is a team and fnc_spawn_team
// raises it whatever it is called; anything else resolves to a classname and is placed as a vehicle.
// A team or a vehicle added to a table spawns without a case being written for it.
//
// A token whose class resolves to "" is refused rather than spawned. The composition was filtered
// before it got here, so this is a caller that skipped the filter, and spawning "" is a nil vehicle.
DUWS_fnc_zoneSpawnOne = {
    params ["_token", "_pos", "_size", ["_strength", 1]];
    if !(([_token] call DUWS_fnc_teamRow) isEqualTo []) exitWith {
        [_token, _pos, _size, _strength] call fnc_spawn_team
    };
    private _class = [_token] call DUWS_fnc_tokenClass;
    if (_class == "") exitWith {
        ["WARN", "ZONES", format ["%1 cannot be fielded here and was not filtered out", _token]] call fnc_log;
        grpNull
    };
    [_class, _pos, _size] call fnc_spawn_vehicle
};

// Called by the zone raise worker, which owns the streaming decisions around it. Nothing guards a
// stale cycle here any more: the worker holds the raise flag for the whole placement, and the tick
// that set it will not start a second one or tear the zone down until it reports.
fnc_zone_spawn = {
    params ["_spawnPos", "_size", ["_zoneKey", ""]];
    if (_zoneKey == "") then { _zoneKey = [_spawnPos] call fnc_zone_key };
    private _roster = [_zoneKey] call fnc_zone_roster;

    private _tier = [_zoneKey] call fnc_zone_tier;
    private _spawns = [_tier, _size] call DUWS_fnc_zoneSpawnList;
    if (_spawns isEqualTo []) exitWith {
        ["ERROR", "ZONES", format ["no radius band covers %1 for %2", _size, _zoneKey]] call fnc_log;
    };

    // The composition is what the zone fields intact; it deploys at whatever its garrison was ground
    // down to. Without this, breaking a garrison and leaving buys the player nothing -- the same
    // fight is waiting at full strength when they come back.
    //
    // The list only loses what a fraction cannot place at all; everything else carries the fraction
    // into the raise and fields its own reduced share.
    private _strength = [_zoneKey] call fnc_zone_strength;
    _spawns = [_spawns, _strength] call DUWS_fnc_thinComposition;

    { _roster append (units _x) } forEach ([_spawns, _spawnPos, _size, _strength] call DUWS_fnc_raiseGarrison);

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
