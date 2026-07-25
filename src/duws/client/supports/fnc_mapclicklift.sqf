// Locality: client; the map-click body below runs on the machine that triggers it, not
// here (passed as an addAction function value in supports/fnc_helolift.sqf:424).
// fnc_mapclicklift.sqf - 地图点击选择三个航点，带实时图标反馈，标记保留至释放
// 由玩家动作触发，接收参数 [_target, _caller, _actionId, _arguments]

params ["_target", "_caller", "_actionId", "_arguments"];

// ========== 互斥锁检查：防止多个玩家同时使用地图点击 ==========
private _lockOwner = missionNamespace getVariable ["LIFT_MAPCLICK_OWNER", ""];
private _lockExpiry = missionNamespace getVariable ["LIFT_MAPCLICK_EXPIRY", 0];
private _myUID = getPlayerUID player;

// 如果锁已被其他玩家占用且未超时，则提示并退出
if (_lockOwner != "" && {_lockOwner != _myUID} && {diag_tickTime < _lockExpiry}) exitWith {
    titleText ["<t color='#ff0000' size='2'>Another player is already setting waypoints. Please wait.</t>", "PLAIN DOWN", -1, true, true];
};

// 否则，尝试占用锁（可能存在极小概率的竞态，但可接受）
missionNamespace setVariable ["LIFT_MAPCLICK_OWNER", _myUID];
missionNamespace setVariable ["LIFT_MAPCLICK_EXPIRY", diag_tickTime + 600]; // 10分钟超时

// ========== 私有化所有临时变量 ==========
private _timer = 3000;                     // 超时计数器（5分钟 = 3000 * 0.1秒）
private _waypoints = [];                   // 存储点击位置
private _markers = [];                      // 存储已创建的临时标记
private _clickPos = [];                      // 本次点击位置
private _safePos = [];                        // 安全位置检查结果
private _markerName = "";                     // 标记名称
private _marker = "";                          // 标记对象
private _color = "";                            // 标记颜色

// 初始化该玩家的变量（如果尚未存在）
if (isNil {player getVariable "LiftTakeOff"}) then {player setVariable ["LiftTakeOff", false]};
if (isNil {player getVariable "LiftWaypoints"}) then {player setVariable ["LiftWaypoints", []]};
if (isNil {player getVariable "LiftWaypointMarkers"}) then {player setVariable ["LiftWaypointMarkers", []]};

// 打开地图
openMap true;

while {_timer > 0 && count _waypoints < 3} do {
    // 确保地图始终打开（如果玩家关闭，立即重新打开）
    if (!visibleMap) then {
        openMap true;
    };

    // 重置并设置点击回调（使用玩家变量传递数据）
    onMapSingleClick "";
    onMapSingleClick "player setVariable ['LIFT_TMPPOS', _pos]; player setVariable ['LIFT_CLICKED', true];";

    // 等待点击，期间若地图被关闭则立即重新打开
    waitUntil {
        sleep 0.1;
        if (!visibleMap) then {
            openMap true;
        };
        player getVariable ["LIFT_CLICKED", false]
    };

    // 玩家已点击地图
    _clickPos = player getVariable ["LIFT_TMPPOS", []];
    player setVariable ["LIFT_TMPPOS", nil];
    player setVariable ["LIFT_CLICKED", false];

    // 检查点击位置是否有效（平坦且可到达）
    _safePos = [_clickPos, 0, 50, 5, 0, 0.2, 0, [], [_clickPos, _clickPos]] call BIS_fnc_findSafePos;
    if (_safePos isEqualTo [0,0]) then {
        // 无效位置，忽略并继续
    } else {
        // 有效位置，添加到航点列表
        _waypoints pushBack _safePos;

        // 创建临时地图图标（加入UID使名称更唯一）
        _markerName = format ["liftwp_%1_%2_%3", _myUID, floor random 10000, count _waypoints];
        _marker = createMarker [_markerName, _safePos];
        if ((count _waypoints) == 3) then {
            _marker setMarkerType "hd_flag";      // 终点用旗帜
        } else {
            _marker setMarkerType "hd_dot";       // 中间点用圆点
        };
        _color = ["ColorGreen", "ColorYellow", "ColorRed"] select ((count _waypoints) - 1);
        _marker setMarkerColor _color;
        _marker setMarkerText format ["Waypoint %1", count _waypoints];
        _markers pushBack _marker;
    };

    _timer = _timer - 1;
    sleep 1.0;
};

// 将选择的航点保存到玩家变量
player setVariable ["LiftWaypoints", _waypoints];

// 根据最终状态决定标记的清理
if (count _waypoints == 3) then {
    // 三个点已选完，将标记数组保存到玩家变量，由主脚本在释放后清理
    player setVariable ["LiftWaypointMarkers", _markers];
    titleText ["<t color='#00ff00' size='2'>Route set! Helicopter inbound.</t>", "PLAIN DOWN", -1, true, true];
} else {
    // 未完成选择（超时），立即删除标记
    { deleteMarker _x } forEach _markers;
    player setVariable ["LiftWaypointMarkers", []];
    titleText ["<t color='#ff0000' size='2'>Waypoint selection incomplete or timed out. Mission aborted.</t>", "PLAIN DOWN", -1, true, true];
};

// 标记完成，让主脚本继续
player setVariable ["LiftTakeOff", true];

// 关闭地图
openMap false;

// 清理回调及玩家变量
onMapSingleClick "";
player setVariable ["LIFT_CLICKED", nil];
player setVariable ["LIFT_TMPPOS", nil];

// ========== 释放互斥锁 ==========
missionNamespace setVariable ["LIFT_MAPCLICK_OWNER", nil];
missionNamespace setVariable ["LIFT_MAPCLICK_EXPIRY", nil];