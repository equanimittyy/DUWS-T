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

// --- the shared attrition store: what a mauled garrison redeploys at ---
// Exercised through the zone wrappers, so the delegation is covered along with the arithmetic. A
// town reads the same functions under a town_<n> key.
// Tenths rounded up, floored at 0.3, capped at 1. The floor is the mechanic: against the 0.2 break
// line, a garrison at three tenths is still a tenth of the zone's original strength from beaten.
["garrisonStrength: rounds up to the next tenth",
    (["k1", 0.55] call fnc_zone_strength_set), 0.6] call fnc_assertEq;
["garrisonStrength: an exact tenth does not step up",
    (["k1", 0.7] call fnc_zone_strength_set), 0.7] call fnc_assertEq;
["garrisonStrength: a wiped garrison redeploys at the floor",
    (["k1", 0] call fnc_zone_strength_set), 0.3] call fnc_assertEq;
["garrisonStrength: just under the floor is the floor, not a rounding of it",
    (["k1", 0.24] call fnc_zone_strength_set), 0.3] call fnc_assertEq;
["garrisonStrength: an untouched garrison stays at full",
    (["k1", 1] call fnc_zone_strength_set), 1] call fnc_assertEq;
["garrisonStrength: reads back what it stored",
    (["k1"] call fnc_zone_strength), 1] call fnc_assertEq;
["garrisonStrength: a zone that has never been fought over is full strength",
    (["never_touched"] call fnc_zone_strength), 1] call fnc_assertEq;

// --- DUWS_fnc_garrisonStrengthRecord: survivors against the force it was given ---
["rec1", 1] call fnc_zone_strength_set;
["strengthRecord: records what is left, quantised up",
    (["rec1", 5, 10] call DUWS_fnc_garrisonStrengthRecord), 0.5] call fnc_assertEq;
// Falls only. An untouched garrison measured raw would climb a step every visit, because every
// consumer rounds its own share up and keeps at least one of whatever it places.
["strengthRecord: never raises what is already lower",
    (["rec1", 10, 10] call DUWS_fnc_garrisonStrengthRecord), 0.5] call fnc_assertEq;
["strengthRecord: a wiped garrison lands on the floor, not on zero",
    (["rec1", 0, 10] call DUWS_fnc_garrisonStrengthRecord), 0.3] call fnc_assertEq;
// No baseline means no cycle ever finished placing, so there is nothing to measure against and what
// is standing describes a garrison that was still arriving.
["rec2", 1] call fnc_zone_strength_set;
["strengthRecord: a zero baseline records nothing",
    (["rec2", 3, 0] call DUWS_fnc_garrisonStrengthRecord), 1] call fnc_assertEq;

// --- fnc_zone_thin: scaling a spawn list by that strength ---
private _band = ["sniper", "patrol", "patrol", "team", "wpteam", "armored", "air", "car", "car", "patrol"];
["zone_thin: keeps the ceiling of the fraction",
    (count ([_band, 0.55] call fnc_zone_thin)), 6] call fnc_assertEq;
["zone_thin: full strength keeps the whole band",
    (count ([_band, 1] call fnc_zone_thin)), 10] call fnc_assertEq;
// A zone that placed nothing publishes no peak, and fnc_zone_capture_ready refuses capture on a
// zero peak -- so a thinned band must never come back empty.
["zone_thin: never empties a list",
    (count ([["patrol", "team"], 0.1] call fnc_zone_thin)), 1] call fnc_assertEq;
["zone_thin: leaves the caller's list alone",
    (count _band), 10] call fnc_assertEq;

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

// --- the access filter: three reasons to drop a token, never to substitute one ---
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
WARCOM_opfor_ap = 40;
["tokenClass: below its Army Power rung a token is not yet unlocked",
    (["tank"] call DUWS_fnc_tokenClass), ""] call fnc_assertEq;
WARCOM_opfor_ap = 100;
["tokenClass: reaching the rung unlocks it",
    (["tank"] call DUWS_fnc_tokenClass), "cls_tank"] call fnc_assertEq;
WARCOM_opfor_ap = 200;

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

