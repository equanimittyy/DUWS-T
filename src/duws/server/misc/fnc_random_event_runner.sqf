// Locality: server -- the random-event runner. Rolls once for an event each tick (5-10 min, jittered); on a hit,
// an event fires near a player against the reputation of the town nearest them
// (docs/plans/random_events_plan.md).
//
// Not the blind spawn timer fnc_WARCOM_init rules out: it spends no AP and drips nothing onto an empty
// map on a clock. It fires only near a player and only where reputation has already turned a town, so
// it is the sanctioned free-consequence-of-reputation mechanic. Anchoring on a present player rather
// than planning ahead of where the player will go is a deliberate simplification of the plan's
// predictive version -- the event lands where a player can witness it.
//
// Plain civilian path only: civ_town_rep and the town arrays it reads exist only there, not under
// NONE/RAVAGE/WBK (fnc_civ_init_Tomata). WARCOM_init gates the spawn on that; this guard is the backstop.
#define RANDOM_EVENT_TICK_MIN 300
#define RANDOM_EVENT_TICK_MAX 600
#define RANDOM_EVENT_CHANCE 0.5
#define RANDOM_EVENT_RANGE 800

if (!isServer) exitWith {};
if (isNil "CIV_PRESENCE" || {CIV_PRESENCE in ["NONE", "RAVAGE", "WBK"]}) exitWith {};

// Kinds confined to the hostile band (hi <= -10). Derived from the table so a new hostile event needs no
// edit here: they are held off a player standing in BLUFOR territory -- a turned town does not reach a
// player already safe on friendly ground (docs/plans/random_events_plan.md).
private _hostileKinds = [];
{
	_x params ["", "", "_hi", "_weights"];
	if (_hi <= -10) then { { _hostileKinds pushBackUnique (_x select 0) } forEach _weights };
} forEach [
#include "..\..\shared\includes\random_event_tables.hpp"
];

while {true} do {
	// A throw would kill this daemon for the whole session (see fnc_repetitive_cleanup). Gated with
	// nested if rather than exitWith/continue: inside a while body those read as end-of-iteration, not
	// as "skip the rest, keep the clock" (see fnc_WARCOM_opf_hardpoints).
	try {
		sleep (RANDOM_EVENT_TICK_MIN + random (RANDOM_EVENT_TICK_MAX - RANDOM_EVENT_TICK_MIN));

		if (random 1 < RANDOM_EVENT_CHANCE) then {
			private _players = call BIS_fnc_listPlayers;
			if (count _players > 0) then {
				private _player = selectRandom _players;
				private _town = [getPos _player, RANDOM_EVENT_RANGE] call fnc_civ_townNear;
				if (_town >= 0) then {
					private _rep = [_town] call fnc_civ_repAt;
					private _kind = [[_rep] call fnc_random_event_table] call fnc_search_drawKind;
					// Empty band or empty table draws to "" -- the expected path until events exist. A hostile
					// kind is skipped on a player the BLUFOR AOI already covers (skip if no valid player).
					if !(_kind isEqualTo "") then {
						if !(_kind in _hostileKinds && {[getPos _player] call fnc_aoi_blufor_covers}) then {
							[_kind, _town, _player] call fnc_random_event_fire;
						};
					};
				};
			};
		};
	} catch {
		["ERROR", "CIV", format ["random event tick threw, thread held alive: %1", _exception]] call fnc_log;
		sleep 10;
	};
};
