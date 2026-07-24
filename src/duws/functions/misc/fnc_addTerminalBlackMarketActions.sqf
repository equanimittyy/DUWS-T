/*
    fnc_addTerminalBlackMarketActions.sqf
*/
if (!hasInterface) exitWith {};

params ["_terminal"];
if (isNull _terminal) exitWith {};
if (_terminal getVariable ["blackMarketActionsDone", false]) exitWith {};
_terminal setVariable ["blackMarketActionsDone", true];

_terminal addAction [
    format ["<t color='#00ff00'>%1</t>", localize "STR_DUWS_T_BLACKMARKET_TITLE"],
    {
        [localize "STR_DUWS_T_BLACKMARKET_TITLE", [
            [localize "STR_DUWS_T_BLACKMARKET_BUY_GOGGLES", { [player, 1, "goggles"] remoteExec ["fnc_blackMarketPurchase", 2]; }, [], [0,1,0,1]],
            [localize "STR_DUWS_T_BLACKMARKET_BUY_PISTOL",  { [player, 5, "pistol"]  remoteExec ["fnc_blackMarketPurchase", 2]; }, [], [0,1,0,1]],
            [localize "STR_DUWS_T_BLACKMARKET_BUY_OPTIC",   { [player, 5, "optic"]   remoteExec ["fnc_blackMarketPurchase", 2]; }, [], [0,1,0,1]],
            [localize "STR_DUWS_T_INTEL_ANALYSIS_ACTION",   { [player] remoteExec ["fnc_intelAnalysis", 2]; }, [], [1,0.667,0,1]],
            [localize "STR_DUWS_T_HIRE_PARTISANS",          { [player] remoteExec ["fnc_hirePartisans", 2]; }, [], [1,0.667,0,1]],
            [localize "STR_DUWS_T_HIRE_PMC",                { [player] remoteExec ["fnc_hirePMC", 2]; }, [], [1,0.667,0,1]]
        ]] call fnc_open_action_menu;
    },
    nil,
    6,
    true,
    true,
    "",
    "true"
];