// --- attrition is a fraction of men, so a token carries its own share of it ---
// An entry is not a unit: "patrol" is two men and "car" is a vehicle, so dropping entries at random
// let two zones reported at the same strength differ by twenty men.
["tokenStrength: a team thins from the inside and keeps its leader",
    (["patrol", 0.4] call DUWS_fnc_tokenStrength), 0.4] call fnc_assertEq;
["tokenStrength: a vehicle above half strength stands whole",
    (["apc", 0.5] call DUWS_fnc_tokenStrength), 1] call fnc_assertEq;
["tokenStrength: and below it is dropped, since there is no partial vehicle",
    (["apc", 0.49] call DUWS_fnc_tokenStrength), 0] call fnc_assertEq;
["tokenStrength: full strength leaves everything whole",
    (["apc", 1] call DUWS_fnc_tokenStrength), 1] call fnc_assertEq;

["thinComposition: a worn zone keeps its men and loses its vehicles",
    ([["patrol", "team", "car", "apc"], 0.4] call DUWS_fnc_thinComposition),
    ["patrol", "team"]] call fnc_assertEq;
["thinComposition: full strength changes nothing",
    ([["patrol", "car"], 1] call DUWS_fnc_thinComposition), ["patrol", "car"]] call fnc_assertEq;
// Deterministic, unlike the entry drop it replaces: a zone the player wore down has to come back as
// the zone they wore down, not as a fresh roll of which entries survived.
["thinComposition: the same composition and strength give the same answer twice",
    ([["patrol", "team", "car", "apc"], 0.6] call DUWS_fnc_thinComposition),
    ([["patrol", "team", "car", "apc"], 0.6] call DUWS_fnc_thinComposition)] call fnc_assertEq;

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
// The orders every team and every vehicle walked when a posture was a column on the roster row, so
// a side mission that names only a team keeps getting what it always got.
["tokenPosture: a bare token falls back to a close patrol",
    (["team"] call DUWS_fnc_tokenPosture), "closepatrol"] call fnc_assertEq;
// The lookups strip the posture themselves; a row matched on the whole string would find nothing.
["teamRow: a posture-carrying token still finds its roster row",
    ((["garrison:team"] call DUWS_fnc_teamRow) select 0), "team"] call fnc_assertEq;
["vehicleRow: and so does a vehicle's",
    ((["closepatrol:apc"] call DUWS_fnc_vehicleRow) select 0), "apc"] call fnc_assertEq;
// fnc_spawn_vehicle is handed this as a classname, so the posture has to be gone by here.
["tokenClass: a posture-carrying classname passes through without its posture",
    (["garrison:O_MBT_02_cannon_F"] call DUWS_fnc_tokenClass), "O_MBT_02_cannon_F"] call fnc_assertEq;
["thinComposition: attrition reads a posture-carrying token by what it is made of",
    ([["garrison:team", "closepatrol:apc"], 0.4] call DUWS_fnc_thinComposition),
    ["garrison:team"]] call fnc_assertEq;

// fnc_zone_thin drops at random indices, so a thinned roster is asserted by size and by who leads
// rather than by contents. Nine men halved is five, plus the leader.
private _thinned = ["big", "opfor", 0.5] call DUWS_fnc_teamRoster;
["teamRoster: attrition thins the men",
    (count _thinned), 6] call fnc_assertEq;
// The reason thinning happens before the leader is prepended: a section ground down still has one.
["teamRoster: attrition never takes the leader",
    (_thinned select 0), "cls_TL"] call fnc_assertEq;
["teamRoster: full strength thins nothing",
    (count (["big", "opfor", 1] call DUWS_fnc_teamRoster)), 10] call fnc_assertEq;

// The join that makes one table serve both armies: the row names a role, the side names the army.
// Same row, same order, other side's men.
blufor_A_X = "cls_blu_A";
blufor_B_X = "cls_blu_B";
["teamRoster: the side is prepended, so one row raises either army",
    (["patrol", "blufor"] call DUWS_fnc_teamRoster), ["cls_blu_A", "cls_blu_B"]] call fnc_assertEq;

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

// The zone band reads the setting itself, so a tier row states one zone and the campaign says how
// many of it. Restored afterwards: every later case here assumes an unscaled composition.
enemyunitMultiplier = 2;
["zoneSpawnList: the campaign's multiplier reaches the tier row",
    ([1] call DUWS_fnc_zoneSpawnList), ["patrol", "patrol"]] call fnc_assertEq;
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

