// Locality: server -- called by server/misc/fnc_debug_force_mission.sqf.

// Where a forced side mission is anchored. Same rule the strategic map's picker applies to the
// missions it offers (client/missions/fnc_stratmap.sqf): sample a named map location, then refuse
// any that lands on ground a zone or a town already owns. It used to hold a flat 600 m off zone
// centres, which is inside most zones and knows nothing about towns, so a forced mission could be
// built on top of the thing it was meant to be tested away from.
//
// The 400 m margin is the picker's, and for the same reason: the objective drifts from this anchor
// before fnc_missionTargetPos settles it, so an anchor a metre outside a town hands that loop fifty
// rejections and an abort.
params [
    ["_minDistFromHQ", 600],
    ["_maxAttempts", 50]
];

private _hqPos = missionNamespace getVariable ["PosOfBLUHQ", [0,0,0]];
private _missionLocations = missionNamespace getVariable ["MissionLocations", []];

// 如果没有地点池，使用地图城镇位置
if (_missionLocations isEqualTo []) then {
    _missionLocations = nearestLocations [getArray (configFile >> "CfgWorlds" >> worldName >> "centerPosition"), ["NameCity","NameVillage","NameCityCapital"], worldSize];
};

private _foundPos = [];
private _attempts = 0;

while {_attempts < _maxAttempts && _foundPos isEqualTo []} do {
    _attempts = _attempts + 1;
    private _candidatePos = getPos (selectRandom _missionLocations);

    if (_candidatePos distance _hqPos < _minDistFromHQ) then { continue };
    if ([_candidatePos, 400] call fnc_pos_claimed) then { continue };

    private _safePos = [_candidatePos, 0, 50, 5, 0, 0.2, 0, [], [_candidatePos, _candidatePos]] call BIS_fnc_findSafePos;
    // Re-tested after the safe-position search, which moves the point up to 50 m and can walk it
    // back over a boundary this loop just cleared.
    if !(_safePos isEqualTo [0,0,0] || {[_safePos, 400] call fnc_pos_claimed}) then {
        _foundPos = _safePos;
    };
};

_foundPos
