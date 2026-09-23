// Locality: server, [] call'd at load. The commander's archetypes, one record each, and the one it plays.
//
// A mix reads each weight as a share of its mix's sum, so 1 everywhere spreads evenly and a 2 is twice as common as a
// 1. A key past its share scores less and one short of it more (DUWS_fnc_opcom_mixFactor), so the cheap types cannot
// crowd out the rest: a tilt, never a quota. hpMix weighs OPFOR's hardpoints by build type, a minefield's key carrying
// its variant; recruitMix weighs OPCOM's live units by recruit-menu row.
if (!isServer) exitWith {};

DUWS_opcom_archetype = "balanced";

DUWS_opcom_archetypes = createHashMapFromArray [
    ["balanced", createHashMapFromArray [
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

// -> the playing archetype's mix by name; empty, so it leans on nothing, for an archetype or a mix with no record.
DUWS_fnc_opcom_archetypeMix = {
    params ["_name"];
    (DUWS_opcom_archetypes getOrDefault [DUWS_opcom_archetype, createHashMap]) getOrDefault [_name, createHashMap]
};
