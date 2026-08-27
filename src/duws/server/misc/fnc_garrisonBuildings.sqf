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
// A side mission's guard ring, and only that. A zone and a town garrison hold buildings through the
// "garrison" posture instead -- one squad to one structure, drawn from an ordinary team roster --
// which is what a composition can name and vary; this raises its own men by a rule and cannot be
// asked for anything else. The zone parameters that used to sit here (nearest-first, men stood UP,
// five positions rather than two, an attrition fraction) went with that caller.
params ["_pos", "_radius", ["_desiredBldgCount", 6], ["_unitsPerBuilding", 4]];

// Two positions, so a hut with a doorway counts: a side mission wants its objective ringed rather
// than held from the best windows on the street.
private _usableBuildings = [_pos, 2, _radius] call fnc_usableBuildings;
private _actualBldgCount = count _usableBuildings;
if (_actualBldgCount == 0) exitWith { grpNull };

private _maxBuildingsToUse = (_actualBldgCount min _desiredBldgCount) max 1;
private _selectedBuildings = _usableBuildings;
if (_actualBldgCount != _maxBuildingsToUse) then {
    _selectedBuildings = [];
    private _tempArray = +_usableBuildings;
    for "_i" from 1 to _maxBuildingsToUse do {
        private _index = floor (random (count _tempArray));
        _selectedBuildings pushBack (_tempArray select _index);
        _tempArray deleteAt _index;
    };
};
_maxBuildingsToUse = count _selectedBuildings;

private _possibleUnitTypes = [([
    "opfor_SOLDIER_X", "opfor_AA_SOLDIER_X", "opfor_AR_SOLDIER_X",
    "opfor_AT_SOLDIER_X", "opfor_LAT_SOLDIER_X", "opfor_SL_SOLDIER_X"
] apply { [_x] call fnc_faction_pick }), "opfor"] call fnc_factionRoles;

private _bldgUnits = [];
for "_i" from 1 to (_maxBuildingsToUse * _unitsPerBuilding) do {
    _bldgUnits pushBack (selectRandom _possibleUnitTypes);
};
private _buildingGroup = [[0,0], EAST, _bldgUnits, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
_buildingGroup deleteGroupWhenEmpty true;

[_buildingGroup, _selectedBuildings, _unitsPerBuilding, "AUTO"] call fnc_spreadIntoBuildings;

{ [_x] call fnc_addRandomLoot } forEach units _buildingGroup;

_buildingGroup
