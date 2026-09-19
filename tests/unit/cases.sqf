// Tier 2 unit tests. The functions under test are extracted from real source by
// run.sh (see functions.txt) and defined before this file runs.

// --- DUWS_fnc_extractLoadoutItems: recursively collect non-empty strings ---
private _o = [];
[["Money_roll", ["a", ["b", "Files"]], ""], _o] call DUWS_fnc_extractLoadoutItems;
["extractLoadoutItems: flattens nested arrays, drops empty strings",
    _o, ["Money_roll", "a", "b", "Files"]] call fnc_assertEq;

private _o2 = [];
["Solo", _o2] call DUWS_fnc_extractLoadoutItems;
["extractLoadoutItems: accepts a bare string", _o2, ["Solo"]] call fnc_assertEq;

private _o3 = [];
[["dup", "dup", "x"], _o3] call DUWS_fnc_extractLoadoutItems;
["extractLoadoutItems: dedups via pushBackUnique", _o3, ["dup", "x"]] call fnc_assertEq;

// --- DUWS_fnc_countLoadoutChanges: count item classes that differ ---
["countLoadoutChanges: 1 removed + 2 added = 3",
    ([["x", "y"], ["y", "z", "w"]] call DUWS_fnc_countLoadoutChanges), 3] call fnc_assertEq;
["countLoadoutChanges: identical loadouts = 0",
    ([["a", "b"], ["a", "b"]] call DUWS_fnc_countLoadoutChanges), 0] call fnc_assertEq;

// --- fnc_cs: substitute the chosen squad callsign into English dialogue lines ---
duws_callsign = "Alpha 1-1";
["cs: default callsign is a no-op",
    (["Alpha 1-1 to Overlord, in position."] call fnc_cs),
    "Alpha 1-1 to Overlord, in position."] call fnc_assertEq;

duws_callsign = "Reaper";
["cs: substitutes the chosen callsign",
    (["Alpha 1-1 to Overlord, in position."] call fnc_cs),
    "Reaper to Overlord, in position."] call fnc_assertEq;

["cs: substitutes every occurrence",
    (["Alpha 1-1, this is Overlord. Alpha 1-1, acknowledge."] call fnc_cs),
    "Reaper, this is Overlord. Reaper, acknowledge."] call fnc_assertEq;

["cs: leaves lines without the callsign untouched",
    (["Overlord to all units in the AO."] call fnc_cs),
    "Overlord to all units in the AO."] call fnc_assertEq;

// --- fnc_duws_dialogue_channel: which surface a speaker lands on ---
// Fed English literals because sqf-vm has no stringtable. What is under test is the
// lookup, not what localize returns -- the router builds the real table from the same keys.
// Nineteen strings for twenty keys: allseer and Scout share an English value.
private _net = ["Allseer 1-1", "Express 2-1", "Viper 1-5", "Delta 3-2", "Koi 1-1",
    "Longbow 1-1", "Slingshot 1-1", "Cobra 1-3", "Hound 2-2", "Signal 3-1", "Signal 2-2",
    "OPFOR", "Chariot 1-1", "Crane 1-1", "Swordfish 1-1",
    "Chalk 2-1", "Courier 1-1", "Courier 3-1", "Ranger 1-1"];

{
    [format ["dialogue_channel: %1 is NET", _x],
        ([_x, _net] call fnc_duws_dialogue_channel), "NET"] call fnc_assertEq;
} forEach _net;

{
    [format ["dialogue_channel: %1 is VOICE", _x],
        ([_x, _net] call fnc_duws_dialogue_channel), "VOICE"] call fnc_assertEq;
} forEach ["Overlord", "Alpha 1-1", "Civilian", "informant", "Survivor", "IDAP staff",
    "Pilot"];

["dialogue_channel: a blank speaker is VOICE",
    (["", _net] call fnc_duws_dialogue_channel), "VOICE"] call fnc_assertEq;

// fnc_fob_server builds its call with format and interpolates a position array here.
["dialogue_channel: a non-string speaker is VOICE, never a table lookup",
    ([[1234.5, 6789, 0], _net] call fnc_duws_dialogue_channel), "VOICE"] call fnc_assertEq;

// Fail loud: an unlisted callsign must reach the surface the player is looking at.
["dialogue_channel: an unknown callsign defaults to VOICE",
    (["Havoc 6-1", _net] call fnc_duws_dialogue_channel), "VOICE"] call fnc_assertEq;

// --- fnc_civ_reaction_weights: the civilian request curve ---
// Asserted as whole percents: the weights are floats, and str-comparing them would be testing
// the VM's formatting rather than the curve.
private _pct = { (_this call fnc_civ_reaction_weights) apply { round (_x * 100) } };

[ "reaction: -20 is 0/10/90",  (-20 call _pct), [0, 10, 90] ] call fnc_assertEq;
[ "reaction: -10 is 17/22/62", (-10 call _pct), [17, 22, 62] ] call fnc_assertEq;
[ "reaction: 0 is an even split", (0 call _pct), [33, 33, 33] ] call fnc_assertEq;
[ "reaction: +10 is 62/22/17", (10 call _pct), [62, 22, 17] ] call fnc_assertEq;
[ "reaction: +20 is 90/10/0",  (20 call _pct), [90, 10, 0] ] call fnc_assertEq;

// The curve is asserted to saturate rather than trusted to be fed in range: the +-20 clamp lives
// in fnc_town_rep_adjust, a different function, and the line run past its ends yields a negative
// weight rather than an error.
[ "reaction: below -20 saturates", (-100 call _pct), (-20 call _pct) ] call fnc_assertEq;
[ "reaction: above +20 saturates", (100 call _pct), (20 call _pct) ] call fnc_assertEq;

// The roll picks by walking the three weights, so anything that fails to sum to 1 silently
// biases the last branch.
{
    private _w = _x call fnc_civ_reaction_weights;
    [format ["reaction: weights at %1 sum to 1", _x],
        round (((_w select 0) + (_w select 1) + (_w select 2)) * 1000), 1000] call fnc_assertEq;
} forEach [-20, -13, -7, 0, 3, 11, 20];

// No weight may go negative: a negative bribe would make the tent an inverted V and hand the
// remainder to refuse at exactly the reputations the player worked for.
{
    private _w = _x call fnc_civ_reaction_weights;
    [format ["reaction: no negative weight at %1", _x],
        (_w findIf { _x < 0 }), -1] call fnc_assertEq;
} forEach [-20, -15, -5, 0, 5, 15, 20];

// --- fnc_civ_rowPrice: what a row costs when the roll comes back bribe ---
["rowPrice: intel", (["INTEL"] call fnc_civ_rowPrice), 3] call fnc_assertEq;
["rowPrice: recruit", (["RECRUIT"] call fnc_civ_rowPrice), 2] call fnc_assertEq;
["rowPrice: aid", (["AID"] call fnc_civ_rowPrice), 2] call fnc_assertEq;
["rowPrice: toolkit", (["TOOLKIT"] call fnc_civ_rowPrice), 2] call fnc_assertEq;

["rowPrice: case-insensitive", (["intel"] call fnc_civ_rowPrice), 3] call fnc_assertEq;

// Fail closed. Rows only ever arrive over the wire, so an unrecognised one is a client sending
// something the menu never offered; the negative price is what every caller rejects on.
{
    [format ["rowPrice: %1 is rejected", str _x],
        ([_x] call fnc_civ_rowPrice) < 0, true] call fnc_assertEq;
} forEach ["", "ARREST", "SUPPLIES", "intel ", "DROP TABLE"];

// --- fnc_civ_townBand: the [ellipse, icon] colour pair a reputation paints ---
private _neutral = [0] call fnc_civ_townBand;
private _blu = [10] call fnc_civ_townBand;
private _opf = [-10] call fnc_civ_townBand;

// The bands are inclusive at +-10, which is the same edge fnc_civ_townIncome pays on: a town
// coloured for a side while paying nothing would contradict the readout drawn beside it.
["townBand: +10 is the BLUFOR band", ([10] call fnc_civ_townBand), _blu] call fnc_assertEq;
["townBand: -10 is the OPFOR band", ([-10] call fnc_civ_townBand), _opf] call fnc_assertEq;
["townBand: 9.9 is still neutral", ([9.9] call fnc_civ_townBand), _neutral] call fnc_assertEq;
["townBand: -9.9 is still neutral", ([-9.9] call fnc_civ_townBand), _neutral] call fnc_assertEq;
["townBand: no argument is neutral", ([] call fnc_civ_townBand), _neutral] call fnc_assertEq;

// Three distinct pairs, and within each pair two distinct colours: a band that collapsed onto
// another would leave two sides indistinguishable on the map, and the icon matching its
// ellipse would put it back in the wash the deeper colour exists to escape.
{
    _x params ["_label", "_pair"];
    [format ["townBand: %1 icon differs from its ellipse", _label],
        ((_pair select 0) isEqualTo (_pair select 1)), false] call fnc_assertEq;
} forEach [["neutral", _neutral], ["blufor", _blu], ["opfor", _opf]];

["townBand: neutral and blufor differ", (_neutral isEqualTo _blu), false] call fnc_assertEq;
["townBand: neutral and opfor differ", (_neutral isEqualTo _opf), false] call fnc_assertEq;
["townBand: blufor and opfor differ", (_blu isEqualTo _opf), false] call fnc_assertEq;

// --- fnc_civ_townIncome: what a town pays a tick, and to whom ---
["townIncome: a BLUFOR town pays its worth west",
    ([12, 3] call fnc_civ_townIncome), [3, "BLU"]] call fnc_assertEq;
["townIncome: an OPFOR town pays its worth east",
    ([-12, 3] call fnc_civ_townIncome), [3, "OPF"]] call fnc_assertEq;

// A neutral town pays nobody, so its worth is not its income. The map readout prints this
// figure, and printing the worth there would promise AP the economy tick never credits.
{
    [format ["townIncome: %1 is neutral and pays nothing", _x],
        ([_x, 3] call fnc_civ_townIncome), [0, ""]] call fnc_assertEq;
} forEach [0, 9.9, -9.9];

["townIncome: the band edges pay",
    [([10, 2] call fnc_civ_townIncome), ([-10, 2] call fnc_civ_townIncome)],
    [[2, "BLU"], [2, "OPF"]]] call fnc_assertEq;

// RAVAGE and WBK register no town worth, so the array read that feeds this comes back short.
["townIncome: no worth pays nothing",
    ([20, 0] call fnc_civ_townIncome), [0, "BLU"]] call fnc_assertEq;

// --- fnc_civ_liveTarget: how many civilians one town may hold right now ---
// Reads per-town state out of the mission namespace, so each case stages the towns it needs.
// civ_locations is only ever counted, so a list of placeholders stands in for the Locations.
CIV_PRESENCE = "med";
private _stage = {
    params ["_pops", "_occupied"];
    missionNamespace setVariable ["civ_locations", _pops apply { 0 }];
    {
        missionNamespace setVariable [format ["civ_pop_%1", _forEachIndex], _x];
        missionNamespace setVariable [format ["civ_spawned_%1", _forEachIndex], _forEachIndex in _occupied];
    } forEach _pops;
};

[[100, 30, 3], [0]] call _stage;
["liveTarget: a city alone gets the full density", ([15, 0] call fnc_civ_liveTarget), 15] call fnc_assertEq;
["liveTarget: the top option is not thinned either", ([30, 0] call fnc_civ_liveTarget), 30] call fnc_assertEq;

// The population is a building count, and a town too small to house the density says so. This is
// the floor the whole design rests on: three buildings can only ever be three people.
["liveTarget: a hamlet caps at its own population", ([10, 2] call fnc_civ_liveTarget), 3] call fnc_assertEq;
["liveTarget: an empty town holds nobody", ([10, 9] call fnc_civ_liveTarget), 0] call fnc_assertEq;

// Two occupied towns is the single-player peak -- walking into the next while the last drains --
// and it sits well inside the ceiling, so no solo transition is ever thinned.
[[100, 100, 100, 100], [0, 1]] call _stage;
["liveTarget: the single-player peak is untouched", ([15, 0] call fnc_civ_liveTarget), 15] call fnc_assertEq;

// Three towns at full density is exactly the ceiling, so the boundary itself is not thinned.
[[100, 100, 100, 100], [0, 1, 2]] call _stage;
["liveTarget: three occupied towns still pay in full", ([10, 0] call fnc_civ_liveTarget), 10] call fnc_assertEq;

// A fourth occupied town overruns it. Everyone thins rather than the last one starving.
[[100, 100, 100, 100], [0, 1, 2, 3]] call _stage;
["liveTarget: a fourth town thins the share", ([10, 0] call fnc_civ_liveTarget), 7] call fnc_assertEq;

// Only occupied towns count against the ceiling: an unvisited town has nobody in it to pay for.
[[100, 100, 100, 100], [0]] call _stage;
["liveTarget: unoccupied towns cost nothing", ([10, 0] call fnc_civ_liveTarget), 10] call fnc_assertEq;

// Past the point where the ceiling can cover a town each, the floor holds and the ceiling gives:
// a town nobody spawns in reads as broken, where a thin one only reads as quiet.
[[100, 100, 100, 100, 100, 100, 100, 100, 100, 100], [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]] call _stage;
["liveTarget: the floor outranks the ceiling", ([10, 0] call fnc_civ_liveTarget), 3] call fnc_assertEq;

// The ceiling is three times whatever the setting is, so no option thins any earlier than another.
[[100, 100, 100], [0, 1, 2]] call _stage;
{
    [format ["liveTarget: density %1 fills three towns", _x],
        ([_x, 0] call fnc_civ_liveTarget), _x] call fnc_assertEq;
} forEach [5, 10, 15, 20];

