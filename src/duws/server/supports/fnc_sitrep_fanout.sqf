// Hands each player their own SITREP, because one line of it is local to where they stand: the
// reputation of the town they are in. The support runs on the client that bought it and
// civ_town_rep is never broadcast, so nothing client-side can answer that. Not published --
// fnc_sitrep_support remoteExecs it here rather than calling it.
if (!isServer) exitWith {};
private _reps = missionNamespace getVariable ["civ_town_rep", []];
{
	private _town = [getPos _x] call fnc_civ_townAt;
	// Sent as text, not a number: open country, a civilians-off campaign and RAVAGE/WBK all
	// register no reputation, and a 0 would report those as a town that feels neutral about
	// the player. Read straight out of the array rather than through fnc_civ_repAt, which
	// cannot make that distinction either.
	private _rep = if (_town >= 0 && _town < count _reps) then {
		str (_reps select _town)
	} else {
		"--"
	};
	[_rep] remoteExec ["fnc_sitrep_display", _x];
} forEach allPlayers;
