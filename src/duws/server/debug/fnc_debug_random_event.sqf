// Locality: server -- fnc_debug_random_event_menu remoteExecs it to target 2 with [kind, player]. Fires one
// random event by hand: honours the runner's AoI gate, resolves that player's nearest town (as the runner
// does) and dispatches through fnc_random_event_fire, so the forced event runs exactly the code a rolled one
// does. Not broadcast: the menu re-checks game_master before sending, matching fnc_debug_force_mission.
if (!isServer) exitWith {};
params [["_kind", ""], ["_player", objNull]];
if (_kind isEqualTo "" || {isNull _player}) exitWith {};

// Honour the runner's gate: a hostile kind fired within the HQ safe haven is suppressed here too, so the
// debug tool cannot force what a roll never would. Feedback back to the caller so the no-op is not silent.
if !([_kind, _player] call fnc_random_event_allowed) exitWith {
	["INFO", "CIV", format ["debug: random event '%1' suppressed near HQ on %2", _kind, name _player]] call fnc_log;
	["Event suppressed: player within the HQ safe haven."] remoteExec ["hint", _player];
};

// No threshold, unlike the runner: a debug fire should land whatever town the player is standing near,
// so the nearest is always taken.
private _town = [getPos _player, 1e6] call fnc_civ_townNear;
["INFO", "CIV", format ["debug: forcing random event '%1' on %2 at town %3", _kind, name _player, _town]] call fnc_log;
[_kind, _town, _player] call fnc_random_event_fire;
