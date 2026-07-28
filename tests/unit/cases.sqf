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

// --- fnc_civ_rowSpec: which slot a row spends and what it costs ---
["rowSpec: intel", (["INTEL"] call fnc_civ_rowSpec), ["INTEL", 3]] call fnc_assertEq;
["rowSpec: recruit", (["RECRUIT"] call fnc_civ_rowSpec), ["RECRUIT", 2]] call fnc_assertEq;

// The whole point of the pairing: one civilian gives aid or a toolkit, never both.
["rowSpec: aid takes the supplies slot",
    (["AID"] call fnc_civ_rowSpec), ["SUPPLIES", 1]] call fnc_assertEq;
["rowSpec: toolkit takes the same slot at the same price",
    (["TOOLKIT"] call fnc_civ_rowSpec), ["SUPPLIES", 1]] call fnc_assertEq;

["rowSpec: case-insensitive", (["intel"] call fnc_civ_rowSpec), ["INTEL", 3]] call fnc_assertEq;

// Fail closed. Rows only ever arrive over the wire, so an unrecognised one is a client sending
// something the menu never offered; the negative price is what every caller rejects on.
{
    [format ["rowSpec: %1 is rejected", str _x],
        (([_x] call fnc_civ_rowSpec) select 1) < 0, true] call fnc_assertEq;
} forEach ["", "ARREST", "SUPPLIES", "intel ", "DROP TABLE"];
