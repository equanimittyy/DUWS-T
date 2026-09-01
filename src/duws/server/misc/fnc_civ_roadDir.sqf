// Locality: any -- pure geometry over the road network, no engine spawn. Faces a car the way its stretch
// of road runs, taken from the nearest connected node; falls back to the segment's own heading at a
// dead-end with nothing connected. Shared by fnc_civ_traffic and the random-event cars.
params ["_road"];
private _cons = roadsConnectedTo _road;
if (_cons isEqualTo []) exitWith { getDir _road };
[getPosATL _road, getPosATL (_cons select 0)] call BIS_fnc_dirTo
