// Locality: server, [] call'd at load. The commander's archetypes, one record each, and the one it plays.
//
// actionWeight multiplies the score of every action in a class, Bank's included. It is relative: weighting every
// class alike changes no pick, so 1 everywhere is the baseline and a 2 doubles a class against the rest.
//
// A mix reads each weight as a share of its mix's sum, so 1 everywhere spreads evenly and a 2 is twice as common as a
// 1. A key past its share scores less and one short of it more (DUWS_fnc_opcom_mixFactor), so the cheap types cannot
// crowd out the rest: a tilt, never a quota. hpMix weighs OPFOR's hardpoints by build type, a minefield's key carrying
// its variant; recruitMix weighs OPCOM's live units by recruit-menu row.
if (!isServer) exitWith {};

DUWS_opcom_archetype = "balanced";

DUWS_opcom_archetypes = createHashMapFromArray [
    ["balanced", createHashMapFromArray [
        ["actionWeight", createHashMapFromArray [
            ["bank", 1], ["defensive", 1], ["offensive", 1], ["buildup", 1], ["recon", 1], ["indirect", 1]
        ]],
        ["hpMix", createHashMapFromArray [
            ["MG", 2], ["ROADBLOCK", 2], ["AT", 1], ["AA", 1], ["OP", 1], ["GMG", 1],
            ["MINEFIELD_AT", 0.5], ["MINEFIELD_AP", 0.5]
        ]],
        ["recruitMix", createHashMapFromArray [
            ["rifles", 1], ["weapons_team", 1], ["recon_foot", 1], ["truck", 1], ["recon_car", 1], ["boat", 1],
            ["apc", 1], ["ifv", 1], ["mbt", 1], ["recon_heli", 1], ["trans_heli", 1], ["attack_heli", 1], ["jet", 1]
        ]]
    ]]
];

// -> the playing archetype's table by name; empty, so it leans on nothing, for an archetype or a table with no record.
DUWS_fnc_opcom_archetypeTable = {
    params ["_name"];
    (DUWS_opcom_archetypes getOrDefault [DUWS_opcom_archetype, createHashMap]) getOrDefault [_name, createHashMap]
};
