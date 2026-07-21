/*
    fnc_addTerminalBlackMarketActions.sqf
*/
if (!hasInterface) exitWith {};

params ["_terminal"];
if (isNull _terminal) exitWith {};
if (_terminal getVariable ["blackMarketActionsDone", false]) exitWith {};
_terminal setVariable ["blackMarketActionsDone", true];

// ========== 黑市购买动作（原有） ==========
_terminal addAction [
    format ["<t color='#00ff00'>%1</t>", localize "STR_DUWS_T_BLACKMARKET_BUY_GOGGLES"],
    {
        params ["_target", "_caller", "_actionId"];
        [_caller, 1, "goggles"] remoteExec ["fnc_blackMarketPurchase", 2];
    },
    nil,
    6,
    true,
    true,
    "",
    "true"
];

_terminal addAction [
    format ["<t color='#00ff00'>%1</t>", localize "STR_DUWS_T_BLACKMARKET_BUY_PISTOL"],
    {
        params ["_target", "_caller", "_actionId"];
        [_caller, 5, "pistol"] remoteExec ["fnc_blackMarketPurchase", 2];
    },
    nil,
    6,
    true,
    true,
    "",
    "true"
];

_terminal addAction [
    format ["<t color='#00ff00'>%1</t>", localize "STR_DUWS_T_BLACKMARKET_BUY_OPTIC"],
    {
        params ["_target", "_caller", "_actionId"];
        [_caller, 5, "optic"] remoteExec ["fnc_blackMarketPurchase", 2];
    },
    nil,
    6,
    true,
    true,
    "",
    "true"
];

// ========== 统一情报分析动作 ==========
_terminal addAction [
    format ["<t color='#ffaa00'>%1</t>", localize "STR_DUWS_T_INTEL_ANALYSIS_ACTION"],
    {
        params ["_target", "_caller", "_actionId"];
        [_caller] remoteExec ["fnc_intelAnalysis", 2];
    },
    nil,
    6,
    true,
    true,
    "",
    "true"
];

_terminal addAction [
    format ["<t color='#ffaa00'>%1</t>", localize "STR_DUWS_T_HIRE_PARTISANS"],
    {
        params ["_target", "_caller", "_actionId"];
        [_caller] remoteExec ["fnc_hirePartisans", 2];
    },
    nil,
    6,
    true,
    true,
    "",
    "true"
];

_terminal addAction [
    format ["<t color='#ffaa00'>%1</t>", localize "STR_DUWS_T_HIRE_PMC"],
    {
        params ["_target", "_caller", "_actionId"];
        [_caller] remoteExec ["fnc_hirePMC", 2];
    },
    nil,
    6,
    true,
    true,
    "",
    "true"
];