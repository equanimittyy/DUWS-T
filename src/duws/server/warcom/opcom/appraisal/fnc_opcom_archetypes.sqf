// Locality: server, [] call'd at load. The commander's archetypes, one record each, and the one it plays.
//
// actionWeight multiplies each action's score, keyed by its id (fnc_opcom_actions), Bank's included; an id it omits
// weighs 1. It is relative: weighting every action alike changes no pick, so 1 everywhere is the baseline and a 2
// doubles an action against the rest.
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
            ["bank", 1], ["attack", 1], ["intercept", 1], ["scout", 1], ["rapport", 1], ["arty", 1],
            ["zone_reinforce", 1], ["zone_fortify", 1], ["town_reinforce", 1], ["town_fortify", 1],
            ["zone_build_mg", 1], ["zone_build_at", 1], ["zone_build_roadblock", 1], ["zone_build_gmg", 1],
            ["standalone_build_mg", 1], ["standalone_build_at", 1], ["standalone_build_aa", 1],
            ["standalone_build_roadblock", 1], ["standalone_build_gmg", 1],
            ["radio_build", 1], ["op_build", 1], ["mortar_build", 1], ["arty_build", 1],
            ["mine_build_at", 1], ["mine_build_ap", 1],
            ["recruit_rifles", 1], ["recruit_weapons_team", 1], ["recruit_recon_foot", 1], ["recruit_truck", 1],
            ["recruit_recon_car", 1], ["recruit_boat", 1], ["recruit_apc", 1], ["recruit_ifv", 1], ["recruit_mbt", 1],
            ["recruit_recon_heli", 1], ["recruit_trans_heli", 1], ["recruit_attack_heli", 1], ["recruit_jet", 1]
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
