// Drops one FOB from the three index-parallel FOB registries in lockstep: deleting from each in
// its own forEach would skip elements and let the registries disagree about which FOB sits at an
// index. Matched by nearest-within-tolerance, not equality -- the removal dialog reads a position
// back off the building while the destruction watcher captured one at build time, and the two agree
// only to within float noise. 5 m cannot reach a second FOB -- the building alone is wider than that.
if (!isServer) exitWith {};
params [["_fobPos", []]];
if (_fobPos isEqualTo []) exitWith {};
private _i = Array_of_FOBpos findIf { (_x distance2D _fobPos) < 5 };
if (_i < 0) exitWith {
	["WARN", "SUPPORT", format ["fnc_fob_deregister: no FOB registered at %1", _fobPos]] call fnc_log;
};
// The site record goes with the registries, and it has to go from here: both removal paths -- the
// player's dialog and the destruction watcher -- funnel through this one function, and nothing else
// knows a FOB has stopped existing. Left behind, the record polls the ground the base used to stand
// on for the rest of the campaign, and a frozen site pays a spatial query for that answer.
// Read off the building before the index entry goes, since the key is where fnc_fob_server filed it.
private _siteKey = (Array_of_FOBS select _i) getVariable ["DUWS_siteKey", ""];
// Garrison deleted by roster before retire (which only untracks); with no TF to gather them the men
// would otherwise idle where the base stood. By roster, never proximity -- a sweep takes a neighbour's men.
if (_siteKey != "") then {
	[_siteKey, "infantry"] call fnc_site_collect;
	[_siteKey] call fnc_site_retire;
	{ [_x] call DUWS_fnc_buildCrewClear } forEach ((DUWS_compositions getOrDefault [format ["%1_builds", _siteKey], []]) select { !isNull _x });
	[format ["%1_builds", _siteKey]] call fnc_duws_release;
};
remoteExec ["", format ["DUWS_siteBuild_%1", netId (Array_of_FOBS select _i)]];

Array_of_FOBS deleteAt _i;
Array_of_FOBname deleteAt _i;
Array_of_FOBpos deleteAt _i;
publicVariable "Array_of_FOBS";
publicVariable "Array_of_FOBname";
publicVariable "Array_of_FOBpos";
