// Copies a spent attempt back onto the body a player is currently in. The record is the UID entry
// in playerIntelSearchTick and that is what refuses a search, so this only brings the client-visible
// flag back in line with it -- a respawned or joining player would otherwise be shown an action the
// server silently refuses. Safe to let the client ask for: nothing here grants anything.
// Not published; fnc_intel_search_action remoteExecs it.
if (!isServer) exitWith {};
params ["_player"];
if (isNull _player) exitWith {};
if ((playerIntelSearchTick getOrDefault [getPlayerUID _player, -1]) == econ_tick) then {
	_player setVariable ["DUWS_intel_searched", true, true];
};
