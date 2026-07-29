// Locality: all machines; the addAction body below runs on the machine that triggers it, not
// here (fnc_civ_arrest remoteExecs this to target 0 once a civilian has surrendered).
//
// The other way an arrest can end. Without it a detainee nobody frisks -- or one the reprisal roll
// spares -- keeps their hands up for the rest of the town's occupancy: PATH is disabled from the
// arrest onwards and fnc_civ_panic refuses to touch anyone surrendered, so nothing else in the
// mission ever puts them back on their feet.
#include "..\includes\action_style.hpp"

params ["_unit"];

if (isNull _unit) exitWith {};

private _actionID = _unit addAction [
    ACT_CIVILIAN_INTERACTION("STR_DUWS_T_RELEASE"),
    {
        params ["_target", "_caller", "_actionId"];
        // Removed first: the server line below speaks and sleeps, and a second click inside that
        // window would resume the same civilian twice.
        _target removeAction _actionId;
        [_target, _caller] remoteExec ["fnc_civ_release", 2];
    },
    nil,
    6,
    true,
    true,
    "",
    // Side as well as the surrender flag: fnc_civ_search_armed moves a civilian who turns on the
    // player into a resistance group and leaves isSurrendered set, so without this the player
    // could pacify someone shooting at them by handing back a walking circuit.
    "_this distance _target < 3 && {_target getVariable ['isSurrendered', false]} && {side group _target == civilian}"
];

_unit setVariable ["civ_releaseActionID", _actionID];
