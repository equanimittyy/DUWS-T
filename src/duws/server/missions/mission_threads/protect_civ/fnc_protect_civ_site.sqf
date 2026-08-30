// Site-finder for Protect Informant (surveyKind "map"): snaps the offer onto a real building near the
// candidate and returns its position, so the objective centres on it. Qualifies only with a real interior
// (>= 4 building positions). Client-side in the picker. Contract: [_pos] -> [] | [_buildingPos].
params ["_pos"];

#define ACCEPT_RADIUS 60

private _cands = [nearestTerrainObjects [_pos, ["HOUSE", "BUILDING"], ACCEPT_RADIUS, false], [], { _pos distance2D _x }, "ASCEND"] call BIS_fnc_sortBy;
private _building = objNull;
{ if (count (_x buildingPos -1) >= 4) exitWith { _building = _x } } forEach _cands;

if (isNull _building) exitWith { [] };
[getPosATL _building]