// The Altis survey registers two hamlets at 3 and 4 buildings and nothing else below 47, so the
// population cap only ever binds on those two. Every real town takes the setting whole, and what
// separates them is how much ground their cluster covers rather than how many people are in it.
[[3, 4, 47, 260], [0]] call _stage;
{
    _x params ["_town", "_pop", "_expected"];
    [format ["liveTarget: a %1-building town holds %2", _pop, _expected],
        ([15, _town] call fnc_civ_liveTarget), _expected] call fnc_assertEq;
} forEach [[0, 3, 3], [1, 4, 4], [2, 47, 15], [3, 260, 15]];

// --- fnc_search_drawKind: pick a payout kind in proportion to weight ---
// _roll is a 0-1 fraction standing in for the draw, so each band can be named rather than
// sampled. Weights 2/3/2/1 over a total of 8 put the boundaries at .25, .625 and .875.
private _w = [["intel", 2], ["pool", 3], ["coins", 2], ["document", 1]];

["drawKind: the bottom of the first band", ([_w, 0] call fnc_search_drawKind), "intel"] call fnc_assertEq;
["drawKind: just inside the first band", ([_w, 0.249] call fnc_search_drawKind), "intel"] call fnc_assertEq;
["drawKind: the boundary belongs to the next band", ([_w, 0.25] call fnc_search_drawKind), "pool"] call fnc_assertEq;
["drawKind: the widest band spans its whole width", ([_w, 0.624] call fnc_search_drawKind), "pool"] call fnc_assertEq;
["drawKind: third band", ([_w, 0.7] call fnc_search_drawKind), "coins"] call fnc_assertEq;
["drawKind: the last band takes the top of the range", ([_w, 1] call fnc_search_drawKind), "document"] call fnc_assertEq;

// A kind that reported nothing left is dropped and the rest re-drawn, so the table shrinks
// mid-search. What must not happen is the remainder failing to cover the full 0-1 range.
private _shrunk = [["coins", 2], ["document", 1]];
["drawKind: a shrunk table still covers the bottom", ([_shrunk, 0] call fnc_search_drawKind), "coins"] call fnc_assertEq;
["drawKind: a shrunk table still covers the top", ([_shrunk, 1] call fnc_search_drawKind), "document"] call fnc_assertEq;

["drawKind: a single row absorbs the whole range", ([[["intel", 1]], 0.9] call fnc_search_drawKind), "intel"] call fnc_assertEq;
["drawKind: an exhausted table draws nothing", ([[], 0.5] call fnc_search_drawKind), ""] call fnc_assertEq;
["drawKind: zero weights draw nothing rather than the first row",
    ([[["intel", 0], ["pool", 0]], 0.5] call fnc_search_drawKind), ""] call fnc_assertEq;

// A zero-weight row is how a source opts out of a kind; it must never be selectable.
["drawKind: a zero-weight row is skipped", ([[["intel", 0], ["pool", 1]], 0] call fnc_search_drawKind), "pool"] call fnc_assertEq;

// --- fnc_faction_rqst_list: the rows a faction actually filled ---
// The array comes from a faction file this mission does not own, and every caller reads `select 2`
// off each row it is handed. A short row therefore has to be dropped here rather than reach them.
blufor_RQST_UNITS = [["B_Soldier_F", "Rifleman", 2], ["B_medic_F", "Medic", 3]];
["rqstList: a well-formed table passes through whole",
    (["UNIT"] call fnc_faction_rqst_list),
    [["B_Soldier_F", "Rifleman", 2], ["B_medic_F", "Medic", 3]]] call fnc_assertEq;

blufor_RQST_UNITS = [["B_Soldier_F", "Rifleman", 2], ["B_medic_F", "Medic"], ["B_engineer_F", "Engineer", 4]];
["rqstList: a row with no cost is dropped, not carried into the menu",
    (["UNIT"] call fnc_faction_rqst_list),
    [["B_Soldier_F", "Rifleman", 2], ["B_engineer_F", "Engineer", 4]]] call fnc_assertEq;

blufor_RQST_UNITS = [["B_Soldier_F", "Rifleman", 2], "B_medic_F"];
["rqstList: a row that is not a row at all is dropped",
    (["UNIT"] call fnc_faction_rqst_list),
    [["B_Soldier_F", "Rifleman", 2]]] call fnc_assertEq;

// With no array global the numbered walk answers instead, which is what carries an unconverted
// third-party faction file. Slot 02 ends it, so slot 03 must not appear.
blufor_RQST_UNITS = [];
blufor_RQST_UNIT_01_X = ["B_Soldier_F", "Rifleman", 2];
blufor_RQST_UNIT_02_X = ["empty", "", 0];
blufor_RQST_UNIT_03_X = ["B_engineer_F", "Engineer", 4];
["rqstList: the numbered fallback stops at the padding",
    (["UNIT"] call fnc_faction_rqst_list),
    [["B_Soldier_F", "Rifleman", 2]]] call fnc_assertEq;

// --- fnc_factionRoles: the spawnable role list a faction table actually resolved ---
// Last block in the file: it captures fnc_log rather than stubbing it away, because the warning
// is what makes a faction table that resolved nothing visible at all, and it leaves fnc_log
// captured and opfor_SOLDIER_X undefined behind it.
DUWS_TEST_LOG = [];
fnc_log = { DUWS_TEST_LOG pushBack _this };

// Deliberately not the real classnames: a fake rifleman is the only way to tell "fell back to
// opfor_SOLDIER_X" apart from "fell back to the vanilla literal".
opfor_SOLDIER_X = "O_Soldier_F_fake";
opfor_AA_SOLDIER_X = "O_Soldier_AA_fake";
opfor_AR_SOLDIER_X = "O_Soldier_AR_fake";

["factionRoles: a table defining every role keeps all of them, in order",
    ([[opfor_SOLDIER_X, opfor_AA_SOLDIER_X, opfor_AR_SOLDIER_X], "opfor"] call fnc_factionRoles),
    ["O_Soldier_F_fake", "O_Soldier_AA_fake", "O_Soldier_AR_fake"]] call fnc_assertEq;

// The array literal is built at the call site, so a role the faction table never defined arrives
// as a nil element. This is the whole reason the list is walked instead of filtered.
["factionRoles: a role the table never defined is dropped, not spawned as nil",
    ([[opfor_SOLDIER_X, opfor_MISSING_ROLE_X, opfor_AR_SOLDIER_X], "opfor"] call fnc_factionRoles),
    ["O_Soldier_F_fake", "O_Soldier_AR_fake"]] call fnc_assertEq;

opfor_EMPTY_ROLE_X = "";
["factionRoles: a role defined as an empty string is dropped too",
    ([[opfor_SOLDIER_X, opfor_EMPTY_ROLE_X], "opfor"] call fnc_factionRoles),
    ["O_Soldier_F_fake"]] call fnc_assertEq;

DUWS_TEST_LOG = [];
["factionRoles: a table resolving nothing falls back to the rifleman",
    ([[opfor_MISSING_ROLE_X, opfor_ALSO_MISSING_X], "opfor"] call fnc_factionRoles),
    ["O_Soldier_F_fake"]] call fnc_assertEq;
["factionRoles: the fallback warns rather than degrading silently",
    (count DUWS_TEST_LOG), 1] call fnc_assertEq;

// The side reaches the fallback, which is the reason it is a parameter at all: a BLUFOR roster that
// resolved nothing must not hand back an enemy rifleman standing inside a friendly squad.
blufor_SOLDIER_X = "B_Soldier_F_fake";
["factionRoles: the fallback rifleman comes from the side asked for",
    ([[blufor_MISSING_ROLE_X], "blufor"] call fnc_factionRoles),
    ["B_Soldier_F_fake"]] call fnc_assertEq;

// The case the fallback used to miss: with no rifleman defined either, handing back
// [opfor_SOLDIER_X] returned [nil] -- the exact outcome the guard exists to prevent.
opfor_SOLDIER_X = nil;
["factionRoles: with no rifleman defined either, the fallback is a vanilla class",
    ([[opfor_MISSING_ROLE_X], "opfor"] call fnc_factionRoles), ["O_Soldier_F"]] call fnc_assertEq;

blufor_SOLDIER_X = nil;
["factionRoles: the vanilla fallback is the side's own, not the other army's",
    ([[blufor_MISSING_ROLE_X], "blufor"] call fnc_factionRoles), ["B_Soldier_F"]] call fnc_assertEq;

["factionRoles: no roles at all still yields a spawnable list",
    ([[], "opfor"] call fnc_factionRoles), ["O_Soldier_F"]] call fnc_assertEq;

// The shared attrition ledger (surviving / derive / seed / unlose / recordLoss / projection) is
// exercised below, after the stand-in composition tables it reads token men through are defined.

// --- fnc_zone_tier: a zone's inherent size ---
// fnc_zone_tier_roll is absent here on purpose: it needs selectRandomWeighted, which sqf-vm does not
// implement, and reshaping the roll to suit the harness would cost the mission its stated idiom.
["zone_tier: an unrolled zone is tier IV, so nothing regresses on a save that predates tiers",
    (["untiered"] call fnc_zone_tier), 4] call fnc_assertEq;

// --- the spawn composition framework ---
// Stand-in tables, not the shipped ones: these pin the mechanics -- token lookup, the access filter,
// attrition -- and the shipped numbers are balance, which a test should not freeze. The extractor
// pulls named functions, not the globals beside them, so they are set here.
// Bare role names, as the shipped table holds them: the side is prepended when the team is raised,
// which is what lets one row serve both armies.
DUWS_teamRosters = [
    ["patrol", ["A_X", "B_X"], ""],
    ["team", ["A_X", "C_X"], "TL_X"],
    ["wpteam", ["A_X"], ""],
    ["thin", ["A_X", "ABSENT_X"], ""],
    ["big", ["A_X", "A_X", "A_X", "A_X", "A_X", "A_X", "A_X", "A_X", "C_X"], "TL_X"]
];
DUWS_spawnVehicles = [
    ["car",    "opfor_CAR_X",  "",           0],
    ["at_car", "opfor_CAR_X",  "",           0],
    ["aa_car", "opfor_CAR_X",  "",           0],
    ["apc",    "opfor_APC_X",  "",           0],
    ["tank",   "opfor_TANK_X", "TEST_Heavy", 100],
    ["heli",   "opfor_HELI_X", "TEST_Air",   0],
    ["absent", "opfor_GONE_X", "",           0]
];
opfor_A_X = "cls_A";
opfor_B_X = "cls_B";
opfor_C_X = "cls_C";
opfor_TL_X = "cls_TL";
opfor_CAR_X = "cls_car";
opfor_APC_X = "cls_apc";
opfor_TANK_X = "cls_tank";
opfor_HELI_X = "cls_heli";
TEST_Heavy = 1;
TEST_Air = 1;
WARCOM_opfor_ap = 200;
DUWS_zoneSpawnTiers = [["patrol"], ["patrol", "car"], ["patrol", "apc"],
    ["patrol", "team", "car", "apc", "heli"]];

// --- fnc_faction_pick: one classname per spawn, drawn from the detected pool ---
// The pool is what detection found; the global is a stable representative for the two hundred-odd
// sites that read it directly. Picking happens where units are raised, so two zones standing up in
// the same second field different vehicles -- which is the variety the timed re-pick could not give.
DUWS_factionPool_opfor_TEST_X = ["cls_a", "cls_b", "cls_c"];
opfor_TEST_X = "cls_a";
["faction_pick: draws from the pool", (["opfor_TEST_X"] call fnc_faction_pick) in ["cls_a","cls_b","cls_c"], true] call fnc_assertEq;
// A hand-written faction file assigns a plain string and gets no pool. It must still answer.
opfor_PLAIN_X = "cls_plain";
["faction_pick: a role with no pool falls back to its global",
    (["opfor_PLAIN_X"] call fnc_faction_pick), "cls_plain"] call fnc_assertEq;
// Fail closed rather than inventing a class: fnc_factionRoles drops the empty answer, where a
// substitute would hide a missing role behind a unit that spawns.
["faction_pick: a role the faction never defined answers with nothing",
    (["opfor_NEVER_X"] call fnc_faction_pick), ""] call fnc_assertEq;
DUWS_factionPool_opfor_EMPTY_X = [];
opfor_EMPTY_X = [];
["faction_pick: an empty pool answers with nothing, not nil",
    (["opfor_EMPTY_X"] call fnc_faction_pick), ""] call fnc_assertEq;
// A static with no pool var but an array global -- a re-pick that left the global un-collapsed --
// answers with the representative, never a random draw. The pool gate clears a static's pool var, so
// randomising here would field the uncreatable variant that gate exists to keep out.
opfor_STATIC_ARR_X = ["cls_gun", "cls_variant"];
["faction_pick: a pool-less array global answers with the representative, not a random draw",
    (["opfor_STATIC_ARR_X"] call fnc_faction_pick), "cls_gun"] call fnc_assertEq;
// An optional filter narrows the candidates before the draw, so a caller can exclude classes a context
// must not field; "" when nothing passes, and a pool-less global is filtered the same way.
DUWS_factionPool_opfor_FILT_X = ["keep_1", "drop_1", "keep_2"];
["faction_pick: a filter keeps only the classes that pass",
    (["opfor_FILT_X", { (_this select 0) in ["keep_1", "keep_2"] }] call fnc_faction_pick) in ["keep_1", "keep_2"], true] call fnc_assertEq;
["faction_pick: a filter that rejects the whole pool answers with nothing",
    (["opfor_FILT_X", { false }] call fnc_faction_pick), ""] call fnc_assertEq;
