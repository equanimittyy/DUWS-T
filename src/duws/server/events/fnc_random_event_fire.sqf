// Locality: server -- turns a rolled event kind into what happens at the town. The runner has already
// picked the player, town and kind; this owns the how. One switch: a new event is a case here plus a
// row in fnc_random_event_table, and the runner never changes.
//
// A hostile case must honour two invariants -- an attacker is isHostile so the player is not charged
// a war crime for self-defence, and it becomes a legal target before it becomes lethal. An unhandled
// kind lands in the default and only logs.
if (!isServer) exitWith {};
params [["_kind", ""], ["_townIndex", -1], ["_player", objNull]];
if (_kind isEqualTo "") exitWith {};

switch (_kind) do {
	case "civ_car":      { [_townIndex, _player] call fnc_random_event_car };
	case "civ_heli":     { [_townIndex, _player] call fnc_random_event_heli };
	case "civ_convoy":   { [_townIndex, _player] call fnc_random_event_convoy };
	case "civ_stranded": { [_townIndex, _player] call fnc_random_event_stranded };
	case "car_bomb":     { [_townIndex, _player] call fnc_random_event_car_bomb };
	case "recon_patrol": { [_townIndex, _player] call fnc_random_event_recon_patrol };
	case "enemy_car":    { [_townIndex, _player] call fnc_random_event_enemy_car };
	case "enemy_sniper": { [_townIndex, _player] call fnc_random_event_enemy_sniper };
	case "ied":          { [_townIndex, _player] call fnc_random_event_ied };
	// Civilian "attackers" by design: the isHostile invariant above is waived here (fnc_random_event_mob).
	case "angry_mob":    { [_townIndex, _player] call fnc_random_event_mob };
	// Same event, escalation on: instigators break off, draw pistols and turn EAST after a fuse (fnc_random_event_mob).
	case "angry_mob2":   { [_townIndex, _player, true] call fnc_random_event_mob };
	default {
		["INFO", "CIV", format ["random event '%1' rolled at town %2 (no handler yet)", _kind, _townIndex]] call fnc_log;
	};
};
