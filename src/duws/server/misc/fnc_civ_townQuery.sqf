// Locality: server. Answers one map click from the board's View Map action: which town, if
// any, sits under the clicked position. The lookup cannot live on the client -- civ_locations,
// civ_radii, the per-town population variables and civ_town_rep are all server-only and none
// of them is broadcast -- so the click travels here and the readout travels back.
if (!isServer) exitWith {};

params [["_pos", [0, 0, 0]], ["_caller", objNull]];
if (isNull _caller) exitWith {};

private _locations = missionNamespace getVariable ["civ_locations", []];
private _radii = missionNamespace getVariable ["civ_radii", []];
private _visible = missionNamespace getVariable ["civ_visible", []];

// An unrevealed town answers as empty ground. Anything else would make the map a free sweep
// for the towns the presence trigger exists to keep hidden until the player walks into one.
// A missing radius reads as 0 so an array that ever falls short of civ_locations misses rather
// than matching everything.
private _hit = -1;
{
	if ((_visible param [_forEachIndex, true])
		&& {(_pos distance2D (getPos _x)) < (_radii param [_forEachIndex, 0])}) exitWith {
		_hit = _forEachIndex;
	};
} forEach _locations;

if (_hit < 0) exitWith { [] remoteExec ["fnc_civ_townInfo", _caller]; };

private _name = text (_locations select _hit);
if (_name isEqualTo "") then { _name = format ["Unnamed%1", _hit] };
private _pop = missionNamespace getVariable [format ["civ_pop_%1", _hit], 0];

// Read straight out of the array rather than through fnc_civ_repAt, which falls back to the
// campaign-wide figure: printing that under a town's name would report a number the town does
// not have. RAVAGE and WBK register no town reputation at all, and the flag is what lets the
// readout say so instead of showing a fabricated 0.
private _reps = missionNamespace getVariable ["civ_town_rep", []];
private _hasRep = _hit < count _reps;
private _rep = if (_hasRep) then { _reps select _hit } else { 0 };
private _ap = (missionNamespace getVariable ["civ_town_ap", []]) param [_hit, 0];
([_rep, _ap] call fnc_civ_townIncome) params ["_income", "_side"];

[_name, _pop, _hasRep, _rep, _income, _side] remoteExec ["fnc_civ_townInfo", _caller];
