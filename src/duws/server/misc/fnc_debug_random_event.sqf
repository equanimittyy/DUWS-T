// Locality: server -- fnc_debug_random_event_menu remoteExecs it to target 2 with [kind, player]. Fires one
// random event by hand: resolves that player's nearest town (as the runner does) and dispatches through
// fnc_random_event_fire, so the forced event runs exactly the code a rolled one does. Not broadcast: the
// menu re-checks game_master before sending, matching fnc_debug_force_mission.
if (!isServer) exitWith {};
params [["_kind", ""], ["_player", objNull]];
if (_kind isEqualTo "" || {isNull _player}) exitWith {};

// No threshold, unlike the runner: a debug fire should land whatever town the player is standing near,
// so the nearest is always taken.
private _town = [getPos _player, 1e6] call fnc_civ_townNear;
["INFO", "CIV", format ["debug: forcing random event '%1' on %2 at town %3", _kind, name _player, _town]] call fnc_log;
[_kind, _town, _player] call fnc_random_event_fire;
