// Locality: server -- spawns OPFOR and attaches the intel handler, so only the server may run it.
//
// Puts a garrison in the enterable buildings around a point and returns the group holding it, or
// grpNull when there was nothing to garrison.
//
// The intel and loot passes are inside rather than left to the caller. Nine hand-copies of this
// routine drifted apart, and the one that lost them -- target_sniper -- quietly stopped paying the
// corpse intel every other mission paid, with nothing in the source to say that was deliberate. A
// caller cannot forget a step it does not perform.
//
// Shared by side missions and by a zone's own dug-in half, which wants different answers to three
// questions: five usable building positions rather than two, men stood UP rather than AUTO, and the
// buildings nearest the centre rather than a random spread, so a zone is held from its middle.
// Those are the parameters below rather than a second copy of this routine.
// clearthearea_cqb stays out, because its house-cleared announcements need the per-building unit
// lists this does not return.
//
// _strength thins the number of buildings held and never the men inside one: three to a house is
// what makes clearing one cost something, and a house with a single man in it is a house the player
// walks through. Never empties: a garrison at its floor still holds one building.
params ["_pos", "_radius", ["_desiredBldgCount", 6], ["_unitsPerBuilding", 4],
        ["_positionsNeeded", 2], ["_stance", "AUTO"], ["_nearestFirst", false], ["_strength", 1]];

private _usableBuildings = [_pos, _positionsNeeded, _radius] call fnc_usableBuildings;
private _actualBldgCount = count _usableBuildings;
if (_actualBldgCount == 0) exitWith { grpNull };

private _maxBuildingsToUse = ((ceil (_strength * (_actualBldgCount min _desiredBldgCount))) max 1);
private _selectedBuildings = [];
if (_nearestFirst) then {
    // fnc_usableBuildings returns them sorted by distance, so a slice is the nearest N.
    _selectedBuildings = _usableBuildings select [0, _maxBuildingsToUse];
} else {
    if (_actualBldgCount == _maxBuildingsToUse) then {
        _selectedBuildings = _usableBuildings;
    } else {
        private _tempArray = +_usableBuildings;
        for "_i" from 1 to _maxBuildingsToUse do {
            private _index = floor (random (count _tempArray));
            _selectedBuildings pushBack (_tempArray select _index);
            _tempArray deleteAt _index;
        };
    };
};
_maxBuildingsToUse = count _selectedBuildings;

private _possibleUnitTypes = [[
    opfor_SOLDIER_X,
    opfor_AA_SOLDIER_X,
    opfor_AR_SOLDIER_X,
    opfor_AT_SOLDIER_X,
    opfor_LAT_SOLDIER_X,
    opfor_SL_SOLDIER_X
]] call fnc_opforRoles;

private _bldgUnits = [];
for "_i" from 1 to (_maxBuildingsToUse * _unitsPerBuilding) do {
    _bldgUnits pushBack (selectRandom _possibleUnitTypes);
};
private _buildingGroup = [[0,0], EAST, _bldgUnits, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
_buildingGroup deleteGroupWhenEmpty true;

[_buildingGroup, _selectedBuildings, _unitsPerBuilding, _stance] call fnc_spreadIntoBuildings;

[_buildingGroup, "garrison"] call fnc_search_flag_group;
{ [_x] call fnc_addRandomLoot } forEach units _buildingGroup;

_buildingGroup