opfor_FILTPLAIN_X = "only_class";
["faction_pick: a filter drops a pool-less global that fails it",
    (["opfor_FILTPLAIN_X", { false }] call fnc_faction_pick), ""] call fnc_assertEq;
["faction_pick: a pool-less global that passes the filter is kept",
    (["opfor_FILTPLAIN_X", { true }] call fnc_faction_pick), "only_class"] call fnc_assertEq;

// --- fnc_faction_poolable_keys: which roles fnc_faction_pools_publish gives a pool ---
// Pooling (a random draw per spawn) is for vehicle roles only: spawn variety is deliberately a
// vehicle feature, so a man role collapses to its single detected representative. A static holds one
// canonical piece, and a random draw there risks an import/proxy variant that clears detection's
// scope gate yet cannot be createVehicle'd -- a gunless emplacement.
// The gate reads the kind column of the schema, so it tracks whatever the schema files as a static.
DUWS_faction_poolableKeys = nil;                   // force a fresh build off the schema
private _poolable = call fnc_faction_poolable_keys;
["poolable_keys: an infantry role is not poolable", "opfor_SOLDIER_X" in _poolable, false] call fnc_assertEq;
["poolable_keys: a vehicle role is poolable", "opfor_APC1_X" in _poolable, true] call fnc_assertEq;
["poolable_keys: a static role is not poolable", "opfor_TURRET_AT" in _poolable, false] call fnc_assertEq;
["poolable_keys: a key the schema does not carry is not poolable", "opfor_MADEUP_X" in _poolable, false] call fnc_assertEq;

// --- the access filter: three reasons to drop a token, never to substitute one ---
// DUWS_fnc_tokenClass filters combat tokens by armament: car/apc/ifv/tank through
// DUWS_fnc_classGroundCapable, at_car/aa_car through DUWS_fnc_classAT/classAA. All three read
// CfgVehicles -- absent in sqf-vm -- so stub them permissive; the resolution tests here see the
// unfiltered draw, and each filter's own wiring is proven under a rejecting stub below.
DUWS_fnc_classGroundCapable = { true };
DUWS_fnc_classAT = { true };
DUWS_fnc_classAA = { true };
["tokenClass: a token resolves to the classname its faction role holds",
    (["apc"] call DUWS_fnc_tokenClass), "cls_apc"] call fnc_assertEq;
["tokenClass: a team answers for itself rather than resolving to a vehicle",
    (["patrol"] call DUWS_fnc_tokenClass), "patrol"] call fnc_assertEq;
["tokenClass: a classname no table claims stands as itself",
    (["O_MBT_02_cannon_F"] call DUWS_fnc_tokenClass), "O_MBT_02_cannon_F"] call fnc_assertEq;
["tokenClass: a role this faction never defined resolves to nothing",
    (["absent"] call DUWS_fnc_tokenClass), ""] call fnc_assertEq;
TEST_Air = 0;
["tokenClass: a campaign setting that is off drops the token",
    (["heli"] call DUWS_fnc_tokenClass), ""] call fnc_assertEq;
["spawnFilter: and the composition loses it rather than gaining a substitute",
    ([["patrol", "heli", "car"]] call DUWS_fnc_spawnFilter), ["patrol", "car"]] call fnc_assertEq;
TEST_Air = 1;
// Gated on the earned counter, not the spendable wallet -- the var DUWS_fnc_tokenClass reads, so a
// tier the side reached does not relock when the commander spends its wallet down.
WARCOM_opfor_ap_earned = 40;
["tokenClass: below its Army Power rung a token is not yet unlocked",
    (["tank"] call DUWS_fnc_tokenClass), ""] call fnc_assertEq;
["spawnFilter: a token below its rung is kept, locked, rather than dropped",
    ([["patrol", "tank"]] call DUWS_fnc_spawnFilter), ["patrol", "tank"]] call fnc_assertEq;
WARCOM_opfor_ap_earned = 100;
["tokenClass: reaching the rung unlocks it",
    (["tank"] call DUWS_fnc_tokenClass), "cls_tank"] call fnc_assertEq;
// The armament filter is wired to the combat tokens: a rejecting stub drops a car token to "", while
// an air token (never armament-filtered) still resolves. Restored permissive for the tests that follow.
DUWS_fnc_classGroundCapable = { false };
["tokenClass: a combat vehicle token is dropped when nothing passes the armament filter",
    (["car"] call DUWS_fnc_tokenClass), ""] call fnc_assertEq;
["tokenClass: an air token ignores the armament filter",
    (["heli"] call DUWS_fnc_tokenClass), "cls_heli"] call fnc_assertEq;
// at_car/aa_car take their own predicate, not the gun one: with the gun filter rejecting they still
// resolve off classAT/classAA, and drop only when their own predicate rejects.
["tokenClass: at_car resolves off its AT filter, not the gun filter",
    (["at_car"] call DUWS_fnc_tokenClass), "cls_car"] call fnc_assertEq;
["tokenClass: aa_car resolves off its AA filter, not the gun filter",
    (["aa_car"] call DUWS_fnc_tokenClass), "cls_car"] call fnc_assertEq;
DUWS_fnc_classGroundCapable = { true };
DUWS_fnc_classAT = { false };
["tokenClass: at_car is dropped when nothing passes the AT filter",
    (["at_car"] call DUWS_fnc_tokenClass), ""] call fnc_assertEq;
DUWS_fnc_classAA = { false };
["tokenClass: aa_car is dropped when nothing passes the AA filter",
    (["aa_car"] call DUWS_fnc_tokenClass), ""] call fnc_assertEq;
DUWS_fnc_classAT = { true };
DUWS_fnc_classAA = { true };
WARCOM_opfor_ap_earned = 200;

["zoneSpawnList: a tier fields its row, one group per entry",
    ([4] call DUWS_fnc_zoneSpawnList),
    ["patrol", "team", "car", "apc", "heli"]] call fnc_assertEq;
TEST_Air = 0;
["zoneSpawnList: a token the campaign switched off leaves a gap, not a substitute",
    ([4] call DUWS_fnc_zoneSpawnList), ["patrol", "team", "car", "apc"]] call fnc_assertEq;
TEST_Air = 1;
["zoneSpawnList: the tier is the whole of what a zone fields",
    ([1] call DUWS_fnc_zoneSpawnList), ["patrol"]] call fnc_assertEq;
["zoneSpawnList: a tier above the table clamps rather than faulting",
    ([9] call DUWS_fnc_zoneSpawnList), ["patrol", "team", "car", "apc", "heli"]] call fnc_assertEq;

// --- DUWS_fnc_spawnDiff: what an upgrade owes ---
["spawnDiff: only what the new composition adds",
    ([["patrol","team"], ["patrol","team","armored"]] call DUWS_fnc_spawnDiff), ["armored"]] call fnc_assertEq;
// Counting duplicates is the point: a tier going from one team to two owes one team, not two.
["spawnDiff: duplicates are counted, not matched once",
    ([["patrol","team"], ["patrol","team","team"]] call DUWS_fnc_spawnDiff), ["team"]] call fnc_assertEq;
["spawnDiff: an unchanged composition owes nothing",
    ([["patrol","team"], ["patrol","team"]] call DUWS_fnc_spawnDiff), []] call fnc_assertEq;
// A downgrade owes nothing rather than something negative: nothing is withdrawn to meet a smaller
// list, so a retuned table cannot order a standing garrison to shrink.
["spawnDiff: a smaller composition owes nothing",
    ([["patrol","team","armored"], ["patrol"]] call DUWS_fnc_spawnDiff), []] call fnc_assertEq;
["spawnDiff: seeding from nothing owes the whole list",
    ([[], ["patrol","team"]] call DUWS_fnc_spawnDiff), ["patrol","team"]] call fnc_assertEq;
private _have = ["patrol","team"];
[_have, ["patrol","team","armored"]] call DUWS_fnc_spawnDiff;
["spawnDiff: leaves the caller's standing list alone",
    _have, ["patrol","team"]] call fnc_assertEq;

// --- DUWS_fnc_teamRoster: the men behind a team name ---
// Against the fixture above rather than the shipped rosters: what is under test is how a row
// expands, and asserting on the live tables would fail every time one is rebalanced.
// One team, whatever the campaign settings say. How many of it a site fields is the composition's
// business now (DUWS_fnc_scaleComposition), which is what let the row drop to a role list.
["teamRoster: a row is one team",
    (["patrol", "opfor"] call DUWS_fnc_teamRoster), ["cls_A","cls_B"]] call fnc_assertEq;
["teamRoster: the leader leads",
    (["team", "opfor"] call DUWS_fnc_teamRoster), ["cls_TL","cls_A","cls_C"]] call fnc_assertEq;
["teamRoster: a role this faction does not define is dropped, not spawned as nil",
    (["thin", "opfor"] call DUWS_fnc_teamRoster), ["cls_A"]] call fnc_assertEq;
// Nothing rather than a fallback: the caller named a team that does not exist, and inventing men
// for it would hide the typo behind a garrison that spawns.
["teamRoster: an unknown team fields nothing",
    (["nosuchkind", "opfor"] call DUWS_fnc_teamRoster), []] call fnc_assertEq;
// The same answer is what tells the spawn path a token is a vehicle class rather than a team.
["teamRow: an unknown team has no row",
    (["nosuchkind"] call DUWS_fnc_teamRow), []] call fnc_assertEq;

["tokenName: a posture-carrying token names the team behind it",
    (["garrison:team"] call DUWS_fnc_tokenName), "team"] call fnc_assertEq;
["tokenName: a bare token is its own name",
    (["team"] call DUWS_fnc_tokenName), "team"] call fnc_assertEq;
["tokenPosture: the posture is the half before the colon",
    (["garrison:team"] call DUWS_fnc_tokenPosture), "garrison"] call fnc_assertEq;
// A bare token carries no posture, so it resolves to none: no standing orders, for a caller that
// raises a unit it drives itself. A caller wanting a patrol names the posture.
["tokenPosture: a bare token falls back to none, no standing orders",
    (["team"] call DUWS_fnc_tokenPosture), "none"] call fnc_assertEq;
// The lookups strip the posture themselves; a row matched on the whole string would find nothing.
["teamRow: a posture-carrying token still finds its roster row",
    ((["garrison:team"] call DUWS_fnc_teamRow) select 0), "team"] call fnc_assertEq;
["vehicleRow: and so does a vehicle's",
    ((["closepatrol:apc"] call DUWS_fnc_vehicleRow) select 0), "apc"] call fnc_assertEq;
// fnc_spawn_vehicle is handed this as a classname, so the posture has to be gone by here.
["tokenClass: a posture-carrying classname passes through without its posture",
    (["garrison:O_MBT_02_cannon_F"] call DUWS_fnc_tokenClass), "O_MBT_02_cannon_F"] call fnc_assertEq;
// A team stands up whole now -- attrition is the ledger of lost tokens, not a men-thin -- and its
// leader still leads.
["teamRoster: a team stands up whole",
    (count (["big", "opfor"] call DUWS_fnc_teamRoster)), 10] call fnc_assertEq;
["teamRoster: the leader leads",
    ((["big", "opfor"] call DUWS_fnc_teamRoster) select 0), "cls_TL"] call fnc_assertEq;

// The join that makes one table serve both armies: the row names a role, the side names the army.
// Same row, same order, other side's men.
blufor_A_X = "cls_blu_A";
blufor_B_X = "cls_blu_B";
["teamRoster: the side is prepended, so one row raises either army",
    (["patrol", "blufor"] call DUWS_fnc_teamRoster), ["cls_blu_A", "cls_blu_B"]] call fnc_assertEq;

// --- DUWS_fnc_tokenMenCount / tokenListMen: owed men, counted not built ---
// The reserve accounting cannot build a roster to size the pool: the capture trigger polls the owed
// count several times a second, and a build would resolve faction picks and raise men. So the count
// mirrors DUWS_fnc_teamRoster's arithmetic directly -- leader plus roles -- raising nothing. Whole
// tokens: attrition is a ledger of lost tokens now, so a placed token owes its full men.
["tokenMenCount: a leaderless team is its role count",
    (["patrol"] call DUWS_fnc_tokenMenCount), 2] call fnc_assertEq;
["tokenMenCount: a led team counts its leader",
    (["team"] call DUWS_fnc_tokenMenCount), 3] call fnc_assertEq;
["tokenMenCount: a whole team is its full roster and leader",
    (["big"] call DUWS_fnc_tokenMenCount), 10] call fnc_assertEq;
// The posture prefix is the group's orders, not its size: stripped before the row is counted.
["tokenMenCount: the posture prefix does not change the count",
    (["garrison:team"] call DUWS_fnc_tokenMenCount), 3] call fnc_assertEq;
// A vehicle or bare-class token owes no infantry men: the pool counts crews as zero, the same measure
// the projection's denominator uses, so the two stay consistent.
["tokenMenCount: a vehicle token owes no infantry men",
    (["car"] call DUWS_fnc_tokenMenCount), 0] call fnc_assertEq;
["tokenMenCount: an unknown token owes nothing",
    (["nosuchkind"] call DUWS_fnc_tokenMenCount), 0] call fnc_assertEq;
// The men a list owes are the sum over its tokens: patrol two, team three, car none.
["tokenListMen: sums the tokens it is given",
    ([["patrol", "team", "car"]] call DUWS_fnc_tokenListMen), 5] call fnc_assertEq;
["tokenListMen: an empty list owes nothing",
    ([[]] call DUWS_fnc_tokenListMen), 0] call fnc_assertEq;
