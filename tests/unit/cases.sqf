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

// --- fnc_opforRoles: the spawnable role list a faction table actually resolved ---
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

["opforRoles: a table defining every role keeps all of them, in order",
    ([[opfor_SOLDIER_X, opfor_AA_SOLDIER_X, opfor_AR_SOLDIER_X]] call fnc_opforRoles),
    ["O_Soldier_F_fake", "O_Soldier_AA_fake", "O_Soldier_AR_fake"]] call fnc_assertEq;

// The array literal is built at the call site, so a role the faction table never defined arrives
// as a nil element. This is the whole reason the list is walked instead of filtered.
["opforRoles: a role the table never defined is dropped, not spawned as nil",
    ([[opfor_SOLDIER_X, opfor_MISSING_ROLE_X, opfor_AR_SOLDIER_X]] call fnc_opforRoles),
    ["O_Soldier_F_fake", "O_Soldier_AR_fake"]] call fnc_assertEq;

opfor_EMPTY_ROLE_X = "";
["opforRoles: a role defined as an empty string is dropped too",
    ([[opfor_SOLDIER_X, opfor_EMPTY_ROLE_X]] call fnc_opforRoles),
    ["O_Soldier_F_fake"]] call fnc_assertEq;

DUWS_TEST_LOG = [];
["opforRoles: a table resolving nothing falls back to the rifleman",
    ([[opfor_MISSING_ROLE_X, opfor_ALSO_MISSING_X]] call fnc_opforRoles),
    ["O_Soldier_F_fake"]] call fnc_assertEq;
["opforRoles: the fallback warns rather than degrading silently",
    (count DUWS_TEST_LOG), 1] call fnc_assertEq;

// The case the fallback used to miss: with no rifleman defined either, handing back
// [opfor_SOLDIER_X] returned [nil] -- the exact outcome the guard exists to prevent.
opfor_SOLDIER_X = nil;
["opforRoles: with no rifleman defined either, the fallback is a vanilla class",
    ([[opfor_MISSING_ROLE_X]] call fnc_opforRoles), ["O_Soldier_F"]] call fnc_assertEq;

["opforRoles: no argument at all still yields a spawnable list",
    ([] call fnc_opforRoles), ["O_Soldier_F"]] call fnc_assertEq;

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
// Stand-in tables, not the shipped ones: these pin the mechanics -- category lookup, per-category
// multiplication, the co-op append -- and the shipped numbers are balance, which a test should not
// freeze. The extractor pulls named functions, not the globals beside them, so they are set here.
DUWS_spawnCategories = [
    ["infantry", ["patrol", "team", "sniper", "wpteam", "buildings"]],
    ["light",    ["car"]],
    ["armour",   ["armored"]],
    ["air",      ["air"]]
];
DUWS_zoneRadiusMult = [[101, 1, 1, 0, 0], [1e11, 3, 1, 2, 1]];
DUWS_zoneSpawnTiers = [["patrol"], ["patrol", "car"], ["patrol", "armored"],
    ["patrol", "team", "car", "armored", "air"]];
DUWS_zoneCoopExtra = [[], [], [], ["team"]];

["spawnCategory: a group kind resolves to infantry",
    (["wpteam"] call DUWS_fnc_spawnCategory), "infantry"] call fnc_assertEq;
["spawnCategory: armour is its own category, so radius scales it separately",
    (["armored"] call DUWS_fnc_spawnCategory), "armour"] call fnc_assertEq;
// A faction file may name a vehicle class directly and fnc_random_veh resolves it. It must still
// spawn, and at one per entry rather than at the armour multiplier.
["spawnCategory: an unlisted token is treated as light rather than dropped",
    (["O_MBT_02_cannon_F"] call DUWS_fnc_spawnCategory), "light"] call fnc_assertEq;

["zoneSpawnList: a small zone drops the categories its band zeroes",
    ([4, 50] call DUWS_fnc_zoneSpawnList), ["patrol", "team", "car"]] call fnc_assertEq;
["zoneSpawnList: a large zone repeats each entry by its own category multiplier",
    ([4, 5000] call DUWS_fnc_zoneSpawnList),
    ["patrol","patrol","patrol","team","team","team","car","armored","armored","air"]] call fnc_assertEq;
["zoneSpawnList: tier picks the composition, radius only scales it",
    ([1, 5000] call DUWS_fnc_zoneSpawnList), ["patrol","patrol","patrol"]] call fnc_assertEq;
// Appended after the multiply, so co-op adds a flat handful rather than another multiplied band.
["zoneSpawnList: the co-op extra is not multiplied",
    ([4, 5000, true] call DUWS_fnc_zoneSpawnList),
    ["patrol","patrol","patrol","team","team","team","car","armored","armored","air","team"]] call fnc_assertEq;
["zoneSpawnList: a tier above the table clamps rather than faulting",
    ([9, 50] call DUWS_fnc_zoneSpawnList), ["patrol", "team", "car"]] call fnc_assertEq;

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

// --- DUWS_fnc_groupRoster: the men behind a group token ---
// A fixture table rather than the shipped one: what is under test is how a row expands, and
// asserting against the live rosters would fail every time one of them is rebalanced.
DUWS_groupRosters = [
    ["patrol", ["opfor_A_X", "opfor_B_X"], [], ""],
    ["team", ["opfor_A_X"], ["opfor_C_X"], "opfor_TL_X"],
    ["thin", ["opfor_A_X", "opfor_ABSENT_X"], [], ""]
];
opfor_A_X = "cls_A";
opfor_B_X = "cls_B";
opfor_C_X = "cls_C";
opfor_TL_X = "cls_TL";

["groupRoster: the core repeats by the multiplier",
    (["patrol", 3] call DUWS_fnc_groupRoster), ["cls_A","cls_B","cls_A","cls_B","cls_A","cls_B"]] call fnc_assertEq;
// The whole reason the tail and the leader are their own columns: at x3 this is one marksman and
// one task leader, not three of each.
["groupRoster: the tail is added once and the leader leads",
    (["team", 3] call DUWS_fnc_groupRoster), ["cls_TL","cls_A","cls_A","cls_A","cls_C"]] call fnc_assertEq;
["groupRoster: a multiplier below one still fields the group once",
    (["patrol", 0] call DUWS_fnc_groupRoster), ["cls_A","cls_B"]] call fnc_assertEq;
["groupRoster: a role this faction does not define is dropped, not spawned as nil",
    (["thin", 1] call DUWS_fnc_groupRoster), ["cls_A"]] call fnc_assertEq;
// Nothing rather than a fallback group: the caller named a kind that does not exist, and inventing
// men for it would hide the typo behind a garrison that spawns.
["groupRoster: an unknown token fields nothing",
    (["nosuchkind", 2] call DUWS_fnc_groupRoster), []] call fnc_assertEq;

// fnc_zone_thin drops at random indices, so a thinned roster is asserted by size and by who leads
// rather than by contents. Four core men at x2 is eight, halved is four, and the leader is extra.
private _thinned = ["team", 8, 0.5] call DUWS_fnc_groupRoster;
["groupRoster: attrition thins the men",
    (count _thinned), 6] call fnc_assertEq;
// The reason thinning happens before the leader is prepended: a section ground down still has one.
["groupRoster: attrition never takes the leader",
    (_thinned select 0), "cls_TL"] call fnc_assertEq;
["groupRoster: full strength thins nothing",
    (count (["team", 8, 1] call DUWS_fnc_groupRoster)), 10] call fnc_assertEq;
