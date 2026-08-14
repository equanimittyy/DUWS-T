// Locality: client; the addAction bodies below run on the machine that triggers them, not here.
#include "..\..\shared\includes\action_style.hpp"

params ["_crate"];
if (!hasInterface) exitWith {};
if (isNull _crate) exitWith {};

// Quick kits hand out a full standard-issue role loadout on demand. Hybrid can afford that -- friendly
// gear is the unlimited floor -- but Limited tracks every class, so an on-demand kit would bypass the
// pool the mode exists to enforce. Offer no quick-kit action there. Set at boot in server_var_init and
// broadcast, so it is already known by the time any crate this attaches to exists.
if (missionNamespace getVariable ["DUWS_arsenalLimited", false]) exitWith {};

// wait for the data the server scans and broadcasts
waitUntil {sleep 0.1; !isNil "blufor_quickChange_loadouts_scanned"};

// dedup: remove any actions already present
private _actionAID = _crate getVariable ["quickChange_actionA", -1];
if (_actionAID != -1) then { _crate removeAction _actionAID; };

_actionAID = _crate addAction [
    ACT_EQUIP("STR_DUWS_T_QUICK_KITS"),
    { [] call fnc_quick_kits_menu; },
    [],
    80,
    true,
    true,
    "",
    "_this distance _target < 3"
];
_crate setVariable ["quickChange_actionA", _actionAID];
