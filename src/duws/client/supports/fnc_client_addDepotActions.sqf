// Locality: client; the addAction body runs on the machine that triggers it, not here.
#include "..\..\shared\includes\action_style.hpp"

if (!hasInterface) exitWith {};
params ["_depot", "_trgNetId"];
if (isNull _depot) exitWith {};

if (_depot getVariable ["depot_actions_done", false]) exitWith {};
_depot setVariable ["depot_actions_done", true];

private _trg = objectFromNetId _trgNetId;
if (isNull _trg) exitWith { ["ERROR", "SUPPORT", "Trigger null on client"] call fnc_log; };

// One "Vehicle Depot" action replaces the old pair (Vehicle Customization / Vehicle Recycling): it
// opens the unified dialog, whose three panels cover modification, storage and recycling.
_depot addAction [
    ACT_SECONDARY_MENU("STR_DUWS_T_DEPOT_MENU"),
    { params ["_t", "_c", "_i", "_args"]; _args call fnc_vehicle_depot_menu; },
    [_trg],
    90,
    true,
    true,
    "",
    "_this distance _target < 8"
];