// --- fnc_faction_schema: the required column ---
// A row short of four columns reads `nil` as its required flag, which fnc_custom_faction_parse's
// filter would treat as false -- silently dropping a core key out of paste validation.
private _rows = (["blufor"] call fnc_faction_schema) + (["opfor"] call fnc_faction_schema);
["faction_schema: every row carries all four columns",
    (_rows findIf { count _x != 4 }), -1] call fnc_assertEq;
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
     "blufor_TURRET_MORTAR", "opfor_TURRET_AA", "opfor_TURRET_AT", "opfor_TURRET_GMG",
     "opfor_TURRET_MORTAR", "opfor_ARTY_X"]] call fnc_assertEq;

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
// Facts row: [onWater, relElev, slope, roadDist, roadDrop, treeNear, treeWide, buildingCnt, hpDist].
// Multipliers are asserted within a tolerance; the 0 vetoes are exact.

// Water is unplaceable for every type.
["hp_score: water vetoes any type",
    ([[true, 6, 0.2, 0, 4, 0, 0, 0, 1e9], "MG"] call fnc_hardpoint_score), 0] call fnc_assertEq;

// MG/AT on a bare hill, no road: uphill scores, and the missing road is not a veto.
["hp_score: MG on a roadless hill still places",
    ([[false, 6, 0.2, 1e9, 0, 0, 0, 0, 1e9], "MG"] call fnc_hardpoint_score), 1.5] call fnc_assertClose;
["hp_score: AT on a roadless hill still places (no road gate)",
    ([[false, 6, 0.2, 1e9, 0, 0, 0, 0, 1e9], "AT"] call fnc_hardpoint_score), 1.5] call fnc_assertClose;

// A road below and near multiplies both, AT the harder -- roughly triples where MG gains ~80%.
["hp_score: MG gains from overwatching a road",
    ([[false, 6, 0.2, 0, 4, 0, 0, 0, 1e9], "MG"] call fnc_hardpoint_score), 2.7] call fnc_assertClose;
["hp_score: AT gains more from the road it kills on",
    ([[false, 6, 0.2, 0, 4, 0, 0, 0, 1e9], "AT"] call fnc_hardpoint_score), 3.75] call fnc_assertClose;

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

// A roadblock needs a road.
["hp_score: roadblock vetoes no road",
    ([[false, 0, 0.2, 1e9, 0, 0, 0, 0, 1e9], "ROADBLOCK"] call fnc_hardpoint_score), 0] call fnc_assertEq;
["hp_score: roadblock on the road",
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

// An unmapped type sites anywhere until given a preference.
["hp_score: an unknown type is neutral",
    ([[false, 0, 0, 0, 0, 0, 0, 0, 1e9], "WATCHTOWER"] call fnc_hardpoint_score), 1] call fnc_assertEq;

// --- fnc_hardpoint_minefield_lattice: the deterministic mine grid ---
["hp_lattice: a 2x1 field is centred on the origin",
    ([2, 1, 4] call fnc_hardpoint_minefield_lattice), [[-2, 0], [2, 0]]] call fnc_assertEq;
["hp_lattice: a 3x2 field staggers the odd row by half the spacing",
    ([3, 2, 4] call fnc_hardpoint_minefield_lattice),
    [[-4, -2], [0, -2], [4, -2], [-2, 2], [2, 2], [6, 2]]] call fnc_assertEq;
["hp_lattice: spacing defaults to 4",
    ([2, 1] call fnc_hardpoint_minefield_lattice), [[-2, 0], [2, 0]]] call fnc_assertEq;

// --- empty garrison is a supported shape (zones and hardpoints both raise from a list that may be
// empty). The composition pipeline must carry [] end to end without special-casing, so a site with
// no loose defenders raises none and does not fault; its emplacements are crewed separately. ---
["scaleComposition: an empty composition scales to empty",
    ([[], 3] call DUWS_fnc_scaleComposition), []] call fnc_assertEq;
["thinComposition: an empty composition thins to empty",
    ([[], 1] call DUWS_fnc_thinComposition), []] call fnc_assertEq;
