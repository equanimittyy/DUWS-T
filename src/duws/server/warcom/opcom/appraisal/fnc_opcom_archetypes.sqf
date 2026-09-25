// Locality: server, [] call'd at load. The commander's archetypes, one record each, and the one it plays.
//
// actionWeight multiplies each action's score, keyed by the row's weight (fnc_opcom_actions), Bank's included; a key
// it omits weighs 1. It is relative: weighting every key alike changes no pick, so 1 everywhere is the baseline and a
// 2 doubles an action against the rest.
//
// A mix reads each weight as a share of its mix's sum, so 1 everywhere spreads evenly and a 2 is twice as common as a
// 1. A key past its share scores less and one short of it more (DUWS_fnc_opcom_mixFactor), so the cheap types cannot
// crowd out the rest: a tilt, never a quota. hpMix weighs OPFOR's hardpoints by build type, a minefield's key carrying
// its variant, and names no asset type, since an asset build never reads it; recruitMix weighs OPCOM's live units by
// recruit-menu row.
if (!isServer) exitWith {};

DUWS_opcom_archetype = "balanced";

DUWS_opcom_archetypes = createHashMapFromArray [
    ["balanced", createHashMapFromArray [
        ["actionWeight", createHashMapFromArray [
            ["bank", 1], ["attack", 1], ["intercept", 1], ["patrol", 1], ["probe", 1], ["garrison", 1], ["ferry", 1],
            ["rapport", 1], ["arty_saturate", 1], ["arty_creeping", 1], ["zone_reinforce", 1], ["zone_fortify", 1],
            ["town_reinforce", 1], ["town_fortify", 1],
            ["build", 1], ["radio_build", 1], ["op_build", 1], ["mortar_build", 1], ["arty_build", 1]
        ]],
        ["hpMix", createHashMapFromArray [
            ["MG", 2], ["ROADBLOCK", 2], ["AT", 1], ["AA", 1], ["GMG", 1], ["MINEFIELD_AT", 0.5], ["MINEFIELD_AP", 0.5]
        ]],
        ["recruitMix", createHashMapFromArray [
            ["rifles", 8], ["weapons_team", 4], ["recon_foot", 2], ["truck", 3], ["recon_car", 2], ["boat", 1],
            ["car", 2], ["apc", 3], ["ifv", 2], ["mbt", 1], ["recon_heli", 1], ["trans_heli", 1],
            ["attack_heli", 0.5], ["jet", 0.25]
        ]]
    ]]
];

// -> the playing archetype's table by name; empty, so it leans on nothing, for an archetype or a table with no record.
DUWS_fnc_opcom_archetypeTable = {
    params ["_name"];
    (DUWS_opcom_archetypes getOrDefault [DUWS_opcom_archetype, createHashMap]) getOrDefault [_name, createHashMap]
};
