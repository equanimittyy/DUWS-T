// Locality: any machine -- reads only the broadcast slot lists and the player list, so every
// client resolves the same person and the whole team sees one name against the callsign.

// The player the team callsign currently speaks for: the game master if one is connected, then
// the highest squad-lead slot, then the first player by name.
//
// Seniority is read off game_master and Squad_Leaders in their own order. Those are
// publicVariable'd and identical everywhere, whereas BIS_fnc_listPlayers is not ordered the same
// on every machine -- picking straight out of it would let two clients disagree about who is
// talking on the same line.
private _players = call BIS_fnc_listPlayers;
if (_players isEqualTo []) exitWith { "None" };

private _bySlot = {
	params ["_slots"];
	private _hit = "";
	{
		private _slot = _x;
		private _i = _players findIf {(vehicleVarName _x) isEqualTo _slot};
		if (_i > -1) exitWith { _hit = name (_players select _i) };
	} forEach _slots;
	_hit
};

private _who = [missionNamespace getVariable ["game_master", []]] call _bySlot;
if (_who isEqualTo "") then {
	_who = [missionNamespace getVariable ["Squad_Leaders", []]] call _bySlot;
};
// Sorted, not raw list order, for the same reason as above. Unreachable while Squad_Leaders
// still lists every playable slot; it starts to matter the moment that array is trimmed.
if (_who isEqualTo "") then {
	private _names = _players apply {name _x};
	_names sort true;
	_who = _names param [0, "None"];
};
_who
