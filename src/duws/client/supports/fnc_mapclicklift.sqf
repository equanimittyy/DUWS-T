// Locality: client; the map-click body below runs on the machine that triggers it, not
// here (passed as an addAction function value in client/supports/fnc_helolift.sqf:427).
// fnc_mapclicklift.sqf - 地图点击选择三个航点，带实时图标反馈，标记保留至释放
// 由玩家动作触发，接收参数 [_target, _caller, _actionId, _arguments]

params ["_target", "_caller", "_actionId", "_arguments"];

// The map-click slot is the thing actually being contended, so this takes the shared claim
// rather than the private lock it used to keep here. That lock was per-machine despite being
// written as a player mutex (the owner was never broadcast) and its timeout was measured with
// diag_tickTime, which a savegame does not restore -- a campaign loaded after the stamp was
// taken saw the lock as either permanently held or permanently free.
private _liftClickHandler = "player setVariable ['LIFT_TMPPOS', _pos]; player setVariable ['LIFT_CLICKED', true];";
if (!(["LIFT", _liftClickHandler] call fnc_mapclick_claim)) exitWith {};

// ========== 私有化所有临时变量 ==========
private _timer = 3000;                     // 超时计数器（5分钟 = 3000 * 0.1秒）
private _waypoints = [];                   // 存储点击位置
private _markers = [];                      // 存储已创建的临时标记
private _clickPos = [];                      // 本次点击位置
private _safePos = [];                        // 安全位置检查结果
private _markerName = "";                     // 标记名称
private _marker = "";                          // 标记对象

// 初始化该玩家的变量（如果尚未存在）
if (isNil {player getVariable "LiftTakeOff"}) then {player setVariable ["LiftTakeOff", false]};
if (isNil {player getVariable "LiftWaypoints"}) then {player setVariable ["LiftWaypoints", []]};
if (isNil {player getVariable "LiftWaypointMarkers"}) then {player setVariable ["LiftWaypointMarkers", []]};

// 打开地图
openMap true;
// Drawn on the map rather than hinted: the map is force-open for this whole routine, and
// the hint box renders beneath it.
[localize "STR_DUWS_T_liftwp_brief"] call fnc_map_prompt;

while {_timer > 0 && count _waypoints < 3} do {
    // 确保地图始终打开（如果玩家关闭，立即重新打开）
    if (!visibleMap) then {
        openMap true;
    };

    // 重置并设置点击回调（使用玩家变量传递数据）
    // Re-claiming as the current holder, which the slot allows: each waypoint reinstalls the
    // same handler.
    ["LIFT", _liftClickHandler] call fnc_mapclick_claim;

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

        // Same marker convention as the helo taxi: yellow objective icons for the route
        // legs, a green end icon for the destination. The two supports draw on the same
        // map and a player should not have to learn two symbol sets.
        _markerName = format ["liftwp_%1_%2_%3", _myUID, floor random 10000, count _waypoints];
        _marker = createMarker [_markerName, _safePos];
        if ((count _waypoints) == 3) then {
            _marker setMarkerType "hd_end";
            _marker setMarkerColor "ColorGreen";
            _marker setMarkerText localize "STR_DUWS_T_liftwp_drop";
        } else {
            _marker setMarkerType "hd_objective";
            _marker setMarkerColor "ColorYellow";
            _marker setMarkerText format ["LiftWP%1", count _waypoints];
        };
        _markers pushBack _marker;

        // Per-leg confirmation, as the taxi picker gives.
        if ((count _waypoints) < 3) then {
            [localize ([
                "STR_DUWS_T_liftwp1marked", "STR_DUWS_T_liftwp2marked"
            ] select ((count _waypoints) - 1))] call fnc_map_prompt;
        };
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
} else {
    // 未完成选择（超时），立即删除标记
    { deleteMarker _x } forEach _markers;
    player setVariable ["LiftWaypointMarkers", []];
};

// 标记完成，让主脚本继续
player setVariable ["LiftTakeOff", true];

// 关闭地图
openMap false;

// Verdict after the map is out of the way, not before: titleText is drawn on a layer the map
// covers, so both of these used to fire into a screen the player could not see.
if (count _waypoints == 3) then {
    titleText [format ["<t color='#00ff00' size='2'>%1</t>", localize "STR_DUWS_T_liftwp_set"], "PLAIN DOWN", -1, true, true];
} else {
    titleText [format ["<t color='#ff0000' size='2'>%1</t>", localize "STR_DUWS_T_liftwp_abort"], "PLAIN DOWN", -1, true, true];
};

// 清理回调及玩家变量
["LIFT"] call fnc_mapclick_release;
player setVariable ["LIFT_CLICKED", nil];
player setVariable ["LIFT_TMPPOS", nil];