["tokenListMen: two whole teams are twice the men",
    ([["big", "big"]] call DUWS_fnc_tokenListMen), 20] call fnc_assertEq;

// --- the garrison strength ledger: full minus lost, whole tokens ---
// The ledger keys off the site key, so each case seeds its own key's state and reads it back. A zone
// and a town read exactly these functions; the split below is what both raises derive their garrison
// and reserve pool from.
missionNamespace setVariable ["DUWS_garrisonLost_svk", ["patrol"]];
["svk", ["patrol", "patrol", "team"]] call DUWS_fnc_garrisonSetFull;
["garrisonSurviving: full potential minus the lost ledger, by value",
    (["svk"] call DUWS_fnc_garrisonSurviving), ["patrol", "team"]] call fnc_assertEq;

// The split: the first x1's worth stand up as the garrison and the surplus is the reserve pool, so a
// lost token comes out of the pool before it thins the garrison. Arbitrary string tokens -- the split
// is by multiset value, not by men.
missionNamespace setVariable ["DUWS_garrisonLost_dvk", []];
["garrisonDerive: a full ledger stands up the x1 garrison and pools the surplus",
    (["dvk", ["a", "b", "c"], 2] call DUWS_fnc_garrisonDerive),
    [["a", "b", "c"], ["a", "b", "c"]]] call fnc_assertEq;
missionNamespace setVariable ["DUWS_garrisonLost_dvk", ["a"]];
["garrisonDerive: a lost token comes out of the pool, not the garrison",
    (["dvk", ["a", "b", "c"], 2] call DUWS_fnc_garrisonDerive),
    [["a", "b", "c"], ["b", "c"]]] call fnc_assertEq;

// recordLoss: bounded at a token's count in full, so a double-fired killed handler cannot overcount and
// a token that was never in the composition cannot drive strength negative.
missionNamespace setVariable ["DUWS_garrisonLost_rk", []];
["rk", ["patrol", "patrol"]] call DUWS_fnc_garrisonSetFull;
["rk", "patrol"] call DUWS_fnc_garrisonRecordLoss;
["rk", "patrol"] call DUWS_fnc_garrisonRecordLoss;
["rk", "patrol"] call DUWS_fnc_garrisonRecordLoss;
["recordLoss: a token cannot be lost more times than it exists",
    (count (["rk"] call DUWS_fnc_garrisonLost)), 2] call fnc_assertEq;
["rk", "team"] call DUWS_fnc_garrisonRecordLoss;
["recordLoss: a token not in the full potential is ignored",
    (count (["rk"] call DUWS_fnc_garrisonLost)), 2] call fnc_assertEq;

// The projection the map bar reads: surviving tokens over full tokens. Full for ground with no full stamped.
missionNamespace setVariable ["DUWS_garrisonLost_pk", []];
["pk", ["patrol", "team"]] call DUWS_fnc_garrisonSetFull;
["garrisonStrength: a fresh ledger is full strength",
    (["pk"] call DUWS_fnc_garrisonStrength), 1] call fnc_assertClose;
missionNamespace setVariable ["DUWS_garrisonLost_pk", ["team"]];
["garrisonStrength: counts tokens, so a lost 6-man team weighs the same as a 2-man patrol",
    (["pk"] call DUWS_fnc_garrisonStrength), 0.5] call fnc_assertClose;
["garrisonStrength: a site with no full stamped reads full",
    (["untouched_key"] call DUWS_fnc_garrisonStrength), 1] call fnc_assertClose;
missionNamespace setVariable ["DUWS_garrisonLost_pk", ["patrol", "patrol", "team"]];
["garrisonStrength: losses filed against an older, larger full never read below empty",
    (["pk"] call DUWS_fnc_garrisonStrength), 0] call fnc_assertClose;

// Locked tokens: stamped into full, counted nowhere until the side earns their rung (tank sits at 100 here).
WARCOM_opfor_ap_earned = 40;
missionNamespace setVariable ["DUWS_garrisonLost_lk", []];
["lk", ["patrol", "tank", "patrol", "tank"]] call DUWS_fnc_garrisonSetFull;
["garrisonFull: a locked token is left out of full",
    (["lk"] call DUWS_fnc_garrisonFull), ["patrol", "patrol"]] call fnc_assertEq;
["garrisonLocked: and listed on its own",
    (["lk"] call DUWS_fnc_garrisonLocked), ["tank", "tank"]] call fnc_assertEq;
["garrisonStrength: a locked token does not read as missing",
    (["lk"] call DUWS_fnc_garrisonStrength), 1] call fnc_assertClose;
WARCOM_opfor_ap_earned = 200;
["garrisonFull: earning the rung counts it, with no restamp",
    (count (["lk"] call DUWS_fnc_garrisonFull)), 4] call fnc_assertEq;

WARCOM_opfor_ap_earned = 40;
missionNamespace setVariable ["DUWS_garrisonLost_lsk", []];
["lsk", ["patrol", "patrol", "tank"]] call DUWS_fnc_garrisonSetFull;
["lsk", 2] call DUWS_fnc_garrisonSeed;
WARCOM_opfor_ap_earned = 200;
["garrisonSeed: a locked token is filed lost, so its rung refills nothing",
    (["lsk"] call DUWS_fnc_garrisonSurviving), ["patrol", "patrol"]] call fnc_assertEq;

WARCOM_opfor_ap_earned = 40;
missionNamespace setVariable ["DUWS_garrisonLost_luk", ["tank", "patrol"]];
["luk", ["patrol", "tank"]] call DUWS_fnc_garrisonSetFull;
["luk", 1] call DUWS_fnc_garrisonUnlose;
["garrisonUnlose: buys back an unlocked token before a locked one",
    (["luk"] call DUWS_fnc_garrisonLost), ["tank"]] call fnc_assertEq;

missionNamespace setVariable ["DUWS_garrisonLost_lgk", []];
["lgk", ["a"], ["a", "b", "tank"]] call DUWS_fnc_garrisonBuyTier;
["garrisonBuyTier: the fielded tenth is unlocked; the locked token is filed lost",
    (["lgk"] call DUWS_fnc_garrisonLost), ["tank"]] call fnc_assertEq;
WARCOM_opfor_ap_earned = 200;

// seed: keep a set number of tokens and file the rest lost -- a recaptured zone, a town OPFOR take.
missionNamespace setVariable ["DUWS_garrisonLost_seedk", []];
["seedk", ["patrol", "patrol", "patrol", "patrol"]] call DUWS_fnc_garrisonSetFull;
["seedk", 2] call DUWS_fnc_garrisonSeed;
["garrisonSeed: keeps the given number of tokens",
    (["seedk"] call DUWS_fnc_garrisonStrength), 0.5] call fnc_assertClose;

// An OPFOR cap stands a tenth of the tier I list, rounded up, against a full restamped to that list.
missionNamespace setVariable ["DUWS_garrisonLost_capk", ["tank", "tank"]];
["capk", ["a", "b", "c", "d", "e", "f", "g"]] call DUWS_fnc_garrisonSeedOpforCap;
["garrisonSeedOpforCap: full is restamped at the tier I list",
    (count (["capk"] call DUWS_fnc_garrisonFull)), 7] call fnc_assertEq;
["garrisonSeedOpforCap: a tenth of seven rounds up to one token kept",
    (count (["capk"] call DUWS_fnc_garrisonSurviving)), 1] call fnc_assertEq;

// unlose: a paid reinforcement buys destroyed tokens back -- the one thing that raises strength.
missionNamespace setVariable ["DUWS_garrisonLost_uk", ["patrol", "patrol", "patrol"]];
["uk", ["patrol", "patrol", "patrol", "patrol"]] call DUWS_fnc_garrisonSetFull;
["uk", 1] call DUWS_fnc_garrisonUnlose;
["garrisonUnlose: buys back the given number of tokens",
    (["uk"] call DUWS_fnc_garrisonStrength), 0.5] call fnc_assertClose;
["uk", 5] call DUWS_fnc_garrisonUnlose;
["garrisonUnlose: never buys back more than was lost",
    (["uk"] call DUWS_fnc_garrisonLost), []] call fnc_assertEq;

missionNamespace setVariable ["DUWS_garrisonLost_gk", []];
["gk", ["a"], ["a", "b", "b", "b", "b", "b", "b", "b", "b", "b", "b"]] call DUWS_fnc_garrisonBuyTier;
["garrisonBuyTier: a tenth of the added tokens is fielded, the rest filed lost",
    (["gk"] call DUWS_fnc_garrisonLost), ["b", "b", "b", "b", "b", "b", "b", "b", "b"]] call fnc_assertEq;
["garrisonBuyTier: full potential is stamped at the new tier",
    (["gk"] call DUWS_fnc_garrisonFull), ["a", "b", "b", "b", "b", "b", "b", "b", "b", "b", "b"]] call fnc_assertEq;
missionNamespace setVariable ["DUWS_garrisonLost_gk", []];
["gk", ["a"], ["a", "b", "b", "b", "b", "b", "b", "b", "b", "b"]] call DUWS_fnc_garrisonBuyTier;
["garrisonBuyTier: under ten added tokens, a tenth rounds up to one fielded",
    (count (["gk"] call DUWS_fnc_garrisonLost)), 8] call fnc_assertEq;
missionNamespace setVariable ["DUWS_garrisonLost_gk", ["b", "b"]];
["gk", [], ["b", "b"]] call DUWS_fnc_garrisonBuyTier;
["garrisonBuyTier: a token already lost up to its count in the new full is not filed again",
    (["gk"] call DUWS_fnc_garrisonLost), ["b", "b"]] call fnc_assertEq;
missionNamespace setVariable ["DUWS_garrisonLost_gk", []];
enemyunitMultiplier = 2;
["gk", ["a"], ["a", "b", "b", "b", "b", "b"]] call DUWS_fnc_garrisonBuyTier;
enemyunitMultiplier = nil;
["garrisonBuyTier: the tenth is taken of every multiplier copy the tier adds",
    (count (["gk"] call DUWS_fnc_garrisonLost)), 9] call fnc_assertEq;

DUWS_zoneGroupCeiling = 130;
DUWS_fnc_opforGroupCount = { 0 };
missionNamespace setVariable ["DUWS_zoneCeiling_sfk", 4];
["sfk", ["patrol", "opcomdef7:team", "absent"]] call DUWS_fnc_garrisonReserveSet;
["garrisonStandFill: a raise stands to its ceiling, base tokens before OPCOM's",
    (["sfk", ["team", "team"]] call DUWS_fnc_garrisonStandFill), ["team", "team", "patrol", "opcomdef7:team"]] call fnc_assertEq;
["garrisonStandFill: what it draws leaves the pool, and an unfieldable token stays",
    (["sfk"] call DUWS_fnc_garrisonReserve), ["absent"]] call fnc_assertEq;
missionNamespace setVariable ["DUWS_zoneCeiling_sfk", 3];
["sfk", ["patrol", "patrol", "opcomdef7:team"]] call DUWS_fnc_garrisonReserveSet;
["garrisonStandFill: base tokens take the room before an OPCOM token",
    (["sfk", ["team"]] call DUWS_fnc_garrisonStandFill), ["team", "patrol", "patrol"]] call fnc_assertEq;
["garrisonStandFill: an OPCOM token left without room stays pooled",
    (["sfk"] call DUWS_fnc_garrisonReserve), ["opcomdef7:team"]] call fnc_assertEq;
["garrisonStandFill: a garrison already at its ceiling draws nothing",
    (["sfk", ["team", "team", "team"]] call DUWS_fnc_garrisonStandFill), ["team", "team", "team"]] call fnc_assertEq;
DUWS_fnc_opforGroupCount = { 128 };
["sfk", ["patrol", "patrol"]] call DUWS_fnc_garrisonReserveSet;
["garrisonStandFill: the global group wall caps the draw",
    (["sfk", ["team"]] call DUWS_fnc_garrisonStandFill), ["team", "patrol"]] call fnc_assertEq;

["rfk", ["patrol"]] call DUWS_fnc_garrisonReserveSet;
["rfk", ["team", "car"], [createGroup east]] call DUWS_fnc_garrisonRefundUnplaced;
["garrisonRefundUnplaced: a token whose group stands empty, or that raised no group, returns to the pool",
    (["rfk"] call DUWS_fnc_garrisonReserve), ["patrol", "team", "car"]] call fnc_assertEq;
["rfk", [], []] call DUWS_fnc_garrisonRefundUnplaced;
["garrisonRefundUnplaced: nothing unplaced leaves the pool as it was",
    (["rfk"] call DUWS_fnc_garrisonReserve), ["patrol", "team", "car"]] call fnc_assertEq;

// --- DUWS_fnc_scaleComposition: the enemy multiplier, applied to cards ---
// A x3 zone fields three patrols rather than one patrol of six men, so a group's size stops being a
// campaign setting and a squad's leader is not outnumbered by his own automatic riflemen.
["scaleComposition: teams and vehicles multiply",
    ([["patrol", "car"], 3] call DUWS_fnc_scaleComposition),
    ["patrol", "patrol", "patrol", "car", "car", "car"]] call fnc_assertEq;
["scaleComposition: the posture rides along with the card it belongs to",
    ([["garrison:team"], 2] call DUWS_fnc_scaleComposition),
    ["garrison:team", "garrison:team"]] call fnc_assertEq;
["scaleComposition: x1 leaves the composition as written",
    ([["patrol", "car"], 1] call DUWS_fnc_scaleComposition),
    ["patrol", "car"]] call fnc_assertEq;
// A campaign that predates the setting reads no multiplier at all; clamping beats fielding nothing.
["scaleComposition: a multiplier below one still fields the composition once",
    ([["patrol"], 0] call DUWS_fnc_scaleComposition), ["patrol"]] call fnc_assertEq;
