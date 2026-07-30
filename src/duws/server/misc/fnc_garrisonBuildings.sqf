// Locality: server -- spawns OPFOR and attaches the intel handler, so only the server may run it.
//
// Puts a garrison in the enterable buildings around a point and returns the group holding it, or
// grpNull when there was nothing to garrison.
//
// The intel and loot passes are inside rather than left to the caller. Nine hand-copies of this
// routine drifted apart, and the one that lost them -- target_sniper -- quietly stopped paying the
// corpse intel every other mission paid, with nothing in the source to say that was deliberate. A
// caller cannot forget a step it does not perform.
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

// Walked rather than filtered, because a faction table that omits a role leaves its global
// undefined, and an undefined name inside an array literal is not something `select` can test for
// after the fact.
private _possibleUnitTypes = [];
{
    if (!isNil "_x" && {_x != ""}) then { _possibleUnitTypes pushBack _x };
} forEach [
    opfor_SOLDIER_X,
    opfor_AA_SOLDIER_X,
    opfor_AR_SOLDIER_X,
    opfor_AT_SOLDIER_X,
    opfor_LAT_SOLDIER_X,
    opfor_SL_SOLDIER_X
];
if (count _possibleUnitTypes == 0) then { _possibleUnitTypes = [opfor_SOLDIER_X] };

private _bldgUnits = [];
for "_i" from 1 to (_maxBuildingsToUse * _unitsPerBuilding) do {
    _bldgUnits pushBack (selectRandom _possibleUnitTypes);
};
private _buildingGroup = [[0,0], EAST, _bldgUnits, [], [], opfor_ai_skill] call BIS_fnc_spawnGroup;
_buildingGroup deleteGroupWhenEmpty true;

{
    if (_forEachIndex >= _maxBuildingsToUse) exitWith {};
    private _building = _x;
    private _positions = [_building] call BIS_fnc_buildingPositions;
    for "_j" from 0 to (_unitsPerBuilding - 1) do {
        private _unitIndex = _forEachIndex * _unitsPerBuilding + _j;
        if (_unitIndex >= count (units _buildingGroup)) exitWith {};
        private _unit = units _buildingGroup select _unitIndex;
        if (count _positions > 0) then {
            _unit setPosATL (_building buildingPos (floor (random (count _positions))));
            _unit setUnitPos "AUTO";
            _unit setBehaviour "AWARE";
            // Each garrison unit runs its own return-to-post loop for life. The alternative, one
            // monitor walking the group, has to re-derive which building each unit belongs to on
            // every pass; the building and its position list are captured here for free.
            [_unit, _building, _positions] spawn {
                params ["_unit", "_building", "_positions"];
                sleep 2 + random 5;
                private _buildingPos = getPosATL _building;
                while {alive _unit} do {
                    if (_unit distance _buildingPos > 15 && count _positions > 0) then {
                        _unit doMove (selectRandom _positions);
                    };
                    if (count _positions > 0) then {
                        private _targetPos = _building buildingPos (floor (random (count _positions)));
                        _unit doMove _targetPos;
                        _unit setUnitPos "AUTO";
                        private _timeout = time + 30;
                        waitUntil {
                            sleep 5;
                            (unitReady _unit) ||
                            (!alive _unit) ||
                            (_unit distance _targetPos < 2) ||
                            (time > _timeout)
                        };
                    };
                    sleep 5 + random 5;
                };
            };
        };
    };
} forEach _selectedBuildings;

[_buildingGroup] call fnc_add_intel_to_group;
{ [_x] call fnc_addRandomLoot } forEach units _buildingGroup;

_buildingGroup
