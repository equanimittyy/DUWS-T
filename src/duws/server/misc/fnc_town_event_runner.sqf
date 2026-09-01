// Locality: server -- the town-event runner. Rolls once for an event each tick (5-10 min, jittered); on a hit,
// an event fires near a player against the reputation of the town nearest them
// (docs/plans/town_events_plan.md).
//
// Not the blind spawn timer fnc_WARCOM_init rules out: it spends no AP and drips nothing onto an empty
// map on a clock. It fires only near a player and only where reputation has already turned a town, so
// it is the sanctioned free-consequence-of-reputation mechanic. Anchoring on a present player rather
// than planning ahead of where the player will go is a deliberate simplification of the plan's
// predictive version -- the event lands where a player can witness it.
//
// Plain civilian path only: civ_town_rep and the town arrays it reads exist only there, not under
// NONE/RAVAGE/WBK (fnc_civ_init_Tomata). WARCOM_init gates the spawn on that; this guard is the backstop.
#define TOWN_EVENT_TICK_MIN 300
#define TOWN_EVENT_TICK_MAX 600
#define TOWN_EVENT_CHANCE 0.5
#define TOWN_EVENT_RANGE 800

if (!isServer) exitWith {};
if (isNil "CIV_PRESENCE" || {CIV_PRESENCE in ["NONE", "RAVAGE", "WBK"]}) exitWith {};

while {true} do {
	// A throw would kill this daemon for the whole session (see fnc_repetitive_cleanup). Gated with
	// nested if rather than exitWith/continue: inside a while body those read as end-of-iteration, not
	// as "skip the rest, keep the clock" (see fnc_WARCOM_opf_hardpoints).
	try {
		sleep (TOWN_EVENT_TICK_MIN + random (TOWN_EVENT_TICK_MAX - TOWN_EVENT_TICK_MIN));

		if (random 1 < TOWN_EVENT_CHANCE) then {
			private _players = call BIS_fnc_listPlayers;
			if (count _players > 0) then {
				private _player = selectRandom _players;
				private _town = [getPos _player, TOWN_EVENT_RANGE] call fnc_civ_townNear;
				if (_town >= 0) then {
					private _rep = [_town] call fnc_civ_repAt;
					private _kind = [[_rep] call fnc_town_event_table] call fnc_search_drawKind;
					// Empty band or empty table draws to "" -- the expected path until events exist.
					if !(_kind isEqualTo "") then {
						[_kind, _town, _player] call fnc_town_event_fire;
					};
				};
			};
		};
	} catch {
		["ERROR", "CIV", format ["town event tick threw, thread held alive: %1", _exception]] call fnc_log;
		sleep 10;
	};
};