private _written = ["patrol", "car"];
[_written, 3] call DUWS_fnc_scaleComposition;
["scaleComposition: leaves the caller's composition alone",
    _written, ["patrol", "car"]] call fnc_assertEq;

// The multiplier is reserve depth now, not a live-force scale: the spawn list is the x1 tier row
// whatever the campaign multiplier says, and the surplus copies seed a reserve pool instead of
// standing on the ground. The pool and the peak are fnc_zone_spawn's, which raises men and so is out
// of the unit suite's reach; here the contract is only that the live list stops scaling.
enemyunitMultiplier = 3;
["zoneSpawnList: the multiplier no longer scales the live composition",
    ([1] call DUWS_fnc_zoneSpawnList), ["patrol"]] call fnc_assertEq;
enemyunitMultiplier = 1;

// --- fnc_selectNonEmpty: first non-empty candidate, and never nil ---
["selectNonEmpty: the first non-empty candidate wins",
    ([[], ["b"], ["c"]] call fnc_selectNonEmpty), ["b"]] call fnc_assertEq;
// The defect this guards: `select 0` on an empty array is nil, and assigning nil UNDEFINES the
// role global -- so a faction fielding no static AA took down every later read of _turretAA,
// including the array fnc_parseFaction returns.
["selectNonEmpty: every candidate empty gives [], not nil",
    ([[], [], []] call fnc_selectNonEmpty), []] call fnc_assertEq;
["selectNonEmpty: no candidates at all gives []",
    ([] call fnc_selectNonEmpty), []] call fnc_assertEq;

// --- fnc_faction_resolve: ladder walk, kind gate, fallback ---
// The gate itself reads CfgVehicles, which sqf-vm has none of, so it is stubbed by one that drops
// a marker class. What is under test is the walk: which rung wins, what reaches the gate, and
// what a key holds when nothing does.
fnc_log = {};
TEST_KIND = "";
fnc_faction_keep = {
    params ["_classes", "_kind"];
    TEST_KIND = _kind;
    _classes select { _x != "rejected" }
};

["faction_resolve: the first rung with anything in it wins",
    (["opfor_AT_SOLDIER_X", [[], ["hat_1"], ["lat_1"]], "O_Soldier_AT_F"] call fnc_faction_resolve),
    ["hat_1"]] call fnc_assertEq;
["faction_resolve: and the key holds what was resolved",
    (missionNamespace getVariable "opfor_AT_SOLDIER_X"), ["hat_1"]] call fnc_assertEq;
["faction_resolve: kind comes from the schema, not the call site",
    TEST_KIND, "man"] call fnc_assertEq;
["faction_resolve: a rung the gate empties is skipped, not accepted",
    (["opfor_AT_SOLDIER_X", [["rejected"], ["lat_1"]], "O_Soldier_AT_F"] call fnc_faction_resolve),
    ["lat_1"]] call fnc_assertEq;
["faction_resolve: every rung empty falls back",
    (["opfor_AT_SOLDIER_X", [[], []], "O_Soldier_AT_F"] call fnc_faction_resolve),
    ["O_Soldier_AT_F"]] call fnc_assertEq;
// A role the faction never fields is left empty on purpose: fnc_faction_pick returns "" and
// fnc_factionRoles drops it, where inventing a class would hide the gap behind a unit that spawns.
["faction_resolve: nothing survives, including the fallback, gives []",
    (["opfor_AT_SOLDIER_X", [[], []], "rejected"] call fnc_faction_resolve), []] call fnc_assertEq;
["faction_resolve: a vehicle key is gated as a vehicle",
    (["opfor_MBT_TANK1_X", [["tank_1"]], "O_MBT_02_cannon_F"] call fnc_faction_resolve),
    ["tank_1"]] call fnc_assertEq;
["faction_resolve: ... and its kind says so", TEST_KIND, "vehicle"] call fnc_assertEq;
["faction_resolve: a blufor key reads the blufor schema",
    (["blufor_TURRET_HMG", [["hmg_1"]], "B_HMG_01_high_F"] call fnc_faction_resolve),
    ["hmg_1"]] call fnc_assertEq;
["faction_resolve: ... whose statics are gated as statics", TEST_KIND, "static"] call fnc_assertEq;
// A misspelled key has no schema row. It resolves ungated rather than silently emptying the role,
// which is what a typo used to do.
["faction_resolve: a key outside the schema still resolves",
    (["blufor_SOLDER_X", [["typo_1"]], "B_Soldier_F"] call fnc_faction_resolve),
    ["typo_1"]] call fnc_assertEq;
["faction_resolve: ... with no kind to gate on", TEST_KIND, ""] call fnc_assertEq;

// The tier the confirmation screen colours from: 0 the faction's own first choice, 1 a lower rung it
// still fills, 2 the vanilla stand-in or nothing at all. Read off the key the resolve just set.
["opfor_AT_SOLDIER_X", [["hat_1"], ["lat_1"]], "O_Soldier_AT_F"] call fnc_faction_resolve;
["faction_resolve: the primary rung is tier 0 (white)",
    (missionNamespace getVariable "DUWS_factionTier_opfor_AT_SOLDIER_X"), 0] call fnc_assertEq;
["opfor_AT_SOLDIER_X", [[], ["lat_1"]], "O_Soldier_AT_F"] call fnc_faction_resolve;
["faction_resolve: a lower rung is tier 1 (yellow)",
    (missionNamespace getVariable "DUWS_factionTier_opfor_AT_SOLDIER_X"), 1] call fnc_assertEq;
["opfor_AT_SOLDIER_X", [[], []], "O_Soldier_AT_F"] call fnc_faction_resolve;
["faction_resolve: the vanilla fallback is tier 2 (red)",
    (missionNamespace getVariable "DUWS_factionTier_opfor_AT_SOLDIER_X"), 2] call fnc_assertEq;
["opfor_AT_SOLDIER_X", [[], []], "rejected"] call fnc_faction_resolve;
["faction_resolve: nothing left at all is tier 2 (red), same as a stand-in",
    (missionNamespace getVariable "DUWS_factionTier_opfor_AT_SOLDIER_X"), 2] call fnc_assertEq;

// Omitting the fallback takes the key's vanilla default from the schema -- what the AutoDetect
// tables now rely on, having dropped their inline column so a stand-in is written in one place.
["opfor_MBT_TANK1_X", [[]]] call fnc_faction_resolve;
["faction_resolve: an omitted fallback comes from the schema vanillaDefault",
    (missionNamespace getVariable "opfor_MBT_TANK1_X"), ["O_MBT_02_cannon_F"]] call fnc_assertEq;

// --- fnc_faction_schema: the required and vanilla-default columns ---
// A row short of the required flag reads `nil` there, which fnc_custom_faction_parse's filter would
// treat as false -- silently dropping a core key out of paste validation. The fifth column is the
// stand-in fnc_faction_resolve and fnc_faction_vanilla_fill both read; a row missing it would hand
// "" to a spawner as the fallback.
private _rows = (["blufor"] call fnc_faction_schema) + (["opfor"] call fnc_faction_schema);
["faction_schema: every row carries all five columns",
    (_rows findIf { count _x != 5 }), -1] call fnc_assertEq;
["faction_schema: every row's vanilla default is a classname string",
    (_rows findIf { !((_x select 4) isEqualType "") }), -1] call fnc_assertEq;
["faction_schema: both sides field the same five statics",
    (_rows select {(_x select 1) isEqualTo "STATIC"} apply {_x select 0}),
    ["blufor_TURRET_AA", "blufor_TURRET_AT", "blufor_TURRET_HMG", "blufor_TURRET_GMG",
     "blufor_TURRET_MORTAR", "opfor_TURRET_AA", "opfor_TURRET_AT", "opfor_TURRET_HMG",
     "opfor_TURRET_GMG", "opfor_TURRET_MORTAR"]] call fnc_assertEq;
// The keys no shipped faction file defines -- the three roles the shared rosters name that BLUFOR
// has never had, and the statics and the gun added after the faction files were written. Marking one
// required fails every paste a player already has, including one copied out of factions/MODERN/.
["faction_schema: the keys no faction file defines are optional",
    (_rows select {!(_x select 3)} apply {_x select 0}),
    ["blufor_AA_SOLDIER_X", "blufor_AT_SOLDIER_X", "blufor_SNIPER_SOLDIER_X",
     "blufor_MEDIC_X", "blufor_TURRET_MORTAR", "opfor_MEDIC_X", "opfor_TURRET_AA",
     "opfor_TURRET_AT", "opfor_TURRET_GMG", "opfor_TURRET_MORTAR", "opfor_ARTY_X",
     "opfor_BOAT_ARMED_X"]] call fnc_assertEq;

// What lets a roster name a role bare: the same key in the same slot on both sides. A pair that
// drifts apart puts one army's row on the wrong line of the confirmation screen and, worse, makes a
// shared team row resolve on one side only.
// select [7] / select [6] drop "blufor_" and "opfor_", leaving the bare role a roster row names.
private _shared = ["INFANTRY", "VEHICLES", "STATIC", "OPERATORS"];
["faction_schema: the shared sections hold the same roles in the same order on both sides",
    ((["blufor"] call fnc_faction_schema) select {(_x select 1) in _shared}
        apply {(_x select 0) select [7]}),
    ((["opfor"] call fnc_faction_schema) select {(_x select 1) in _shared}
        apply {(_x select 0) select [6]})] call fnc_assertEq;

// --- fnc_faction_backfill: a role one side's faction files never named ---
// Stand-in table, as everywhere else here: what is under test is that an empty key borrows from the
// first rung that resolves and a filled one is left alone, not which roles the shipped ladder names.
DUWS_roleFallbacks = [
    ["TEST_AA_X",      ["TEST_SPEC_AA_X", "TEST_LAT_X", "TEST_RIFLE_X"]],
    ["TEST_KEPT_X",    ["TEST_RIFLE_X"]],
    ["TEST_NOWHERE_X", ["TEST_ABSENT_X"]]
];
blufor_TEST_RIFLE_X = "cls_rifle";
blufor_TEST_LAT_X = ["cls_lat1", "cls_lat2"];
blufor_TEST_SPEC_AA_X = "";
blufor_TEST_AA_X = "";
blufor_TEST_KEPT_X = "cls_kept";
blufor_TEST_NOWHERE_X = "";

// Captured again rather than silenced: the log line is the borrow being visible at all, which is
// the whole difference between this and the roles quietly going missing.
DUWS_TEST_LOG = [];
fnc_log = { DUWS_TEST_LOG pushBack _this };
["blufor"] call fnc_faction_backfill;

// The empty rung above it is skipped, so the ladder reads as what the role degrades through. The
// whole pool crosses rather than one class off the top of it, or the borrowed role would be the one
// slot in a composition that never varies.
["backfill: an empty key takes the first rung that resolves, pool and all",
    blufor_TEST_AA_X, ["cls_lat1", "cls_lat2"]] call fnc_assertEq;
["backfill: a key the faction defined is left alone",
    blufor_TEST_KEPT_X, "cls_kept"] call fnc_assertEq;
// Inventing a class here would hide a missing role behind a man who spawns, which is the failure
// this whole area is built to avoid.
["backfill: a key with no rung under it stays empty",
    blufor_TEST_NOWHERE_X, ""] call fnc_assertEq;
["backfill: it says so either way -- one borrow and one gap",
    (count DUWS_TEST_LOG), 2] call fnc_assertEq;

// --- fnc_faction_vanilla_fill: the schema stand-in for a key a preset or paste left empty ---
// Stubbed gate again, dropping "" and two markers: "absent" for a value the install lacks, and the
// real O_Mortar_01_F so the default-missing branch has something to reject. Everything else is kept,
// as a present class would be. The schema is real, so the defaults come from the shipped table.
fnc_faction_keep = {
    params ["_classes", "_kind"];
    _classes select { _x != "" && {_x != "absent"} && {_x != "O_Mortar_01_F"} }
};
fnc_log = {};

opfor_SOLDIER_X = "cls_native";
missionNamespace setVariable ["DUWS_factionTier_opfor_SOLDIER_X", 0];
opfor_ARTY_X = "";
opfor_APC1_X = "absent";
opfor_TURRET_MORTAR = "";
missionNamespace setVariable ["DUWS_factionTier_opfor_TURRET_MORTAR", 0];

["opfor"] call fnc_faction_vanilla_fill;

["vanilla_fill: a key the faction filled is left alone",
    opfor_SOLDIER_X, "cls_native"] call fnc_assertEq;
["vanilla_fill: ... and keeps its tier",
    (missionNamespace getVariable "DUWS_factionTier_opfor_SOLDIER_X"), 0] call fnc_assertEq;
["vanilla_fill: an empty key takes the schema vanilla default",
    opfor_ARTY_X, ["O_MBT_02_arty_F"]] call fnc_assertEq;
["vanilla_fill: ... flagged tier 2 (red), same as a resolved stand-in",
    (missionNamespace getVariable "DUWS_factionTier_opfor_ARTY_X"), 2] call fnc_assertEq;
["vanilla_fill: a key pointing at an absent class is refilled from the default",
    opfor_APC1_X, ["O_APC_Tracked_02_cannon_F"]] call fnc_assertEq;
// A stand-in the install itself lacks is no better than "": left empty and never flagged filled.
["vanilla_fill: an empty key whose default is absent stays empty",
    opfor_TURRET_MORTAR, ""] call fnc_assertEq;
["vanilla_fill: ... and is not marked tier 2",
    (missionNamespace getVariable "DUWS_factionTier_opfor_TURRET_MORTAR"), 0] call fnc_assertEq;

