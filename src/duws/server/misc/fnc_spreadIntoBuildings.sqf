// Locality: server -- setPosATL and the hold loops it starts need the units local.
//
// Spreads an already-spawned group across a list of buildings, _unitsPerBuilding to each, and
// starts every placed unit holding its post. Returns the per-building unit lists, which
// clearthearea_cqb's house-cleared announcements are built on; the other callers discard it.
//
// The group and the building list stay the caller's to build: the three callers pick their
// classes and their buildings on different rules. What they share is the index arithmetic
// below, where a copied off-by-one puts one building's last unit inside its neighbour.
//
// Buildings past the group's supply still return an entry, an empty one, so a caller indexing
// its own building array against the result stays aligned with it.
//
// _stance "" leaves each unit's stance untouched, for a caller that assigns its own per-unit mix.
//
// Each placed unit then holds via fnc_holdBuildingPost -- a doMove loop between its building's
// positions that leaves pathing on, so the unit works the building and fights rather than freezing.
params ["_group", "_buildings", ["_unitsPerBuilding", 4], ["_stance", "AUTO"]];

// One lookup rather than one per unit: `units` walks the group on every call, and nothing below
// suspends, so the list cannot change while the placement runs.
private _units = units _group;
private _perBuilding = [];

{
    private _building = _x;
    private _positions = [_building] call BIS_fnc_buildingPositions;
    private _buildingUnits = [];

    for "_j" from 0 to (_unitsPerBuilding - 1) do {
        private _unitIndex = _forEachIndex * _unitsPerBuilding + _j;
        if (_unitIndex >= count _units) exitWith {};
        private _unit = _units select _unitIndex;

        // Recorded before the placement guard: a caller counting a building's occupants wants
        // the units assigned to it, not only the ones a position was found for.
        _buildingUnits pushBack _unit;

        if !(_positions isEqualTo []) then {
            private _slot = _building buildingPos (floor (random (count _positions)));
            _unit setPosATL _slot;
            // Guarded so "" means one thing: setUnitPos "" is not a stance, and silently leaves the
            // unit however it spawned.
            if (_stance != "") then { _unit setUnitPos _stance };
            // Behaviour is the caller's. Forcing AWARE here overrode whatever the caller had just
            // set on the group, which is how every garrison ended up alert before anything had
            // happened to alert it.
            [_unit, _building, _positions, _stance] spawn fnc_holdBuildingPost;
        };
    };

    _perBuilding pushBack _buildingUnits;
} forEach _buildings;

_perBuilding
