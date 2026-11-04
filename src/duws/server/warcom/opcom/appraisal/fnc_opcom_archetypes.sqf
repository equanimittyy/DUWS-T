// Locality: server, [] call'd at load. The commander's archetypes, one record each.
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

// One pair of mixes for every archetype: the lean is in the action weights. BLUFOR's commander plays the archetype its
// task-force stance names (fnc_taskforce_commander).
private _hpMix = createHashMapFromArray [
    ["MG", 2], ["ROADBLOCK", 2], ["AT", 1], ["AA", 1], ["GMG", 1], ["MINEFIELD_AT", 0.5], ["MINEFIELD_AP", 0.5]
];
private _recruitMix = createHashMapFromArray [
    ["rifles", 8], ["weapons_team", 4], ["recon_foot", 2], ["truck", 3], ["recon_car", 2], ["boat", 1],
    ["car", 2], ["apc", 3], ["ifv", 2], ["mbt", 1], ["recon_heli", 1], ["trans_heli", 1],
    ["attack_heli", 0.5], ["jet", 0.25]
];
DUWS_opcom_archetypes = createHashMapFromArray [
    ["balanced", createHashMapFromArray [
        ["actionWeight", createHashMapFromArray [
            ["bank", 1], ["attack_assault", 1], ["attack_flank", 1], ["attack_qrf", 1], ["patrol", 1], ["probe", 1], ["garrison", 1],
            ["rapport", 0.9], ["arty_saturate", 1], ["arty_creeping", 1], ["zone_reinforce", 1], ["zone_fortify", 1],
            ["build", 1], ["radio_build", 1], ["op_build", 1], ["mortar_build", 1], ["arty_build", 1]
        ]],
        ["hpMix", _hpMix],
        ["recruitMix", _recruitMix]
    ]],
    ["aggressive", createHashMapFromArray [
        ["actionWeight", createHashMapFromArray [
            ["bank", 1], ["attack_assault", 1.6], ["attack_flank", 1.2], ["attack_qrf", 1], ["patrol", 0.8], ["probe", 1], ["garrison", 0.6],
            ["rapport", 1.3], ["arty_saturate", 1.4], ["arty_creeping", 1.2], ["zone_reinforce", 0.7], ["zone_fortify", 0.7],
            ["build", 0.7], ["radio_build", 1], ["op_build", 0.8], ["mortar_build", 1], ["arty_build", 1]
        ]],
        ["hpMix", _hpMix],
        ["recruitMix", _recruitMix]
    ]],
    ["defensive", createHashMapFromArray [
        ["actionWeight", createHashMapFromArray [
            ["bank", 1], ["attack_assault", 0.5], ["attack_flank", 0.8], ["attack_qrf", 1.5], ["patrol", 1.5], ["probe", 1.5], ["garrison", 1.5],
            ["rapport", 0.8], ["arty_saturate", 0.8], ["arty_creeping", 1], ["zone_reinforce", 1.5], ["zone_fortify", 1.5],
            ["build", 1.5], ["radio_build", 1], ["op_build", 1.2], ["mortar_build", 1], ["arty_build", 1]
        ]],
        ["hpMix", _hpMix],
        ["recruitMix", _recruitMix]
    ]]
];

// -> the playing archetype's table by name; empty, so it leans on nothing, for an archetype or a table with no record.
DUWS_fnc_opcom_archetypeTable = {
    params ["_name"];
    (DUWS_opcom_archetypes getOrDefault [_cmd get "archetype", createHashMap]) getOrDefault [_name, createHashMap]
};
