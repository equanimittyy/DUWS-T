// Locality: server, [] call'd at load. The action list the pick stage (fnc_opcom_pick) draws from.
// DUWS_opcom_actions row: [id, class, targets, execute, arg].
//   arg call targets -> [[target, price, label, value, pWin, cost], ...], the action's legal targets now. `arg` is
//     the row's fixed argument: the hardpoint type or mine variant for a build row, the sweep for a commit row, the
//     errand and its offer for a town row, and [] elsewhere. Runs inside isNil, so it never suspends. `value` is the
//     AP the target returns; omitting it scores the action break-even until its category is appraised. `pWin` is the
//     odds a unit sent into contact wins it, so only an order that fights for its target carries one -- a buy stocks
//     ground OPCOM already holds and leaves it out. `cost` is what the score divides by, the price when omitted; a
//     commit order pays no AP but stakes a unit, so it names both.
//   [target, price] call execute -> true when the action landed; the pick charges the price only then.
if (!isServer) exitWith {};

DUWS_opcom_actions = [
    // Priced at nothing, so its Value doubles as its score: the bar every other action has to clear to be worth buying.
    ["bank", "bank", { [[[], 0, "Bank", OPCOM_BANK_SCORE]] }, { true }],
    ["zone_reinforce", "defensive", DUWS_fnc_opcom_zoneReinforceTargets, DUWS_fnc_opcom_zoneReinforceRun],
    ["zone_fortify", "defensive", DUWS_fnc_opcom_zoneFortifyTargets, DUWS_fnc_opcom_zoneFortifyRun],
    ["town_reinforce", "defensive", DUWS_fnc_opcom_townTargets, DUWS_fnc_opcom_townRun,
        ["reinforce", "DUWS_townGarrisonTier", DUWS_fnc_opcom_townReinforceOffer]],
    ["town_fortify", "defensive", DUWS_fnc_opcom_townTargets, DUWS_fnc_opcom_townRun,
        ["fortify", "DUWS_townGarrisonTier", DUWS_fnc_opcom_townFortifyOffer]],
    ["rapport", "offensive", DUWS_fnc_opcom_townTargets, DUWS_fnc_opcom_townRun,
        ["rapport", "civ_town_rep", DUWS_fnc_opcom_rapportOffer]],
    ["attack", "offensive", DUWS_fnc_opcom_commitTargets, DUWS_fnc_opcom_sendRun, ["attackSweep"]],
    ["intercept", "defensive", DUWS_fnc_opcom_commitTargets, DUWS_fnc_opcom_sendRun, ["interceptSweep"]],
    ["scout", "recon", DUWS_fnc_opcom_commitTargets, DUWS_fnc_opcom_sendRun, ["scoutSweep"]],
    // Indirect, not offensive: an archetype that leans on indirect fire leans on firing the guns as well as building them.
    ["arty", "indirect", DUWS_fnc_opcom_fireTargets, DUWS_fnc_opcom_fireRun]
];

// One row per type, never one row offering several: the pick draws an action, so a shared row would decide the type
// for it and leave the archetype nothing to lean on (4C.1).
{
    DUWS_opcom_actions pushBack [format ["zone_build_%1", toLower _x], "defensive",
        DUWS_fnc_opcom_zoneBuildTargets, DUWS_fnc_opcom_zoneBuildRun, [_x]];
} forEach (keys DUWS_hardpointWeightZone);
{
    DUWS_opcom_actions pushBack [format ["standalone_build_%1", toLower _x], "defensive",
        DUWS_fnc_opcom_standaloneBuildTargets, DUWS_fnc_opcom_standaloneBuildRun, [_x]];
} forEach (keys DUWS_hardpointWeightSolo);
{
    _x params ["_type", "_class"];
    DUWS_opcom_actions pushBack [format ["%1_build", toLower _type], _class,
        DUWS_fnc_opcom_assetTargets, DUWS_fnc_opcom_standaloneBuildRun, [_type]];
} forEach [["RADIO", "buildup"], ["OP", "recon"], ["MORTAR", "indirect"], ["ARTY", "indirect"]];
{
    DUWS_opcom_actions pushBack [format ["mine_build_%1", toLower _x], "defensive",
        DUWS_fnc_opcom_mineBuildTargets, DUWS_fnc_opcom_mineBuildRun, [_x]];
} forEach ["AT", "AP"];