// --- fnc_static_resolve: placeholder class to faction class ---
// The table is stubbed to two rows: what is under test is which key a placeholder asks for and what
// it answers when the key is empty, not the shipped table's contents. sqf-vm has no CfgVehicles, so
// isKindOf is false for everything and the type test always fails closed -- which is what makes the
// last case here assert the refusal rather than the happy path.
DUWS_staticRoles = [["B_Mortar_01_F", "MORTAR"], ["B_HMG_01_high_F", "HMG"]];
TEST_ASKED = [];
fnc_faction_pick = { TEST_ASKED pushBack _this; TEST_PICK };
TEST_PICK = "";

["static_resolve: a class no row names stands as itself",
    (["Land_BagFence_Round_F", "opfor"] call fnc_static_resolve),
    "Land_BagFence_Round_F"] call fnc_assertEq;
["static_resolve: ... without asking the faction anything", TEST_ASKED, []] call fnc_assertEq;

// The whole point of the table: the placeholder's side is not the placing side.
TEST_ASKED = [];
["static_resolve: a mapped class asks its own side for the role the table names",
    (["B_Mortar_01_F", "opfor"] call fnc_static_resolve), "B_Mortar_01_F"] call fnc_assertEq;
["static_resolve: ... falling to the side's MG when the role is empty",
    TEST_ASKED, [["opfor_TURRET_MORTAR"], ["opfor_TURRET_HMG"]]] call fnc_assertEq;

TEST_ASKED = [];
["static_resolve: a row that names its key skips the table",
    (["B_Mortar_01_F", "blufor", "blufor_TURRET_AA"] call fnc_static_resolve),
    "B_Mortar_01_F"] call fnc_assertEq;
["static_resolve: ... and asks for that key",
    (TEST_ASKED select 0), ["blufor_TURRET_AA"]] call fnc_assertEq;

// Fail-closed: a mod "static" configured as a car would be placed, never crewed, never crewed out,
// and swept away as an abandoned vehicle.
TEST_PICK = "some_mod_car_F";
["static_resolve: a class that is not a StaticWeapon is refused",
    (["B_HMG_01_high_F", "blufor"] call fnc_static_resolve), "B_HMG_01_high_F"] call fnc_assertEq;

// Artillery is the one role whose piece is a vehicle, so both of the guards above are wrong for it:
// the refusal would reject every gun there is, and the MG substitute would put a machine gun where a
// battery belongs. isKindOf is false for everything under sqf-vm, which is what makes the first case
// here a test of the gate being skipped rather than of the class it was handed.
DUWS_staticRoles = [["B_MBT_01_arty_F", "ARTY"], ["B_HMG_01_high_F", "HMG"]];
TEST_ASKED = [];
TEST_PICK = "some_mod_spg_F";
["static_resolve: an artillery piece is not held to the StaticWeapon test",
    (["B_MBT_01_arty_F", "opfor"] call fnc_static_resolve), "some_mod_spg_F"] call fnc_assertEq;
["static_resolve: ... and asks the side's artillery key, not a turret one",
    TEST_ASKED, [["opfor_ARTY_X"]]] call fnc_assertEq;

TEST_ASKED = [];
TEST_PICK = "";
["static_resolve: a side fielding no artillery keeps the placeholder",
    (["B_MBT_01_arty_F", "opfor"] call fnc_static_resolve), "B_MBT_01_arty_F"] call fnc_assertEq;
["static_resolve: ... without falling to the MG nest a turret role would take",
    TEST_ASKED, [["opfor_ARTY_X"]]] call fnc_assertEq;

// --- fnc_hardpoint_score: terrain suitability multiplier per hardpoint type ---
// Facts row: [onWater, relElev, slope, roadDist, roadDrop, treeNear, treeWide, buildingCnt, hpDist,
// clutter50, aspect, aspectMag, roadDir, roadLos, fofDist, nestDist, nestDir]. Rows below omit the
// trailing fields: most default to 0, but roadLos defaults to 1 (clear), fofDist to 240 (open) and
// nestDist to 1e9 (no neighbour), so an omitted row carries no LOS, field-of-fire or interlock penalty.
// The clutter cases append clutter50, the RADIO cases append aspect/aspectMag, and the LOS, field-of-fire
// and interlock cases fill the row further, leaving roadDir at 12 unread by the score. Multipliers are
// asserted within a tolerance; 0 vetoes exact.

// Water is unplaceable for every type.
["hp_score: water vetoes any type",
    ([[true, 6, 0.2, 0, 4, 0, 0, 0, 1e9], "MG"] call fnc_hardpoint_score), 0] call fnc_assertEq;

// MG/AT on a bare hill, no road: uphill scores, and the missing road is not a veto.
["hp_score: MG on a roadless hill still places",
    ([[false, 6, 0.2, 1e9, 0, 0, 0, 0, 1e9], "MG"] call fnc_hardpoint_score), 1.5] call fnc_assertClose;
["hp_score: AT on a roadless hill still places (no road gate)",
    ([[false, 6, 0.2, 1e9, 0, 0, 0, 0, 1e9], "AT"] call fnc_hardpoint_score), 1.5] call fnc_assertClose;

// A road in the overwatch band (100-300 m; on-the-road is vetoed by the keep-clear) multiplies both,
// AT the harder. At 150 m the road factor is half strength, so MG gains 40% and AT 75%.
["hp_score: MG gains from overwatching a road",
    ([[false, 6, 0.2, 150, 4, 0, 0, 0, 1e9], "MG"] call fnc_hardpoint_score), 2.1] call fnc_assertClose;
["hp_score: AT gains more from the road it kills on",
    ([[false, 6, 0.2, 150, 4, 0, 0, 0, 1e9], "AT"] call fnc_hardpoint_score), 2.625] call fnc_assertClose;
// GMG lobs over cover, so the same overwatch lifts it less than the MG's 40%.
["hp_score: GMG gains less from a road it fires over",
    ([[false, 6, 0.2, 150, 4, 0, 0, 0, 1e9], "GMG"] call fnc_hardpoint_score), 1.875] call fnc_assertClose;
// The keep-clear: any non-roadblock within 100 m of a road is unplaceable, road bonus or not.
["hp_score: MG within the keep-clear is vetoed",
    ([[false, 6, 0.2, 50, 4, 0, 0, 0, 1e9], "MG"] call fnc_hardpoint_score), 0] call fnc_assertEq;
["hp_score: AA within the keep-clear is vetoed",
    ([[false, 0, 0.2, 80, 0, 0, 0, 0, 1e9], "AA"] call fnc_hardpoint_score), 0] call fnc_assertEq;

// Structures inside 50 m box a gun nest in: the same overwatch MG (2.1) loses arcs as clutter climbs,
// down to a 0.4 floor, but is never vetoed. The penalty rides on top of the overwatch multiplier.
["hp_score: MG among a few structures loses some of its arc",
    ([[false, 6, 0.2, 150, 4, 0, 0, 0, 1e9, 3], "MG"] call fnc_hardpoint_score), 1.47] call fnc_assertClose;
["hp_score: MG walled in by a compound floors at 0.4 of its score",
    ([[false, 6, 0.2, 150, 4, 0, 0, 0, 1e9, 6], "MG"] call fnc_hardpoint_score), 0.84] call fnc_assertClose;
["hp_score: GMG takes the same clutter penalty",
    ([[false, 6, 0.2, 150, 4, 0, 0, 0, 1e9, 6], "GMG"] call fnc_hardpoint_score), 0.75] call fnc_assertClose;
// A flat-ground type does not read clutter: the ARTY flat score is unchanged with structures around.
["hp_score: clutter does not touch a non-nest type",
    ([[false, 0, 0.2, 1e9, 0, 0, 0, 0, 1e9, 6], "ARTY"] call fnc_hardpoint_score), 2.0] call fnc_assertClose;

// Interlock rides on the nearest nest neighbour (nestDist facts[15]) and the two guns' facings agreeing
// (candidate fall line aspect facts[10] vs neighbour nestDir facts[16]). The overwatch MG (2.1) lifts as
// an aligned neighbour comes into the band and tapers with the gap; the sentinel 1e9 is a lone nest, no
// bonus. aspectMag (facts[11]) is set >2.5 so the candidate faces its fall line, not the radial.
["hp_score: MG interlocked with an aligned nest is preferred",
    ([[false, 6, 0.2, 150, 4, 0, 0, 0, 1e9, 0, 0, 5, 0, 1, 240, 120, 0], "MG"] call fnc_hardpoint_score), 3.36] call fnc_assertClose;
["hp_score: MG interlock tapers as the gap opens",
    ([[false, 6, 0.2, 150, 4, 0, 0, 0, 1e9, 0, 0, 5, 0, 1, 240, 225, 0], "MG"] call fnc_hardpoint_score), 2.73] call fnc_assertClose;
// The complaint fixed: a neighbour in range but facing the opposite way (nestDir 180 vs aspect 0) crosses
// no fire, so the interlock bonus zeroes and the MG scores as if alone (2.1).
["hp_score: MG interlock nulled when the neighbour faces opposite",
    ([[false, 6, 0.2, 150, 4, 0, 0, 0, 1e9, 0, 0, 5, 0, 1, 240, 120, 180], "MG"] call fnc_hardpoint_score), 2.1] call fnc_assertClose;
// Between aligned and opposed the bonus tapers with the facing delta: 135 deg is half.
["hp_score: MG interlock tapers as facings diverge",
    ([[false, 6, 0.2, 150, 4, 0, 0, 0, 1e9, 0, 0, 5, 0, 1, 240, 120, 135], "MG"] call fnc_hardpoint_score), 2.73] call fnc_assertClose;
// On flat ground the candidate faces the radial the score cannot see, so convergence is skipped and the
// bonus rides on proximity alone -- an opposed neighbour still counts (aspectMag 0 < 2.5).
["hp_score: MG on flat ground takes interlock on proximity alone",
    ([[false, 6, 0.2, 150, 4, 0, 0, 0, 1e9, 0, 0, 0, 0, 1, 240, 120, 180], "MG"] call fnc_hardpoint_score), 3.36] call fnc_assertClose;
// A flat-ground type does not read interlock: ARTY beside a nest neighbour keeps its flat score.
["hp_score: interlock does not touch a non-nest type",
    ([[false, 0, 0.2, 1e9, 0, 0, 0, 0, 1e9, 0, 0, 0, 0, 1, 240, 120], "ARTY"] call fnc_hardpoint_score), 2.0] call fnc_assertClose;

// Line of sight gates the road bonus: the overwatch MG (2.1) that cannot see the road it sits above
// (roadLos 0) falls back to the bare-hill score, as if there were no road. AT loses its larger bonus the
// same way. Row filled through fofDist (open) so only roadLos varies.
["hp_score: MG blind to its road scores as if roadless",
    ([[false, 6, 0.2, 150, 4, 0, 0, 0, 1e9, 0, 0, 0, 0, 0, 320], "MG"] call fnc_hardpoint_score), 1.5] call fnc_assertClose;
["hp_score: AT blind to its road loses its bonus too",
    ([[false, 6, 0.2, 150, 4, 0, 0, 0, 1e9, 0, 0, 0, 0, 0, 320], "AT"] call fnc_hardpoint_score), 1.5] call fnc_assertClose;

// Field of fire scales the nest: the overwatch MG (2.1) tapers toward a 0.6 floor as terrain masks its
// shot sooner. fofDist 0 is boxed in, 140 is mid, 240+ is fully open (the default the other rows carry).
["hp_score: MG boxed in by a short field of fire floors at 0.6",
    ([[false, 6, 0.2, 150, 4, 0, 0, 0, 1e9, 0, 0, 0, 0, 1, 0], "MG"] call fnc_hardpoint_score), 1.26] call fnc_assertClose;
["hp_score: MG field of fire tapers with the masking distance",
    ([[false, 6, 0.2, 150, 4, 0, 0, 0, 1e9, 0, 0, 0, 0, 1, 140], "MG"] call fnc_hardpoint_score), 1.68] call fnc_assertClose;

// A flat-ground type reads neither: AA with the road blind and the field boxed keeps its flat-clear score.
["hp_score: LOS and field of fire do not touch a non-nest type",
    ([[false, 0, 0.2, 1e9, 0, 0, 0, 0, 1e9, 0, 0, 0, 0, 0, 0], "AA"] call fnc_hardpoint_score), 1.7] call fnc_assertClose;

// Flat, low ground with no hill: the floor of the MG reward.
["hp_score: MG on flat ground scores its floor",
    ([[false, 0, 0.2, 1e9, 0, 0, 0, 0, 1e9], "MG"] call fnc_hardpoint_score), 0.5] call fnc_assertClose;

// AA prefers flat and clear; trees and slope tank it but never veto.
["hp_score: AA flat and clear",
    ([[false, 0, 0.2, 1e9, 0, 0, 0, 0, 1e9], "AA"] call fnc_hardpoint_score), 1.7] call fnc_assertClose;
["hp_score: AA under trees is a fraction of that",
    ([[false, 0, 0.2, 1e9, 0, 0, 6, 0, 1e9], "AA"] call fnc_hardpoint_score), 0.34] call fnc_assertClose;
["hp_score: AA on a slope drops but is not vetoed",
    ([[false, 0, 4, 1e9, 0, 0, 0, 0, 1e9], "AA"] call fnc_hardpoint_score), 0.3] call fnc_assertClose;

// Artillery requires level ground: rough is a veto.
["hp_score: artillery vetoes rough ground",
    ([[false, 0, 5, 1e9, 0, 0, 0, 0, 1e9], "ARTY"] call fnc_hardpoint_score), 0] call fnc_assertEq;
