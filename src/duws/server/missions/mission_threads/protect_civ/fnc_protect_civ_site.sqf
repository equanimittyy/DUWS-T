// Site-finder for Protect Informant (surveyKind "map"). Snaps the offer onto a real building near the
// candidate and returns its exact position, so the informant, crate and hold ring all centre on it.
// A building qualifies only with a real interior (>= 4 building positions), skipping sheds and doorways.
// Runs client-side in the offer picker, so terrain queries only. Contract: [_pos] -> [] | [_buildingPos].
params ["_pos"];

#define ACCEPT_RADIUS 60

private _cands = [nearestTerrainObjects [_pos, ["HOUSE", "BUILDING"], ACCEPT_RADIUS, false], [], { _pos distance2D _x }, "ASCEND"] call BIS_fnc_sortBy;
private _building = objNull;
{ if (count (_x buildingPositions -1) >= 4) exitWith { _building = _x } } forEach _cands;

if (isNull _building) exitWith { [] };
[getPosATL _building]
