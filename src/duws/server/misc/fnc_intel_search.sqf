// Locality: server. Both the attempt and the roll are spent here: a client that owns either can
// retry a 20% chance until it pays.
if (!isServer) exitWith {};

params ["_player"];
if (isNull _player) exitWith {};

// Spent on the attempt, not on the outcome. A search that costs nothing when it fails is a
// button the player holds again immediately, which is how the heal action was farmed before
// fnc_civ_healed replaced it.
//
// The record is the UID entry; the flag on the body is a copy of it for the action's condition to
// read client-side. Dying is what forces the split: a respawned player is a new object with no
// flag on it, and the attempt was refunded every death while the object was the only record.
private _uid = getPlayerUID _player;
if ((playerIntelSearchTick getOrDefault [_uid, -1]) == econ_tick) exitWith {};
playerIntelSearchTick set [_uid, econ_tick];
_player setVariable ["DUWS_intel_searched", true, true];

// The searcher speaks this, not Overlord: it reports what one player found on one body, and only
// that player hears it. A name absent from DUWS_netSpeakers lands on VOICE unsquelched, which is
// what someone talking to themselves over a corpse should sound like. Overlord keeps the success
// line, because a revealed zone is broadcast to everyone.
private _speaker = name _player;

// Failure pays nothing but the line. The cost of a search is the 30 minutes before the next one.
if (random 1 >= intel_search_chance) exitWith {
    [_speaker, localize "STR_DUWS_T_b22m11b0"] remoteExec ["fnc_duws_dialogue", _player];
};

// A win with nothing left to uncover still consumed the attempt: the map being finished is the
// answer, not a refund. The payout speaks that line itself, to the searcher it is handed here.
[getPos _player, _player] call fnc_intel_payout;
