// Site-finder for Protect Informant (surveyKind "map"): the offer arrives as an open-ground dot, so a tight
// accept ring rarely catches a building -- this snaps to the nearest building cluster (village or hamlet, never
// a registered town) and returns a real 4-slot building's position. Client-side in the picker, so it reads only
// broadcast state. The thread re-derives the same building within 30 m, so a building position is what it needs.
//
// Contract: [_pos] -> [] | [_buildingPos].
params ["_pos"];

#define SNAP_RADIUS   1500
#define ACCEPT_RADIUS 350

private _circles = missionNamespace getVariable ["duws_town_circles", []];

// nearestLocations is nearest-first; the isNull guard keeps the nearest qualifying cluster.
private _locs = nearestLocations [_pos, ["NameCityCapital", "NameCity", "NameVillage", "NameLocal"], SNAP_RADIUS];
private _building = objNull;
{
    if (isNull _building) then {
        private _c = locationPosition _x;
        // No towns: skip a settlement inside any registered town circle (hamlets pass).
        if ((_circles findIf { _x params ["_tc", "_r"]; _c distance2D _tc < _r }) < 0) then {
            private _houses = [nearestTerrainObjects [_c, ["HOUSE", "BUILDING"], ACCEPT_RADIUS, false], [], { _c distance2D _x }, "ASCEND"] call BIS_fnc_sortBy;
            private _i = _houses findIf { count (_x buildingPos -1) >= 4 };
            if (_i >= 0) then { _building = _houses select _i };
        };
    };
} forEach _locs;

if (isNull _building) exitWith { [] };
[getPosATL _building]
