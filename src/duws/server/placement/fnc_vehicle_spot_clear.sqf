// Locality: any (a pure placement query); every caller is server-side.
//
// A vehicle spawned into another detonates the one already placed (an allowDamage false settle guards only the
// newcomer), so no vehicle, wreck included, may stand within VEH_GAP.
//
// [_class, _pos, _dir] -> true when the class fits at _pos facing _dir
params ["_class", "_pos", "_dir"];

#define VEH_GAP 20

if ((nearestObjects [_pos, ["LandVehicle", "Air", "Ship"], VEH_GAP]) isNotEqualTo []) exitWith { false };
[_class, _pos, _dir] call fnc_footprint_clear
