// Locality: server. The hands-up roll, moved off the client action it used to live on: a 90 %
// chance a client owns is a 90 % chance a client can retry.
//
// Arrest is coercion, not a request: it rolls no reaction and takes no bribe. It is still one of
// the exchanges a civilian only has one of, so a person who has already been talked to is spent.
if (!isServer) exitWith {};

params ["_civilian", "_caller"];

if (isNull _civilian || isNull _caller) exitWith {};
if (!alive _civilian) exitWith {};

// Spent on the attempt, not on the outcome. The scroll action this replaces removed itself when
// clicked, so its 10 % runner could not be retried; a dialog row is redrawn on every open, and
// without this flag the player holds the row until the 90 % lands, which makes both the
// reputation hit and the escape free.
//
// The closed flag is re-read here and not just greyed client-side: the action is removed on every
// machine when a civilian is spent, but a dialog already open when the flag lands still has its
// row live, and the row only ever arrives over the wire.
if (_civilian getVariable ["DUWS_civ_arrested", false]) exitWith {};
if (_civilian getVariable ["DUWS_civ_closed", false]) exitWith {};
_civilian setVariable ["DUWS_civ_arrested", true, true];

[name _caller, localize "STR_DUWS_T_HANDSUP1"] remoteExec ["fnc_duws_dialogue", _caller];

_civilian disableAI "PATH";

// Charged whether or not they comply: the town saw the weapon raised either way.
[_civilian getVariable ["civ_locIndex", -1], -1, "civilian_arrested"] call fnc_town_rep_adjust;

sleep 3;
if (isNull _civilian || !alive _civilian) exitWith {};

if (random 1 < 0.9) then {
    [_civilian, "AmovPercMstpSsurWnonDnon"] remoteExec ["playMoveNow", 0];
    // Broadcast, unlike the client-local write this replaces: the search action's condition is
    // evaluated on every machine that carries it, so a local-only flag left the action invisible
    // to everyone but the player who ordered the surrender.
    _civilian setVariable ["isSurrendered", true, true];
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_HANDSUP2"] remoteExec ["fnc_duws_dialogue", _caller];
    // PATH stays disabled: a surrendered civilian holds still until they are let go or armed.
    // Both endings are offered at once -- searching them is a second decision, not the only one,
    // and a detainee left with neither stands there until the town is recycled.
    // Flagged rather than given an action of its own: a detainee holds still, so the player's
    // outward-looking search action reaches them the same way it reaches a body. Civilians are
    // flagged unconditionally -- the arrest is the price, and it has just been paid -- so the
    // frisk's odds live entirely in its payout table.
    [[_civilian], "civ_frisk"] call fnc_search_flag_group;
    [_civilian] remoteExec ["fnc_civ_release_action", 0];
} else {
    _civilian enableAI "PATH";
    [_civilian] call fnc_civ_resume;
    [localize "STR_DUWS_T_civ", localize "STR_DUWS_T_HANDSUP3"] remoteExec ["fnc_duws_dialogue", _caller];
};
