// Locality: server -- run from server/server_fnc_init.sqf to publish the grammar and table below.
// Every reader raises men, which only the server does.
//
// The shared half of the spawn vocabulary: what a composition token is made of, and every team
// either side fields. The rest of the framework -- the vehicles and the zone tiers that name them
// -- is init_zones/fnc_zone_spawn_sizes, which is OPFOR's and loads later.
//
// Its own file rather than a block inside the zone spawn band, for a load-order reason: the BLUFOR
// squad catalogue is built at server_init before that band is spawned, so a table living there
// would not exist yet when the first squad is priced. The token grammar comes along because the
// roster lookup below is written in terms of it.
//
// A row is self-describing on purpose: a team added here is spawnable without touching code, which
// is what makes the composition tool able to add one at all.
//
// Roles are named bare and the side is prepended when the team is raised, which is the whole point
// of one table: `recon` is the same four roles whoever stands it up, and each side fills them from
// its own faction. It only works because both sides spell a role the same way -- fnc_faction_schema
// holds the shared vocabulary, and fnc_faction_backfill covers a role one side's files never named.
//
// Named rather than referenced for a second reason: a faction table that omits a role leaves its
// global undefined, and an undefined name inside an array literal is not something the spawner can
// test for afterwards -- BIS_fnc_spawnGroup takes the nil and quietly raises a group one man short.
// Named, it resolves to "" and fnc_factionRoles drops it.
//
// A row is the men and nothing about how many of the team there are. The enemy multiplier used to
// reach inside here, repeating a "core" column while a "tail" column was added once so a x3 setting
// fielded one marksman rather than three -- two columns and a rule, to express a count. It scales
// whole cards now (DUWS_fnc_scaleComposition), so a x3 zone fields three of this team rather than
// one team three times the size, and the row is just a role list with at most one leader at the
// front.
//
// A team is what an A3 group is made of and nothing about what it does. The orders used to be a
// column here, which meant a roster and one set of orders were a single decision: fielding these
// same men dug in rather than patrolling took a second row with an identical roster. A composition
// names the posture now, so one roster covers both.

// A composition token is "posture:name" -- what the group does, and what it is made of. Splitting
// them is what stops a roster and its orders being one decision: the same five men are a patrol at
// one zone and a house garrison at the next without a second roster row that duplicates the first.
//
// One string rather than a nested pair because these tables are edited through the composition TUI,
// whose row editor splits typed input on commas and would cut a nested list in half
// (docs/info/composition_tooling.md). It also leaves DUWS_fnc_spawnDiff comparing strings, so a town
// reinforcement still diffs what is standing against what is owed without knowing about postures.
//
// A bare name gets a close patrol, which is the circuit every team and every vehicle walked back when
// orders were a property of the roster. So a caller that names no posture -- a side mission raising a
// guard ring, a faction file naming a vehicle classname -- still gets what it has always got.
DUWS_fnc_tokenName = {
    params ["_token"];
    private _parts = _token splitString ":";
    if (count _parts < 2) exitWith { _token };
    _parts select 1
};

DUWS_fnc_tokenPosture = {
    params ["_token"];
    private _parts = _token splitString ":";
    if (count _parts < 2) exitWith { "closepatrol" };
    _parts select 0
};

// --DUWS-UNITCOMP BEGIN name="Teams" kind=team row="team, roles, leader" fields="team, roles, leader" prefix=blufor_,opfor_--
DUWS_teamRosters = [
    ["patrol", ["SOLDIER_X", "AR_SOLDIER_X"], ""],
    ["team", ["AR_SOLDIER_X", "GL_SOLDIER_X", "MARK_SOLDIER_X", "LAT_SOLDIER_X"], "TL_SOLDIER_X"],
    ["sniper", ["SNIPER_SOLDIER_X", "SNIPER_SOLDIER_X"], ""],
    ["wpteam", ["SOLDIER_X", "AA_SOLDIER_X", "AT_SOLDIER_X", "SPECOPS_MEDIC_X"], "TL_SOLDIER_X"],
    ["fortified", ["AR_SOLDIER_X", "AT_SOLDIER_X", "GL_SOLDIER_X", "SPECOPS_MEDIC_X"], "SL_SOLDIER_X"],
    ["recon", ["SPECOPS_X", "SPECOPS_GL_X", "SPECOPS_MG_X", "SPECOPS_LAT_X"], ""],
    ["infantry", ["GL_SOLDIER_X", "LAT_SOLDIER_X", "AR_SOLDIER_X"], "TL_SOLDIER_X"],
    ["squad", ["SOLDIER_X", "SOLDIER_X", "GL_SOLDIER_X", "GL_SOLDIER_X", "LAT_SOLDIER_X", "LAT_SOLDIER_X", "AR_SOLDIER_X"], "SL_SOLDIER_X"]
];
// --DUWS-UNITCOMP END--

// The row behind a token, or [] when nothing claims it -- which is how the spawn path tells a team
// from a vehicle from a classname a faction file named directly.
// Stripped here rather than at every call site: a token carries its posture everywhere it travels,
// and a lookup that matched the whole string would find no row for "closepatrol:team".
DUWS_fnc_teamRow = {
    params ["_token"];
    private _name = [_token] call DUWS_fnc_tokenName;
    private _i = DUWS_teamRosters findIf { (_x select 0) isEqualTo _name };
    if (_i < 0) then { [] } else { DUWS_teamRosters select _i }
};

// A team's men, in spawn order. _side is required rather than defaulted: a row names roles bare, so
// a caller that forgot to say would silently raise the other army.
//
// One team, always: how many of it a site fields is the composition's business, not this function's.
// _strength is attrition, and it is applied before the leader joins the men, so a section ground
// down still has one rather than sometimes losing it to a coin flip.
// An unknown token yields nothing rather than a fallback group -- the caller named a team that does
// not exist, and inventing men for it would hide the typo behind a garrison that spawns.
DUWS_fnc_teamRoster = {
    params ["_token", "_side", ["_strength", 1]];
    private _row = [_token] call DUWS_fnc_teamRow;
    if (_row isEqualTo []) exitWith { [] };
    _row params ["", "_roles", "_leader"];
    // Copied, not aliased. The row belongs to the shipped table, so anything written through this
    // local would edit every later team built from it, for the rest of the session and invisibly.
    // The shape this replaces built a fresh list by appending and got that for free.
    private _men = +_roles;
    if (_strength < 1) then { _men = [_men, _strength] call fnc_zone_thin };
    private _names = [];
    if (_leader != "") then { _names pushBack _leader };
    _names append _men;
    // Drawn at the moment the team is raised, so two squads standing up in the same second are not
    // the same five men. The pool behind each role is fnc_faction_pools.
    [_names apply { [format ["%1_%2", _side, _x]] call fnc_faction_pick }, _side] call fnc_factionRoles
};
