// Locality: client -- an fnc_open_action_menu row handler, so it runs on whoever opened the menu.
/*
    Developer tool: spawn one random event by hand, bypassing the runner's roll but still honouring the
    HQ safe-haven gate. Three stages, each a
    call back into this function: pick a player, pick a table (reputation band), pick an event in it.
    The final pick remoteExecs fnc_debug_random_event to the server, which resolves that player's nearest
    town and fires it. Reached from fnc_debug_menu.sqf; strings are English-only for the same reason.
*/
#include "..\..\shared\includes\debug_menu.hpp"
if (!hasInterface) exitWith {};

// Re-checked rather than trusted to the caller: this function is publicVariable'd, so every client
// holds a copy it can call, and firing an event makes the server do real work.
if (!((vehiclevarname player) in game_master)) exitWith {};

params [["_stage", "player"], ["_player", objNull], ["_bandIdx", -1]];

private _bands = [
#include "..\..\shared\includes\random_event_tables.hpp"
];

switch (_stage) do {
	case "player": {
		private _rows = [DBG_BACK("missions")];
		{
			_rows pushBack [format ["%1 >", name _x], {
				["table", _this] call fnc_debug_random_event_menu;
			}, _x, DBG_PAGE];
		} forEach (call BIS_fnc_listPlayers);
		["Spawn random event: pick player", _rows] call fnc_open_action_menu;
	};

	case "table": {
		private _rows = [["< Back", fnc_debug_random_event_menu, ["player"], DBG_PAGE]];
		{
			_x params ["_label", "_lo", "_hi", "_weights"];
			// Skip a band with no events -- it would open an empty pick list. _forEachIndex, not a
			// running counter: the event stage indexes the full band list, so the row must carry the
			// unfiltered index.
			if !(_weights isEqualTo []) then {
				_rows pushBack [format ["%1  (rep %2 to %3) >", _label, _lo, _hi], {
					params ["_p", "_bi"];
					["event", _p, _bi] call fnc_debug_random_event_menu;
				}, [_player, _forEachIndex], DBG_PAGE];
			};
		} forEach _bands;
		[format ["Spawn random event on %1: pick table", name _player], _rows] call fnc_open_action_menu;
	};

	case "event": {
		private _weights = (_bands select _bandIdx) select 3;
		private _rows = [["< Back", fnc_debug_random_event_menu, ["table", _player], DBG_PAGE]];
		{
			_x params ["_kind", "_w"];
			_rows pushBack [format ["%1  (weight %2)", _kind, _w], {
				params ["_p", "_kind"];
				[_kind, _p] remoteExec ["fnc_debug_random_event", 2];
				hint format ["Spawning random event '%1' on %2.\n\nBypasses the runner roll but still honors the HQ gate:\na hostile kind within HQ reach is suppressed.", _kind, name _p];
			}, [_player, _kind], DBG_ACTION];
		} forEach _weights;
		[format ["Spawn '%1' event: pick one", (_bands select _bandIdx) select 0], _rows] call fnc_open_action_menu;
	};
};
