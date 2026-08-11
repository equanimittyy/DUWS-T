// Drops one FOB from the three index-parallel FOB registries at once. Removal used to run as
// two independent forEach passes matching on different keys -- the building by a stringified
// position, the name by string equality -- each deleting from the array it was iterating.
// Deleting during forEach skips the next element, and two key types can disagree about which
// FOB they matched, so the registries could end up describing different FOBs at the same index.
// Nearest-within-tolerance rather than equality: the removal dialog reports a position it read
// back off the building, the destruction watcher reports one captured at build time, and those
// agree to within float noise rather than exactly. 5 m cannot reach a second FOB -- the building
// alone is wider than that.
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
// would otherwise idle where the base stood. By roster, never proximity -- a sweep takes a neighbour's
// men. Both player removal and enemy-destruction funnel through here.
if (_siteKey != "") then { [_siteKey, "infantry"] call fnc_site_collect; [_siteKey] call fnc_site_retire };

Array_of_FOBS deleteAt _i;
Array_of_FOBname deleteAt _i;
Array_of_FOBpos deleteAt _i;
publicVariable "Array_of_FOBS";
publicVariable "Array_of_FOBname";
publicVariable "Array_of_FOBpos";
