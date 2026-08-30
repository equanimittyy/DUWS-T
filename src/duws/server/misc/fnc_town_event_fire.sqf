// Locality: server -- turns a rolled event kind into what happens at the town. The runner has already
// picked the player, town and kind; this owns the how. One switch: a new event is a case here plus a
// row in fnc_town_event_table, and the runner never changes.
//
// A hostile case must honour the town_events_plan invariants -- an attacker is isHostile so the player
// is not charged a war crime for self-defence, and it becomes a legal target before it becomes lethal
// (docs/plans/town_events_plan.md). Empty for now: every kind lands in the default.
if (!isServer) exitWith {};
params [["_kind", ""], ["_townIndex", -1], ["_player", objNull]];
if (_kind isEqualTo "") exitWith {};

switch (_kind) do {
	default {
		["INFO", "CIV", format ["town event '%1' rolled at town %2 (no handler yet)", _kind, _townIndex]] call fnc_log;
	};
};
