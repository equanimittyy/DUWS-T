// Locality: server -- published from server/server_fnc_init.sqf. Everything downstream raises men,
// which only the server does.
//
// The shared half of the spawn vocabulary: the composition-token grammar and the team rosters both
// sides field. Vehicles and the zone tiers that name them load later, in
// init_zones/fnc_zone_spawn_sizes.
//
// Its own file for a load-order reason: the BLUFOR squad catalogue is built at server_init, before
// the zone-spawn band runs, so a table living in that band would not exist yet when the first squad
// is priced. The token grammar rides along because the roster lookup below is written in terms of it.
//
// Rows are data: a team added here is spawnable without touching code, which is what lets the
// composition tool add one at all. Roles are named bare and the side is prepended when the team is
// raised, so one table serves both armies -- fnc_faction_schema holds the shared role vocabulary and
// fnc_faction_backfill covers a role one side's files never named.
//
// Named, not referenced: a faction table that omits a role leaves its global nil, and a nil inside an
// array literal cannot be tested for after the fact -- BIS_fnc_spawnGroup takes it and quietly raises
// a group one man short. Named, it resolves to "" and fnc_factionRoles drops it.
//
// A row is the roster and nothing about how many: DUWS_fnc_scaleComposition scales whole cards, so a
// x3 zone fields three of this team rather than one team tripled. At most one leader, at the front.
// Posture is not a column either -- a composition names it, so one roster covers a patrol and a
// dug-in garrison without a duplicate row.

// A composition token is "posture:name" -- what the group does and what it is made of. Separating
// them stops a roster and its orders being one decision: the same five men patrol at one zone and
// garrison a house at the next without a duplicate roster row.
//
// One string, not a nested pair, because these tables are edited through the composition TUI, whose
// row editor splits input on commas and would cut a nested list in half
// (docs/info/architecture/composition_tooling.md). It also leaves DUWS_fnc_spawnDiff comparing plain strings.
//
// A bare name (no posture prefix) defaults to "none": no standing orders, the caller drives the group
// itself. Shipped data always prefixes its posture, so bare is for a caller that orders its own unit.
DUWS_fnc_tokenName = {
    params ["_token"];
    private _parts = _token splitString ":";
    if (count _parts < 2) exitWith { _token };
    _parts select 1
};

DUWS_fnc_tokenPosture = {
    params ["_token"];
    private _parts = _token splitString ":";
    if (count _parts < 2) exitWith { "none" };
    _parts select 0
};

// --DUWS-UNITCOMP BEGIN name="Teams" kind=team row="team, roles, leader" fields="team, roles, leader" prefix=blufor_,opfor_--
DUWS_teamRosters = [
    ["patrol", ["SOLDIER_X", "AR_SOLDIER_X"], ""],
    ["team", ["AR_SOLDIER_X", "GL_SOLDIER_X", "MARK_SOLDIER_X", "LAT_SOLDIER_X", "MEDIC_X"], "TL_SOLDIER_X"],
    ["sniper_element", ["SNIPER_SOLDIER_X", "SNIPER_SOLDIER_X"], ""],
    ["wp_team", ["SOLDIER_X", "AA_SOLDIER_X", "AT_SOLDIER_X", "AT_SOLDIER_X", "MEDIC_X"], "TL_SOLDIER_X"],
    ["garrison_element", ["AR_SOLDIER_X", "SOLDIER_X", "SOLDIER_X", "MEDIC_X"], "SL_SOLDIER_X"],
    ["recon", ["SPECOPS_X", "SPECOPS_GL_X", "SPECOPS_MG_X", "SPECOPS_LAT_X", "SPECOPS_MEDIC_X"], ""],
    ["squad", ["SOLDIER_X", "MARK_SOLDIER_X", "GL_SOLDIER_X", "GL_SOLDIER_X", "LAT_SOLDIER_X", "LAT_SOLDIER_X", "AR_SOLDIER_X", "MEDIC_X"], "SL_SOLDIER_X"]
];
// --DUWS-UNITCOMP END--

// The row behind a token, or [] when nothing claims it -- how the spawn path tells a team from a
// vehicle from a bare classname. Posture is stripped here, not at each call site: a lookup on the
// whole string would find no row for "closepatrol:team".
DUWS_fnc_teamRow = {
    params ["_token"];
    private _name = [_token] call DUWS_fnc_tokenName;
    private _i = DUWS_teamRosters findIf { (_x select 0) isEqualTo _name };
    if (_i < 0) then { [] } else { DUWS_teamRosters select _i }
};

// A team's men, in spawn order. _side is required, not defaulted: a row names roles bare, so a
// caller that forgot would silently raise the other army. One team always -- how many a site fields
// is the composition's business, and whole: attrition is a ledger of lost tokens now, not a men-thin,
// so a team that stands up stands up full. An unknown token yields nothing, not a fallback group:
// inventing men would hide the typo behind a garrison that spawns.
DUWS_fnc_teamRoster = {
    params ["_token", "_side"];
    private _row = [_token] call DUWS_fnc_teamRow;
    if (_row isEqualTo []) exitWith { [] };
    _row params ["", "_roles", "_leader"];
    // Copied, not aliased: the row belongs to the shipped table, so writing through this local would
    // silently edit every later team built from it for the rest of the session.
    private _men = +_roles;
    private _names = [];
    if (_leader != "") then { _names pushBack _leader };
    _names append _men;
    // Drawn at the moment the team is raised, so two squads standing up in the same second are not
    // the same five men. The pool behind each role is fnc_faction_pools.
    [_names apply { [format ["%1_%2", _side, _x]] call fnc_faction_pick }, _side] call fnc_factionRoles
};

// How many men a composition token places, counted rather than built. Mirrors teamRoster's roster --
// leader plus roles -- but resolves no faction pick and raises nothing, so the strength projection and
// the reserve owed-count can read it several times a second without paying a roster raise. A vehicle or
// bare-class token owes no infantry men and answers 0. Whole tokens only: attrition is a ledger of lost
// whole tokens now, so a token that is placed is placed at full and nothing thins the men inside it.
DUWS_fnc_tokenMenCount = {
    params ["_token"];
    private _row = [_token] call DUWS_fnc_teamRow;
    if (_row isEqualTo []) exitWith { 0 };
    _row params ["", "_roles", "_leader"];
    (count _roles) + ([0, 1] select (_leader != ""))
};

DUWS_fnc_tokenListMen = {
    params ["_tokens"];
    private _n = 0;
    { _n = _n + ([_x] call DUWS_fnc_tokenMenCount) } forEach _tokens;
    _n
};
