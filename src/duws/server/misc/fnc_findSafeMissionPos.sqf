// Locality: server -- called by server/misc/fnc_debug_force_mission.sqf.

params [
    ["_minDistFromZones", 600],
    ["_minDistFromHQ", 600],
    ["_maxAttempts", 50]
];

// 获取所有战区位置
private _allZones = [];
{
    _allZones append (missionNamespace getVariable [_x, []]);
} forEach ["WARCOM_zones_controled_by_BLUFOR", "WARCOM_zones_controled_by_OPFOR"];

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
    private _candidateLocation = selectRandom _missionLocations;
    private _candidatePos = getPos _candidateLocation;

    // 检查距离 HQ
    if (_candidatePos distance _hqPos < _minDistFromHQ) then { continue };

    // 检查距离所有战区
    private _tooClose = false;
    {
        if (_candidatePos distance _x < _minDistFromZones) exitWith { _tooClose = true };
    } forEach _allZones;

    if (!_tooClose) then {
        // 确保位置安全
        private _safePos = [_candidatePos, 0, 50, 5, 0, 0.2, 0, [], [_candidatePos, _candidatePos]] call BIS_fnc_findSafePos;
        if !(_safePos isEqualTo [0,0,0]) then {
            _foundPos = _safePos;
        };
    };
};

// 回退：地图中心附近随机安全位置
if (_foundPos isEqualTo []) then {
    _foundPos = [getArray (configFile >> "CfgWorlds" >> worldName >> "centerPosition"), 0, worldSize / 2, 5, 0, 0.2, 0] call BIS_fnc_findSafePos;
};

_foundPos