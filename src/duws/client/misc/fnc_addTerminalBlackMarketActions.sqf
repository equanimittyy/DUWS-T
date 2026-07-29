// Locality: client; the addAction bodies below run on the machine that triggers them, not here.
/*
    fnc_addTerminalBlackMarketActions.sqf
*/
#include "..\..\shared\includes\action_style.hpp"

if (!hasInterface) exitWith {};

params ["_terminal"];
if (isNull _terminal) exitWith {};
if (_terminal getVariable ["blackMarketActionsDone", false]) exitWith {};
_terminal setVariable ["blackMarketActionsDone", true];

_terminal addAction [
    ACT_SECONDARY_MENU("STR_DUWS_T_BLACKMARKET_TITLE"),
    {
        [localize "STR_DUWS_T_BLACKMARKET_TITLE", [
            [localize "STR_DUWS_T_BLACKMARKET_BUY_GOGGLES", { [player, 1, "goggles"] remoteExec ["fnc_blackMarketPurchase", 2]; }, [], [0,1,0,1]],
            [localize "STR_DUWS_T_BLACKMARKET_BUY_PISTOL",  { [player, 5, "pistol"]  remoteExec ["fnc_blackMarketPurchase", 2]; }, [], [0,1,0,1]],
            [localize "STR_DUWS_T_BLACKMARKET_BUY_OPTIC",   { [player, 5, "optic"]   remoteExec ["fnc_blackMarketPurchase", 2]; }, [], [0,1,0,1]]
        ]] call fnc_open_action_menu;
    },
    nil,
    85,
    true,
    true,
    "",
    "true"
];

// Its own entry rather than three more rows under the black market: what the terminal sells out of
// a crate and what command puts at the player's disposal are two different transactions, and the
// list had grown long enough that the split is what tells them apart.
_terminal addAction [
    ACT_SECONDARY_MENU("STR_DUWS_T_INTELRECRUIT_TITLE"),
    {
        [localize "STR_DUWS_T_INTELRECRUIT_TITLE", [
            [localize "STR_DUWS_T_INTEL_ANALYSIS_ACTION",   { [player] remoteExec ["fnc_intelAnalysis", 2]; }, [], [1,0.667,0,1]],
            [localize "STR_DUWS_T_HIRE_PARTISANS",          { [player] remoteExec ["fnc_hirePartisans", 2]; }, [], [1,0.667,0,1]],
            [localize "STR_DUWS_T_HIRE_PMC",                { [player] remoteExec ["fnc_hirePMC", 2]; }, [], [1,0.667,0,1]]
        ]] call fnc_open_action_menu;
    },
    nil,
    84,
    true,
    true,
    "",
    "true"
];
