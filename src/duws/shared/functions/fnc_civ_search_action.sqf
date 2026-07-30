// Locality: all machines; the addAction body below runs on the machine that triggers it, not
// here (fnc_civ_arrest remoteExecs this to target 0 once a civilian has surrendered).
//
// The second half of an arrest, and deliberately still a scroll action rather than a menu row:
// it works at 3 m on a civilian standing still with their hands up, and the interaction menu --
// which opens at arrest range and hides on isSurrendered -- would have to close, wait out the
// animation and reopen to offer it.
//
// The roll and the payout are the server's. This body used to run both on the caller's machine,
// with removeAction as the only guard -- and removeAction is local, so in co-op the entry stayed
// on every other player's screen and a second player frisked the same detainee for a second
// payout. The claim now broadcast by fnc_search_claim is what closes that.
#include "..\includes\action_style.hpp"

params ["_unit"];

if (isNull _unit) exitWith {};

// Flagged from the one machine that may author it. Civilians carry the flag unconditionally --
// the arrest is the price, and it has already been paid by the time this runs -- so the frisk's
// odds live entirely in its payout table.
if (isServer) then { [[_unit], "civ_frisk"] call fnc_search_flag_group };

private _actionID = _unit addAction [
    ACT_CIVILIAN_INTERACTION("STR_DUWS_T_LOOT"),
    {
        params ["_target", "_caller", "_actionId"];
        [localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_LOOT1"] remoteExec ["fnc_duws_dialogue", _caller];
        [_target, _caller] remoteExec ["fnc_search_claim", 2];
    },
    [],
    50,
    true,
    true,
    "",
    // The claim clause is what hides the entry once anyone has frisked this detainee, on every
    // machine at once. It replaces a local removeAction that only ever hid it from the searcher.
    "_this distance _target < 3 && {_target getVariable ['isSurrendered', false]}"
        + " && {!(_target getVariable ['DUWS_search_done', false])}"
];

_unit setVariable ["civ_searchActionID", _actionID];
