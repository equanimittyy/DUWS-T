// Locality: all machines; the addAction body below runs on the machine that triggers it, not here
// (fnc_civ_spawnUnit remoteExecs this to target 0 with the unit as the JIP id).
#include "..\includes\action_style.hpp"

params ["_unit"];

if (isNull _unit) exitWith {};

// The JIP queue replays for every joining client and a killed vendor respawns, so a duplicate is a
// real risk -- and it would read as two identical entries in one scroll menu.
if (_unit getVariable ["DUWS_vendor_menuAdded", false]) exitWith {};
_unit setVariable ["DUWS_vendor_menuAdded", true];

_unit addAction [
    ACT_CIVILIAN_INTERACTION("STR_DUWS_T_VENDOR_ACTION"),
    {
        params ["_target"];
        // Spawned: the catalogue waits on the dialog and on the server's stock answer.
        [_target] spawn fnc_vendor_catalogue;
    },
    [],
    50,
    true,
    true,
    "",
    // Distance and alive alone, at the range the civilian menu works at. The civilian action's own
    // condition is a call-over state machine plus a one-exchange budget -- DUWS_civ_stopped,
    // isSurrendered, DUWS_civ_closed, DUWS_civ_arrested -- and a vendor reads none of those and sets
    // none of them. A shop is open as often as the player walks up to it.
    "alive _target && {_this distance _target < 3}"
];

_unit addEventHandler ["Killed", {
    params ["_unit"];
    removeAllActions _unit;
    [_unit] remoteExec ["removeAllActions", 0];
}];