["hp_score: artillery on the flat",
    ([[false, 0, 0.2, 1e9, 0, 0, 0, 0, 1e9], "ARTY"] call fnc_hardpoint_score), 2.0] call fnc_assertClose;

// A roadblock needs a road, and is the one type exempt from the 100 m keep-clear -- on-the-road
// (roadDist 0) places, where every other type is vetoed inside 100 m.
["hp_score: roadblock vetoes no road",
    ([[false, 0, 0.2, 1e9, 0, 0, 0, 0, 1e9], "ROADBLOCK"] call fnc_hardpoint_score), 0] call fnc_assertEq;
["hp_score: roadblock on the road (exempt from the keep-clear)",
    ([[false, 0, 0.2, 0, 0, 0, 0, 0, 1e9], "ROADBLOCK"] call fnc_hardpoint_score), 1.5] call fnc_assertClose;

// OP wants height and close cover, but a thicket beyond blinds it.
["hp_score: OP high with close cover and an open view",
    ([[false, 6, 0.2, 1e9, 0, 4, 0, 0, 1e9], "OP"] call fnc_hardpoint_score), 3.0] call fnc_assertClose;
["hp_score: OP in a thicket loses half its view",
    ([[false, 6, 0.2, 1e9, 0, 4, 20, 0, 1e9], "OP"] call fnc_hardpoint_score), 1.5] call fnc_assertClose;
["hp_score: OP on low ground scores its floor",
    ([[false, 0, 0.2, 1e9, 0, 0, 0, 0, 1e9], "OP"] call fnc_hardpoint_score), 0.4] call fnc_assertClose;

// Mortar wants defilade: reward below the surroundings, penalise a crest.
["hp_score: mortar in defilade",
    ([[false, -6, 0.2, 1e9, 0, 0, 0, 0, 1e9], "MORTAR"] call fnc_hardpoint_score), 1.6] call fnc_assertClose;
["hp_score: mortar on a crest scores its floor",
    ([[false, 6, 0.2, 1e9, 0, 0, 0, 0, 1e9], "MORTAR"] call fnc_hardpoint_score), 0.4] call fnc_assertClose;

// Minefield needs open, clear ground; a tree, a building or an emplacement on it is each a veto.
["hp_score: minefield on open flat ground",
    ([[false, 0, 0.2, 1e9, 0, 0, 0, 0, 1e9], "MINEFIELD"] call fnc_hardpoint_score), 2.0] call fnc_assertClose;
["hp_score: minefield vetoes a tree on the patch",
    ([[false, 0, 0.2, 1e9, 0, 1, 1, 0, 1e9], "MINEFIELD"] call fnc_hardpoint_score), 0] call fnc_assertEq;
["hp_score: minefield vetoes a building nearby",
    ([[false, 0, 0.2, 1e9, 0, 0, 0, 1, 1e9], "MINEFIELD"] call fnc_hardpoint_score), 0] call fnc_assertEq;
["hp_score: minefield vetoes another emplacement nearby",
    ([[false, 0, 0.2, 1e9, 0, 0, 0, 0, 20], "MINEFIELD"] call fnc_hardpoint_score), 0] call fnc_assertEq;

// A radio mast wants a hilltop crest: high above the ring (relElev) with the ground falling away on
// every bearing (aspectMag near 0). A one-sided slope is docked, never vetoed; a flat plain has no
// fall line either, so the rise is what tells a crest from the flat.
["hp_score: radio mast on a symmetric crest",
    ([[false, 6, 4, 1e9, 0, 0, 0, 0, 1e9, 0, 0, 0], "RADIO"] call fnc_hardpoint_score), 2.0] call fnc_assertClose;
["hp_score: radio mast on a one-sided slope is docked",
    ([[false, 6, 4, 1e9, 0, 0, 0, 0, 1e9, 0, 90, 12], "RADIO"] call fnc_hardpoint_score), 0.8] call fnc_assertClose;
["hp_score: radio mast on a half-formed crest",
    ([[false, 6, 4, 1e9, 0, 0, 0, 0, 1e9, 0, 45, 7.25], "RADIO"] call fnc_hardpoint_score), 1.4] call fnc_assertClose;
["hp_score: radio mast on a flat plain scores its floor",
    ([[false, 0, 0.2, 1e9, 0, 0, 0, 0, 1e9, 0, 0, 0], "RADIO"] call fnc_hardpoint_score), 0.3] call fnc_assertClose;

// An unmapped type sites anywhere until given a preference -- but still keeps clear of roads (only the
// roadblock is exempt), so this reads a site with no road in scan range (roadDist sentinel).
["hp_score: an unknown type is neutral",
    ([[false, 0, 0, 1e9, 0, 0, 0, 0, 1e9], "WATCHTOWER"] call fnc_hardpoint_score), 1] call fnc_assertEq;

// --- fnc_hardpoint_facing: [type, aspectDir, aspectMag, radialDir, roadDir] -> heading ---
// A pronounced fall line (aspectMag >= 2.5) turns an overwatch nest down the slope; a faint one, or a
// type whose heading is cosmetic, keeps the radial heading the loop passes in. A roadblock stays square
// across its road, taking whichever of the road's two headings sits nearer radialDir.
["hp_facing: an MG on a real slope faces the fall line",
    (["MG", 135, 5, 20] call fnc_hardpoint_facing), 135] call fnc_assertEq;
["hp_facing: AT and GMG face it too",
    (["AT", 90, 3, 200] call fnc_hardpoint_facing), 90] call fnc_assertEq;
["hp_facing: a GMG faces the fall line",
    (["GMG", 270, 4, 10] call fnc_hardpoint_facing), 270] call fnc_assertEq;
["hp_facing: on near-flat ground the nest keeps the radial heading",
    (["MG", 135, 1, 20] call fnc_hardpoint_facing), 20] call fnc_assertEq;
// radialDir 20 is within 90 deg of the road's 75, so the block keeps the road heading as-is.
["hp_facing: a roadblock keeps the road heading nearer the radial",
    (["ROADBLOCK", 135, 5, 20, 75] call fnc_hardpoint_facing), 75] call fnc_assertEq;
// radialDir 200 sits on the far side of the road (delta 170 > 90), so the block flips to roadDir+180 to
// face the approach the radial points down rather than the ground behind it.
["hp_facing: a roadblock flips to the road heading facing the approach",
    (["ROADBLOCK", 0, 0, 200, 30] call fnc_hardpoint_facing), 210] call fnc_assertEq;

// --- fnc_hardpoint_zone_cap: a zone ring's cap is its radius step plus one per tier above I ---
// HP_CAP_STEP is a #define in the source; the extractor lifts the function body, not the define, so it
// is restated here as the global the extracted body reads in the VM (value mirrors the source constant).
HP_CAP_STEP = 250;
missionNamespace setVariable ["DUWS_zoneTier_hpcapk", 1];
["hardpoint_zone_cap: tier I adds nothing to the radius cap",
    (["hpcapk", 250] call fnc_hardpoint_zone_cap), 1] call fnc_assertEq;
missionNamespace setVariable ["DUWS_zoneTier_hpcapk", 4];
["hardpoint_zone_cap: tier IV adds three to the radius cap",
    (["hpcapk", 250] call fnc_hardpoint_zone_cap), 4] call fnc_assertEq;
["hardpoint_zone_cap: a small radius floors the cap at one, tier still stacks",
    (["hpcapk", 50] call fnc_hardpoint_zone_cap), 4] call fnc_assertEq;
missionNamespace setVariable ["DUWS_zoneTier_hpcapk", 2];
["hardpoint_zone_cap: radius steps every HP_CAP_STEP metres",
    (["hpcapk", 800] call fnc_hardpoint_zone_cap), 4] call fnc_assertEq;

// --- empty garrison is a supported shape (zones and hardpoints both raise from a list that may be
// empty). The composition pipeline must carry [] end to end without special-casing, so a site with
// no loose defenders raises none and does not fault; its emplacements are crewed separately. ---
["scaleComposition: an empty composition scales to empty",
    ([[], 3] call DUWS_fnc_scaleComposition), []] call fnc_assertEq;
missionNamespace setVariable ["DUWS_garrisonLost_emptyk", []];
["garrisonDerive: an empty composition derives an empty garrison and pool",
    (["emptyk", [], 3] call DUWS_fnc_garrisonDerive), [[], []]] call fnc_assertEq;

// --- fnc_in_base_keep: the depot map-retrieve ring bound, shared by the client pick and the server
// guard. Runs first while PosOfBLUHQ is still unset, to exercise the unknown-HQ branch. ---
["in_base_keep: an unknown HQ position is never inside",
    ([[0, 0, 0]] call fnc_in_base_keep), false] call fnc_assertEq;

PosOfBLUHQ = [1000, 1000, 0];
// DUWS_base_keep_radius still unset here -> the 250 m fallback bounds a JIP client that missed the broadcast.
["in_base_keep: fallback radius accepts a point on the 250 m ring",
    ([[1250, 1000, 0]] call fnc_in_base_keep), true] call fnc_assertEq;
["in_base_keep: fallback radius refuses past 250 m",
    ([[1251, 1000, 0]] call fnc_in_base_keep), false] call fnc_assertEq;

DUWS_base_keep_radius = 500;
["in_base_keep: reads the broadcast radius, not the fallback",
    ([[1300, 1000, 0]] call fnc_in_base_keep), true] call fnc_assertEq;
["in_base_keep: the bound is 2D, so height is ignored",
    ([[1100, 1000, 40]] call fnc_in_base_keep), true] call fnc_assertEq;
["in_base_keep: a point outside the ring is refused",
    ([[1600, 1000, 0]] call fnc_in_base_keep), false] call fnc_assertEq;

PosOfBLUHQ = [];
["in_base_keep: an empty HQ position is never inside",
    ([[1000, 1000, 0]] call fnc_in_base_keep), false] call fnc_assertEq;

// --- fnc_offer_weight: offer-placement weight [_pos, _hard, _mode, _world] -> number ---
// _world = [friendlyAnchors, enemyPts, opforCenters, zoneFoot, hpFoot]: anchors and centres are [x,y],
// enemyPts/zoneFoot/hpFoot are [[x,y], radius]. Expected numbers follow the baked constants -- densRadius
// and depthScale 1500, gauntCorr 400, peakEnemyness 0.5, frontWidth 0.3, zoneRepel 1200, hpRepel 300 --
// so a retune that moves a constant is meant to move the matching value here. Scores rank relatively
// (selectRandomWeighted normalises), so only ratios between these matter, not their scale.

// Hard gate: enemy density both leads and vetoes -- nothing within densRadius scores 0.
["offer_weight: hard with no enemy is vetoed",
    ([[0,0], true, "urban", [[],[],[],[],[]]] call fnc_offer_weight), 0] call fnc_assertEq;
["offer_weight: hard with the only enemy beyond densRadius is vetoed",
    ([[0,0], true, "urban", [[], [[[1600,0],0]], [],[],[]]] call fnc_offer_weight), 0] call fnc_assertEq;

// Hard score with no friendly anchors: gauntlet stays at its 0.2 floor and depth at 1500/(1500+1500)=0.5,
// so the score is dens^2 * (0.15 + 0.5) * 0.2. Enemy on the spot -> dens 1 -> 0.13.
["offer_weight: hard, enemy on the spot, no anchors",
    ([[0,0], true, "urban", [[], [[[0,0],0]], [],[],[]]] call fnc_offer_weight), 0.13] call fnc_assertClose;
// Enemy at 750 m -> dens 0.5 -> dens^2 0.25 -> a quarter of the score (density leads squared).
["offer_weight: hard score falls with enemy distance, squared",
    ([[0,0], true, "urban", [[], [[[750,0],0]], [],[],[]]] call fnc_offer_weight), 0.0325] call fnc_assertClose;
// Two enemies sum density: 1 + 0.5 = 1.5 -> 1.5^2 * 0.65 * 0.2.
["offer_weight: hard density sums across enemies",
    ([[0,0], true, "urban", [[], [[[0,0],0], [[750,0],0]], [],[],[]]] call fnc_offer_weight), 0.2925] call fnc_assertClose;

// Gauntlet: an enemy on the approach line from the nearest anchor adds (1 - perp/400). Anchor at -1000,
// enemy at -300 on that line: dens 0.8 (300 m in), depth 1000/2500 = 0.4, gaunt 0.2 + 1 = 1.2, so
// 0.8^2 * (0.15 + 0.4) * 1.2 = 0.4224.
["offer_weight: hard rewards an enemy in the approach corridor",
    ([[0,0], true, "urban", [[[-1000,0]], [[[-300,0],0]], [],[],[]]] call fnc_offer_weight), 0.4224] call fnc_assertClose;

// _mode is read only on the easy branch, so a hard call ignores it: same value as the urban case above.
["offer_weight: hard ignores _mode",
    ([[0,0], true, "zone", [[], [[[0,0],0]], [],[],[]]] call fnc_offer_weight), 0.13] call fnc_assertClose;

// Easy zone: 1 / max(1, nearest-friendly distance) -- the OPFOR zone nearest friendly ground scores highest.
["offer_weight: easy zone with no anchors is 1",
    ([[0,0], false, "zone", [[],[],[],[],[]]] call fnc_offer_weight), 1] call fnc_assertClose;
["offer_weight: easy zone weight is 1 over nearest-friendly distance",
    ([[0,0], false, "zone", [[[100,0]],[],[],[],[]]] call fnc_offer_weight), 0.01] call fnc_assertClose;
