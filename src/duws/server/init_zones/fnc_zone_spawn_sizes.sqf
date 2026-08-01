// Locality: server -- spawned once from server/server_init.sqf to publish the tables below.
//
// The OPFOR spawn composition framework, shared by zones and by town garrisons. A token is a group
// kind, or a vehicle class fnc_random_veh understands ("car", "armored", "air").
//
// Zones and towns keep separate composition sets -- a town garrison must not field what a zone does,
// or the two stop reading differently on the ground -- but share the token vocabulary, the category
// map and the spawner here, so a new group kind is added in one place rather than two.

// Token to category. Categories exist because a zone's radius scales its garrison unevenly: more
// ground needs proportionally more infantry to cover it and does not need more aircraft. Membership
// lists rather than a per-token map so the whole vocabulary reads in one block.
// --DUWS-UNITCOMP BEGIN name="Spawn categories" row="category, members..."--
DUWS_spawnCategories = [
    ["infantry", ["patrol", "team", "sniper", "wpteam", "buildings"]],
    ["light",    ["car"]],
    ["armour",   ["armored"]],
    ["air",      ["air"]]
];
// --DUWS-UNITCOMP END--

// An unlisted token is a vehicle classname a faction file named directly, which DUWS_fnc_zoneSpawnOne
// hands to fnc_random_veh. Those scale as "light" -- a multiplier of one everywhere -- rather than
// being dropped or guessed at, so a mod's own class still spawns and never at three times the count.
DUWS_fnc_spawnCategory = {
    params ["_token"];
    private _i = DUWS_spawnCategories findIf { _token in (_x select 1) };
    if (_i < 0) then { "light" } else { (DUWS_spawnCategories select _i) select 0 }
};

// How many groups of each category a zone fields per entry in its tier composition.
//
// POSITIONALLY LOCKED to DUWS_spawnCategories above: one multiplier per category, in that order,
// after the radius ceiling. Reordering either table without the other silently scales armour by the
// air column, which is a balance change with nothing in the log to show for it.
// Row order is the lookup order: the first ceiling a radius falls under wins, and the last row is a
// band rather than an else so the table reads in one direction.
// --DUWS-UNITCOMP BEGIN name="Zone radius multipliers" row="ceiling, infantry, light, armour, air"--
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
// --DUWS-UNITCOMP BEGIN name="Zone tiers" row="tier I..IV"--
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
// --DUWS-UNITCOMP BEGIN name="Zone co-op extra" row="tier I..IV"--
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

// Called rather than spawned, for the group each one hands back: the capture test counts this
// zone's own garrison, so every unit raised here has to be flagged with the zone it belongs to.
// The band below still staggers them, which is what the spawn was doing.
DUWS_fnc_zoneSpawnOne = {
    params ["_token", "_pos", "_size"];
    switch (_token) do {
        case "patrol": { [_pos, _size] call fnc_createoppatrol2 };
        case "team":   { [_pos, _size] call fnc_createopteam2 };
        case "sniper": { [_pos, _size] call fnc_createoppatrol_sniper };
        case "wpteam": { [_pos, _size] call fnc_createopwpteam };
        // Anything else names a vehicle class rather than a group kind.
        default        { [OPFOR_Faction_X, _token, _pos, _size] call fnc_random_veh };
    };
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

    {
        private _grp = [_x, _spawnPos, _size] call DUWS_fnc_zoneSpawnOne;
        if (!isNull _grp) then {
            _roster append (units _grp);
            // Flagged where the group is rostered, so the two cannot drift: every spawner here
            // already carried the loot pass and none of them carried this one, which left the
            // 50 % garrison rate firing on side-mission garrisons and nowhere else.
            [_grp, "garrison"] call fnc_search_flag_group;
        };
        // Staggered, not batched: each of these spawns a group, and firing the whole band in one
        // frame is what the original's per-call sleep existed to avoid. None after the last.
        if (_forEachIndex < (count _spawns) - 1) then { sleep 5 };
    } forEach _spawns;

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
    ["INFO", "ZONES", format ["%1 deployed %2 men at tier %3, %4 strength; garrison peak %5",
        _zoneKey, _placed, _tier, [_zoneKey] call fnc_zone_strength, _baseline]] call fnc_log;
};
