// Locality: server. Both the attempt and the roll are spent here: a client that owns either can
// retry a 10% chance until it pays.
if (!isServer) exitWith {};

params ["_player"];
if (isNull _player) exitWith {};

// Spent on the attempt, not on the outcome. A search that costs nothing when it fails is a
// button the player holds again immediately, which is how the heal action was farmed before
// fnc_civ_healed replaced it. Broadcast because the action's own condition reads it client-side.
if (_player getVariable ["DUWS_intel_searched", false]) exitWith {};
_player setVariable ["DUWS_intel_searched", true, true];

// The searcher speaks these, not Overlord: they report what one player found on one body, and
// only that player hears them. A name absent from DUWS_netSpeakers lands on VOICE unsquelched,
// which is what someone talking to themselves over a corpse should sound like. Overlord keeps
// the success line, because a revealed zone is broadcast to everyone.
private _speaker = name _player;

// Failure pays nothing but the line. The cost of a search is the 30 minutes before the next one.
if (random 1 >= intel_search_chance) exitWith {
    [_speaker, localize "STR_DUWS_T_b22m11b0"] remoteExec ["fnc_duws_dialogue", _player];
};

// A win with nothing left to uncover still consumed the attempt: the map being finished is the
// answer, not a refund.
if !(call fnc_intel_payout) then {
    [_speaker, localize "STR_DUWS_T_8skllpyx"] remoteExec ["fnc_duws_dialogue", _player];
};
