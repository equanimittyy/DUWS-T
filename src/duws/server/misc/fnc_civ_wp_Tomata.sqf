if (!isServer) exitWith {};
_bldgUnits = _this select 0;
_usableBuildings = _this select 1;

// 过滤掉无效建筑（确保每个元素都是有效的建筑物对象）
_usableBuildings = _usableBuildings select {!isNull _x && {_x isKindOf "Building"}};

// 如果没有有效建筑，则使用单位当前位置作为路点（避免崩溃）
if (count _usableBuildings == 0) exitWith {
    ["WARN", "CIV", "No valid buildings found, skipping waypoint assignment."] call fnc_log;
    // 可选：给所有组添加一个简单的巡逻路点
    {
        _wp = _x addWaypoint [getPos (leader _x), 100];
        _wp setWaypointType "CYCLE";
        _wp setWaypointSpeed "NORMAL";
        _wp setWaypointBehaviour "STEALTH";
    } forEach _bldgUnits;
};

{
    // 选择一个有效建筑
    private _building = selectRandom _usableBuildings;
    private _positions = [_building] call BIS_fnc_buildingPositions;
    // 如果建筑没有有效位置，跳过该组（但保留 CYCLE 路点）
    if (count _positions == 0) then {
        ["WARN", "CIV", format ["Building %1 has no positions, skipping waypoint for group.", _building]] call fnc_log;
        continue;
    };
    // 随机选择一个位置（排除最底层位置，确保在建筑内）
    private _randPosIndex = floor random count _positions;
    private _targetPos = _building buildingPos _randPosIndex;
    
    private _wp1 = _x addWaypoint [_targetPos, 2];
    _wp1 setWaypointType "MOVE";
    _wp1 setWaypointSpeed "NORMAL";
    _wp1 setWaypointBehaviour "STEALTH";
    _wp1 setWaypointCombatMode "GREEN";
    _wp1 setWaypointTimeout [60, 90, 120];
    _wp1 setWaypointCompletionRadius 15;
} forEach _bldgUnits;

// 添加第二个路点（同样逻辑）
{
    private _building = selectRandom _usableBuildings;
    private _positions = [_building] call BIS_fnc_buildingPositions;
    if (count _positions == 0) then {
        ["WARN", "CIV", format ["Building %1 has no positions, skipping second waypoint.", _building]] call fnc_log;
        continue;
    };
    private _randPosIndex = floor random count _positions;
    private _targetPos = _building buildingPos _randPosIndex;
    
    private _wp2 = _x addWaypoint [_targetPos, 2];
    _wp2 setWaypointType "MOVE";
    _wp2 setWaypointSpeed "NORMAL";
    _wp2 setWaypointBehaviour "STEALTH";
    _wp2 setWaypointCombatMode "GREEN";
    _wp2 setWaypointTimeout [60, 90, 120];
    _wp2 setWaypointCompletionRadius 15;
} forEach _bldgUnits;

// 添加循环路点（确保所有组至少有一个有效的循环点）
{
    private _wp3 = _x addWaypoint [getpos leader _x, 2];
    _wp3 setWaypointType "CYCLE";
    _wp3 setWaypointSpeed "NORMAL";
    _wp3 setWaypointBehaviour "STEALTH";
    _wp3 setWaypointCombatMode "GREEN";
    _wp3 setWaypointCompletionRadius 15;
} forEach _bldgUnits;