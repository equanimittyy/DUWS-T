// An ALiVE ORBAT Creator export keeps attachments, facewear and container contents only in
// ALiVE_orbatCreator_loadout, which the class's init handler applies after spawn; its config arrays name
// bare weapons and empty containers. Reading the key needs no ALiVE.
params ["_class"];
private _orbat = getArray (configFile >> "CfgVehicles" >> _class >> "ALiVE_orbatCreator_loadout");
if (_orbat isEqualTo []) then { getUnitLoadout _class } else { _orbat }
