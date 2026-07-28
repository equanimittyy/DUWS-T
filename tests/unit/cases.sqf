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

// Reputation is clamped to +-20 by fnc_town_rep_adjust, but the global Player_Reputation
// fallback is not, so out-of-range input must saturate rather than run the line past its ends
// into a negative weight.
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
} forEach [5, 10, 15, 20, 30];

// The Altis survey registers two hamlets at 3 and 4 buildings and nothing else below 47, so the
// population cap only ever binds on those two. Every real town takes the setting whole, and what
// separates them is how much ground their cluster covers rather than how many people are in it.
[[3, 4, 47, 260], [0]] call _stage;
{
    _x params ["_town", "_pop", "_expected"];
    [format ["liveTarget: a %1-building town holds %2", _pop, _expected],
        ([15, _town] call fnc_civ_liveTarget), _expected] call fnc_assertEq;
} forEach [[0, 3, 3], [1, 4, 4], [2, 47, 15], [3, 260, 15]];
