// Locality: server -- the laptop thread calls it directly.
//
// Picks the building the laptop mission builds inside, and the interior slot the laptop sits on. From the
// usable buildings near the vetted anchor it prefers a taller one (more floors), then returns a second-floor
// slot if the chosen building has one, else a ground-floor slot. The offer's site-finder already proved a
// usable building is in reach, so this does not fail on a live offer; [] only if the buildings vanished in
// the gap between offer and launch.
//
// A building's floors are its interior positions bucketed by height above its lowest one (buildingPos z is
// height above the building base). Two-or-more occupied bands == multi-storey. No class whitelist, so it
// holds for any building on any map or faction mod.
//
// Contract: [_pos, _radius] -> [_building, _interiorPos] | [].
params ["_pos", "_radius"];

#define FLOOR_H 2.5   // metres between interior height bands; a gap this wide reads as a new floor

private _cands = [_pos, 2, _radius] call fnc_usableBuildings;
if (_cands isEqualTo []) exitWith { [] };

// Occupied floors of a building, low to high: each entry the list of interior positions on that floor.
// Empty bands (a height gap with no slot) are dropped, so index 1 is always a real second storey.
private _fnFloors = {
    params ["_bldg"];
    private _all = [_bldg] call BIS_fnc_buildingPositions;
    if (_all isEqualTo []) exitWith { [] };
    private _baseZ = selectMin (_all apply { _x select 2 });
    private _byFloor = [];
    {
        private _f = floor (((_x select 2) - _baseZ) / FLOOR_H);
        while { count _byFloor <= _f } do { _byFloor pushBack [] };
        (_byFloor select _f) pushBack _x;
    } forEach _all;
    _byFloor select { count _x > 0 }
};

// Prefer more floors; a little noise so ties do not always land on the same structure.
private _best = objNull;
private _bestFloors = [];
private _bestScore = -1;
{
    private _floors = [_x] call _fnFloors;
    if !(_floors isEqualTo []) then {
        private _score = (count _floors) + (random 0.5);
        if (_score > _bestScore) then { _bestScore = _score; _best = _x; _bestFloors = _floors };
    };
} forEach _cands;
if (isNull _best) exitWith { [] };

// Second storey if there is one, else ground. Within that floor, the slot with the fewest objects packed
// around it -- most room for the desk, least chance the laptop clips furniture or a wall.
private _floorIdx = if ((count _bestFloors) >= 2) then { 1 } else { 0 };
private _slots = _bestFloors select _floorIdx;
private _slot = _slots select 0;
private _clearest = 1e9;
{
    private _n = count (nearestObjects [_x, [], 1.2]);
    if (_n < _clearest) then { _clearest = _n; _slot = _x };
} forEach _slots;

[_best, _slot]
