// Locality: client; the addAction body below runs on the machine that triggers it, not here.
// Every command action hangs off the HQ structure, mirroring shared/functions/fnc_FOBactions.sqf.
// Splitting them across the commander and the map board meant a player who lost track of either
// prop lost the menu with it, and the commander is a killable unit.
//
// Only Requests is left: everything a player has to ask command for -- the squad and FOB managers,
// mission control, the rest, the redeploy -- is a row inside that menu now.
#include "..\..\shared\includes\action_style.hpp"

if (!hasInterface) exitWith {};

params ["_hqBuilding"];

if (isNull _hqBuilding) exitWith {};

if (_hqBuilding getVariable ["HQ_building_actions_done", false]) exitWith {};
_hqBuilding setVariable ["HQ_building_actions_done", true];

_hqBuilding addAction [ACT_PRIMARY_MENU("STR_DUWS_T_vw32hahc"), fnc_request_menu, [], 100, true, true, "", "_this == player", ACT_REACH];
