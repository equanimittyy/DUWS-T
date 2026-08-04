// Locality: client; the addAction body below runs on the machine that triggers it, not here.
// Every command action hangs off the HQ structure, mirroring shared/functions/fnc_FOBactions.sqf.
// Splitting them across the commander and the map board meant a player who lost track of either
// prop lost the menu with it, and the commander is a killable unit.
//
// Only Requests is left: everything a player has to ask command for -- the squad and FOB managers,
// mission control, the rest, the redeploy -- is a row inside that menu now. What stayed on the
// scroll wheel is what a player reaches for without asking first, on the prop it belongs to.
#include "..\..\shared\includes\action_style.hpp"

if (!hasInterface) exitWith {};

params ["_hqBuilding"];

if (isNull _hqBuilding) exitWith {};

// 防重
if (_hqBuilding getVariable ["HQ_building_actions_done", false]) exitWith {};
_hqBuilding setVariable ["HQ_building_actions_done", true];

_hqBuilding addAction [ACT_PRIMARY_MENU("STR_DUWS_T_vw32hahc"), fnc_request_menu, [], 100, true, true, "", "_this == player", ACT_REACH];

// The black market stays a scroll entry while mission control, which sat beside it, became a
// request row: this one spends the coins a player takes off civilians, not the CP that command
// answers for, so it is nobody's business to ask permission for.
_hqBuilding addAction [
    ACT_SECONDARY_MENU("STR_DUWS_T_BLACKMARKET_TITLE"),
    {
        [localize "STR_DUWS_T_BLACKMARKET_TITLE", [
            [localize "STR_DUWS_T_BLACKMARKET_BUY_GOGGLES", { [player, 1, "goggles"] remoteExec ["fnc_blackMarketPurchase", 2]; }, [], [0,1,0,1]],
            [localize "STR_DUWS_T_BLACKMARKET_BUY_PISTOL",  { [player, 5, "pistol"]  remoteExec ["fnc_blackMarketPurchase", 2]; }, [], [0,1,0,1]],
            [localize "STR_DUWS_T_BLACKMARKET_BUY_OPTIC",   { [player, 5, "optic"]   remoteExec ["fnc_blackMarketPurchase", 2]; }, [], [0,1,0,1]]
        ]] call fnc_open_action_menu;
    },
    [],
    90,
    true,
    true,
    "",
    "true",
    ACT_REACH
];
