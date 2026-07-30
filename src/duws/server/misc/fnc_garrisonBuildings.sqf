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
// Side missions only. fnc_createopfortified garrisons a zone the same way by eye but not in fact:
// it wants five usable building positions rather than two, stands its units UP rather than AUTO,
// and walks every usable building instead of a random subset. Folding it in costs three parameters
// that no other caller sets. clearthearea_cqb is likewise out, because its house-cleared
// announcements need the per-building unit lists this does not return.
params ["_pos", "_radius", ["_desiredBldgCount", 6], ["_unitsPerBuilding", 4]];

private _usableBuildings = [_pos, 2, _radius] call fnc_usableBuildings;
private _actualBldgCount = count _usableBuildings;
if (_actualBldgCount == 0) exitWith { grpNull };

private _maxBuildingsToUse = _actualBldgCount min _desiredBldgCount;
private _selectedBuildings = [];
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

[_buildingGroup, _selectedBuildings, _unitsPerBuilding, "AUTO"] call fnc_spreadIntoBuildings;

[_buildingGroup, "garrison"] call fnc_search_flag_group;
{ [_x] call fnc_addRandomLoot } forEach units _buildingGroup;

_buildingGroup
