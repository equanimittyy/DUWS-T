// Locality: client; the addAction bodies below run on the machine that triggers them, not here.
#include "..\..\shared\includes\action_style.hpp"

params ["_crate"];
if (!hasInterface) exitWith {};
if (isNull _crate) exitWith {};

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