["offer_weight: easy zone takes the nearest of several anchors",
    ([[0,0], false, "zone", [[[100,0],[50,0]],[],[],[],[]]] call fnc_offer_weight), 0.02] call fnc_assertClose;
["offer_weight: easy zone floors the distance at 1 m",
    ([[0,0], false, "zone", [[[0.5,0]],[],[],[],[]]] call fnc_offer_weight), 1] call fnc_assertClose;

// Easy urban: a bell in enemyness = dFri/(dFri+dOpf), peaked at 0.5 (the seam), times footprint repulsion.
// Friendly at -100 and OPFOR at +100 put the spot on the seam -> front 1; empty footprints -> repel 1.
["offer_weight: easy urban peaks on the seam",
    ([[0,0], false, "urban", [[[-100,0]],[],[[100,0]],[],[]]] call fnc_offer_weight), 1] call fnc_assertClose;
// Off the seam (dFri 100, dOpf 300 -> enemyness 0.25): 1 / (1 + ((0.25 - 0.5) / 0.3)^2).
["offer_weight: easy urban falls off the seam",
    ([[0,0], false, "urban", [[[-100,0]],[],[[300,0]],[],[]]] call fnc_offer_weight), 0.59016393] call fnc_assertClose;
// Repulsion off a footprint is d/(d+scale): a zone centre 1200 m off (scale 1200) halves the weight.
["offer_weight: easy urban is repelled by a zone footprint",
    ([[0,0], false, "urban", [[[-100,0]],[],[[100,0]], [[[0,1200],0]], []]] call fnc_offer_weight), 0.5] call fnc_assertClose;
// A hardpoint 300 m off (scale 300) halves it the same way.
["offer_weight: easy urban is repelled by a hardpoint footprint",
    ([[0,0], false, "urban", [[[-100,0]],[],[[100,0]], [], [[[0,300],0]]]] call fnc_offer_weight), 0.5] call fnc_assertClose;
// Degenerate empty world: no anchors and no centres collapse enemyness to 0.5, so a neutral 1.
["offer_weight: easy urban on an empty world is neutral",
    ([[0,0], false, "urban", [[],[],[],[],[]]] call fnc_offer_weight), 1] call fnc_assertClose;

// --- fnc_campaign_now / fnc_time_expired: a rest's skiptime skew advances the mission clock ---
// campaign_now = time + DUWS_timeSkew; the skew is what a rest bumps. Differencing two reads across a
// skew change isolates the skew from time's own micro-advance in the VM.
DUWS_timeSkew = 0; private _n0 = call fnc_campaign_now;
DUWS_timeSkew = 1000; private _n1 = call fnc_campaign_now;
["campaign_now: skew adds to the clock", floor (_n1 - _n0), 1000] call fnc_assertEq;

// A deadline built now is live; a rest that skips past it trips fnc_time_expired, a shorter one does not.
DUWS_timeSkew = 0;
private _dl = (call fnc_campaign_now) + 100;
["time_expired: fresh deadline is live", ([_dl] call fnc_time_expired), false] call fnc_assertEq;
DUWS_timeSkew = 50;
["time_expired: a shorter rest leaves it live", ([_dl] call fnc_time_expired), false] call fnc_assertEq;
DUWS_timeSkew = 150;
["time_expired: a rest past the deadline expires it", ([_dl] call fnc_time_expired), true] call fnc_assertEq;

// --- fnc_stealth_coef: the movement-scored camouflageCoef for a covert approach ---
["stealth_coef: prone and still is the quietest approach, and the floor exactly",
    (["PRONE", 0, 999] call fnc_stealth_coef), 0.1] call fnc_assertClose;
["stealth_coef: crouched at its walk",
    (["CROUCH", 8.6, 999] call fnc_stealth_coef), 0.2625] call fnc_assertClose;
["stealth_coef: standing at a walk",
    (["STAND", 11, 999] call fnc_stealth_coef), 0.35] call fnc_assertClose;
["stealth_coef: standing still",
    (["STAND", 0, 999] call fnc_stealth_coef), 0.2] call fnc_assertClose;
["stealth_coef: a standing slow-walk",
    (["STAND", 5, 999] call fnc_stealth_coef), 0.275] call fnc_assertClose;
["stealth_coef: a standing sprint is the worst case without a shot",
    (["STAND", 20, 999] call fnc_stealth_coef), 0.5] call fnc_assertClose;
["stealth_coef: combat pace sits between a walk and a sprint",
    (["STAND", 12.9, 999] call fnc_stealth_coef), 0.425] call fnc_assertClose;

["stealth_coef: 4.5 km/h is a sprint while prone",
    (["PRONE", 4.5, 999] call fnc_stealth_coef), 0.25] call fnc_assertClose;
["stealth_coef: the same 4.5 km/h is only a slow-walk standing",
    (["STAND", 4.5, 999] call fnc_stealth_coef), 0.275] call fnc_assertClose;
["stealth_coef: a prone crawl scores slow-walk, never walk",
    (["PRONE", 2.2, 999] call fnc_stealth_coef), 0.1375] call fnc_assertClose;

["stealth_coef: speed is read as a magnitude",
    (["STAND", -12, 999] call fnc_stealth_coef), 0.425] call fnc_assertClose;

["stealth_coef: the shot itself carries the full spike",
    (["PRONE", 0, 0] call fnc_stealth_coef), 0.14] call fnc_assertClose;
["stealth_coef: half the window is half the spike",
    (["PRONE", 0, 2.5] call fnc_stealth_coef), 0.12] call fnc_assertClose;
["stealth_coef: the spike is spent by the end of the window",
    (["PRONE", 0, 5] call fnc_stealth_coef), 0.1] call fnc_assertClose;

["stealth_coef: a standing sprinter who just fired is the ceiling, still under vanilla",
    (["STAND", 20, 0] call fnc_stealth_coef), 0.7] call fnc_assertClose;

// stance answers UNDEFINED for a mounted unit, which the layer skips.
["stealth_coef: an unrecognised stance scores as standing",
    (["UNDEFINED", 0, 999] call fnc_stealth_coef), 0.2] call fnc_assertClose;

// --- DUWS_fnc_opcom_creepGrid: a creep's rows and a gun's rounds per row ---
OPCOM_ARTY_MIN_SPREAD = 50;
OPCOM_ARTY_CREEP_STEP = 50;
["creep_grid: one row per step of length, one round per step of each gun's lane",
    [["creep", 300, 1000, 0], 3] call DUWS_fnc_opcom_creepGrid, [20, 2]] call fnc_assertEq;
["creep_grid: a lane narrower than a step still takes one round a row",
    [["creep", 100, 300, 0], 3] call DUWS_fnc_opcom_creepGrid, [6, 1]] call fnc_assertEq;
["creep_grid: a creep under the floor still lays one row of one round",
    [["creep", 10, 0, 0], 2] call DUWS_fnc_opcom_creepGrid, [1, 1]] call fnc_assertEq;

// --- DUWS_fnc_opcom_fireAim: where each round of a shaped fire mission lands ---
// Every aim is random, so each case samples 200 rounds and asserts the bound holds for all of them.
fnc_test_aimAll = {
    params ["_args", "_pred"];
    private _ok = true;
    for "_i" from 1 to 200 do {
        if !((_args call DUWS_fnc_opcom_fireAim) call _pred) exitWith { _ok = false };
    };
    _ok
};
fnc_test_aimDist = { sqrt (((_this select 0) - 1000) ^ 2 + ((_this select 1) - 1000) ^ 2) };
fnc_test_aimIn = {
    params ["_p", "_x0", "_x1", "_y0", "_y1"];
    (_p select 0) >= _x0 - 1e-6 && {(_p select 0) <= _x1 + 1e-6} && {(_p select 1) >= _y0 - 1e-6} && {(_p select 1) <= _y1 + 1e-6}
};

["fire_aim: a saturate lands inside its radius",
    [[[1000, 1000, 0], ["saturate", 120], 0, 1, 0], { (_this call fnc_test_aimDist) <= 120 }] call fnc_test_aimAll, true] call fnc_assertEq;
["fire_aim: a saturate under the floor still spreads to it, never past it",
    [[[1000, 1000, 0], ["saturate", 10], 0, 1, 0], { (_this call fnc_test_aimDist) <= 50 }] call fnc_test_aimAll, true] call fnc_assertEq;
["fire_aim: a saturate under the floor does not stay inside the radius it was given",
    [[[1000, 1000, 0], ["saturate", 10], 0, 1, 0], { (_this call fnc_test_aimDist) <= 10 }] call fnc_test_aimAll, false] call fnc_assertEq;
["fire_aim: a saturate's disc moves with its round's drift",
    [[[1000, 1000, 0], ["saturate", 50], 0, 1, 1, [[0, 0], [200, -100]]],
        { sqrt (((_this select 0) - 1200) ^ 2 + ((_this select 1) - 900) ^ 2) <= 50 }] call fnc_test_aimAll, true] call fnc_assertEq;
// Bearing 0 only, as sqf-vm's sin and cos take radians; creeping north, the first gun's lane (the left half) lies west.
["fire_aim: a creep's first gun holds the left lane and each row its own band",
    [[[1000, 1000, 0], ["creep", 100, 300, 0], 0, 2, 1], { [_this, 950, 1000, 1050, 1100] call fnc_test_aimIn }] call fnc_test_aimAll, true] call fnc_assertEq;
["fire_aim: a creep's second gun holds the right lane",
    [[[1000, 1000, 0], ["creep", 100, 300, 0], 1, 2, 1], { [_this, 1000, 1050, 1050, 1100] call fnc_test_aimIn }] call fnc_test_aimAll, true] call fnc_assertEq;
["fire_aim: a creep's wide lane lays its row across before it steps forward",
    [[[1000, 1000, 0], ["creep", 300, 300, 0], 0, 3, 3], { [_this, 900, 950, 1050, 1100] call fnc_test_aimIn }] call fnc_test_aimAll, true] call fnc_assertEq;
["fire_aim: a creep's row takes only the lateral part of its drift",
    [[[1000, 1000, 0], ["creep", 100, 300, 0], 0, 1, 0, [[30, 500]]], { [_this, 980, 1080, 1000, 1050] call fnc_test_aimIn }] call fnc_test_aimAll, true] call fnc_assertEq;
["fire_aim: a creep given no length still crawls the floor's depth",
    [[[1000, 1000, 0], ["creep", 100, 0, 0], 0, 1, 0], { ((_this select 1) - 1000) <= 1 }] call fnc_test_aimAll, false] call fnc_assertEq;

// --- DUWS_fnc_opcom_deposit: the grid's linear falloff, and its exact take-back ---
// The grid stage removes a cached source by depositing its weight negated, so a removal must leave every cell
// where a build without that source would put it.
OPCOM_GRID_CELL = 500;
DUWS_opcom_grid_w = 10;
DUWS_opcom_box = [0, 0, 9, 9];
fnc_test_zeroGrid = { private _z = []; for "_i" from 1 to 100 do { _z pushBack 0 }; _z };
fnc_test_maxGap = {
    params ["_a", "_b"];
    private _g = 0;
    { _g = _g max abs (_x - (_b select _forEachIndex)) } forEach _a;
    _g
};

private _g1 = call fnc_test_zeroGrid;
[_g1, [250, 250], 4, 1000] call DUWS_fnc_opcom_deposit;
["deposit: the source's own cell takes the full weight", _g1 select 0, 4] call fnc_assertClose;
["deposit: a cell half the reach away takes half", _g1 select 1, 2] call fnc_assertClose;
["deposit: a cell past the reach takes nothing", _g1 select 3, 0] call fnc_assertClose;

[_g1, [250, 250], -4, 1000] call DUWS_fnc_opcom_deposit;
["deposit: a negated deposit takes the first back", [_g1, call fnc_test_zeroGrid] call fnc_test_maxGap, 0] call fnc_assertClose;

private _g2 = call fnc_test_zeroGrid;
[_g2, [250, 250], 0, 1000] call DUWS_fnc_opcom_deposit;
["deposit: a zero weight writes nothing", [_g2, call fnc_test_zeroGrid] call fnc_test_maxGap, 0] call fnc_assertClose;

DUWS_opcom_box = [2, 2, 7, 7];
private _g3 = call fnc_test_zeroGrid;
[_g3, [250, 250], 4, 2000] call DUWS_fnc_opcom_deposit;
["deposit: a cell outside the box is never written", _g3 select 0, 0] call fnc_assertClose;
["deposit: a box cell in reach of an outside source still takes its share", _g3 select 22, 4 * (1 - sqrt (2 * 1000 ^ 2) / 2000)] call fnc_assertClose;
DUWS_opcom_box = [0, 0, 9, 9];

private _mixed = call fnc_test_zeroGrid;
[_mixed, [1300, 2100], 7.5, 1500] call DUWS_fnc_opcom_deposit;
[_mixed, [2600, 900], 3.25, 1250] call DUWS_fnc_opcom_deposit;
[_mixed, [4100, 4400], 11, 2000] call DUWS_fnc_opcom_deposit;
[_mixed, [2600, 900], -3.25, 1250] call DUWS_fnc_opcom_deposit;
[_mixed, [900, 3800], 2, 1000] call DUWS_fnc_opcom_deposit;
[_mixed, [4100, 4400], -11, 2000] call DUWS_fnc_opcom_deposit;
private _survivors = call fnc_test_zeroGrid;
[_survivors, [1300, 2100], 7.5, 1500] call DUWS_fnc_opcom_deposit;
[_survivors, [900, 3800], 2, 1000] call DUWS_fnc_opcom_deposit;
["deposit: adds and removes in any order match a build of the survivors", [_mixed, _survivors] call fnc_test_maxGap, 0] call fnc_assertClose;
