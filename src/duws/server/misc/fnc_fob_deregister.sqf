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
Array_of_FOBS deleteAt _i;
Array_of_FOBname deleteAt _i;
Array_of_FOBpos deleteAt _i;
publicVariable "Array_of_FOBS";
publicVariable "Array_of_FOBname";
publicVariable "Array_of_FOBpos";
