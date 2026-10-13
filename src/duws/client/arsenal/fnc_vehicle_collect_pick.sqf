// Locality: client. The vehicle this player's Collect into vehicle targets, or objNull. The hold action's
// show and progress conditions and its completion all call it, so the three resolve the same vehicle.
params ["_who"];
private _v = cursorObject;
if (vehicle _who != _who || {!alive _v} || {_v distance _who > 8}) exitWith { objNull };
if !(_v isKindOf "LandVehicle" || {_v isKindOf "Air"} || {_v isKindOf "Ship"}) exitWith { objNull };
if (getNumber (configFile >> "CfgVehicles" >> typeOf _v >> "maximumLoad") <= 0) exitWith { objNull };
_v
