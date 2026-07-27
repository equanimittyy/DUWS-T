// Locality: client -- invoked from the comm menu (shared/includes/supports_radio_modern.hpp:167).
// The addAction body below runs on whoever triggers it.
// This file drives the lift but owns none of the aircraft. The helo is created and kept
// server-side by server/supports/fnc_helolift_spawnHeli.sqf, because waypoint and
// flight-height commands are only honoured where the group is local; issuing them here
// worked for a hosting player and silently did nothing for everyone else. So every helo or
// group command goes out via fnc_helolift_waypoints / fnc_helolift_ropes on target 2, and
// what stays local is exactly what is local by nature: cursorObject, hints, map markers,
// the player's own addAction, and the geometry maths that only reads positions.

// ==================== 客户端执行部分 ====================

// ========== 1. 目标检查与初始化 ==========
_target = cursorObject;
if (isNull _target) exitWith {
    hint localize "STR_DUWS_T_helolift_notarget";
    sleep 10;
    [player, "helo_lift"] call BIS_fnc_addCommMenuItem;
};
if !(_target isKindOf "Car" || _target isKindOf "Tank" || _target isKindOf "Helicopter" || _target isKindOf "Plane") exitWith {
    hint localize "STR_DUWS_T_helolift_badtarget";
    sleep 10;
    [player, "helo_lift"] call BIS_fnc_addCommMenuItem;
};

// 玩家唯一标识
_playerUID = getPlayerUID player;
_varPrefix = format ["LiftTask_%1", _playerUID];

// 初始化玩家变量（用于地图点击脚本）
player setVariable ["LiftTakeOff", false];
player setVariable ["LiftWaypoints", []];
player setVariable ["LiftWaypointMarkers", []];

// ========== 2. 生成直升机（必须由服务器执行）==========
missionNamespace setVariable [_varPrefix + "_heloReady", false];
[player, _target] remoteExec ["fnc_helolift_spawnHeli", 2];

// Bail rather than hang: a lost request would otherwise wedge this thread forever and the
// comm-menu entry never comes back.
_spawnDeadline = diag_tickTime + 30;
waitUntil {
    sleep 0.5;
    (missionNamespace getVariable [_varPrefix + "_heloReady", false]) or (diag_tickTime > _spawnDeadline)
};
_helo = missionNamespace getVariable [_varPrefix + "_helo", objNull];
_heloGroup = missionNamespace getVariable [_varPrefix + "_heloGroup", grpNull];
if (isNull _helo) exitWith {
    hint localize "STR_DUWS_T_helolift_noheli";
    sleep 10;
    [player, "helo_lift"] call BIS_fnc_addCommMenuItem;
};
_pilot = currentPilot _helo;

// ========== 3. 保存目标引用 ==========
_targetVehicle = _target;
_originalMass = getMass _targetVehicle;

// Single teardown for every failure below, replacing nine near-identical copies. The
// server owns the aircraft, so the rope/mass/landing cleanup is its call -- this half only
// clears the player's own map markers and hands the support back.
_abort = {
    private _markers = player getVariable ["LiftWaypointMarkers", []];
    { deleteMarker _x } forEach _markers;
    player setVariable ["LiftWaypointMarkers", []];
    [localize "STR_DUWS_T_OVERLORD", ([localize "STR_DUWS_T_heloliftabort"] call fnc_cs)] remoteExec ["fnc_duws_dialogue", 0];
    [player, "abort", [_helo, _targetVehicle, _originalMass, _heloGroup]] remoteExec ["fnc_helolift_ropes", 2];
    sleep 300;
    [player, "helo_lift"] call BIS_fnc_addCommMenuItem;
};


// ========== 添加直升机损坏检测 ==========
_helo_maxDamage = 0.7;
_helo_minFuel = 0.4;
_check_damage = compile format ["(isNull _helo) or (damage _helo > %1) or (fuel _helo < %2) or (vehicle _pilot == _pilot)", _helo_maxDamage, _helo_minFuel];

// ========== 4. 通知并飞往载具位置 ==========
_speaker = localize "STR_DUWS_T_actionteam";
_message = format[([localize "STR_DUWS_T_heloliftcall"] call fnc_cs)];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

// 创建临时吊装点标记
_hookMarkerName = format ["hook_%1", floor random 10000];
createMarker [_hookMarkerName, getPos _target];
_hookMarkerName setMarkerType "hd_dot";
_hookMarkerName setMarkerColor "ColorBlue";
_hookMarkerName setMarkerText "HOOK POINT";

// ========== 5. 飞抵目标上空并执行挂钩 ==========
[player, "clear", []] remoteExec ["fnc_helolift_waypoints", 2];

// 远程调用服务器设置初始航点
_moveCompletedVar = _varPrefix + "_moveCompleted";
missionNamespace setVariable [_moveCompletedVar, false]; // 初始化（客户端本地）
[player, "setInitial", [_targetVehicle]] remoteExec ["fnc_helolift_waypoints", 2];

sleep 8;
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = format[localize "STR_DUWS_T_helolift1"];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
_speaker = localize "STR_DUWS_T_crane";
_message = format[localize "STR_DUWS_T_helolift2"];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
waitUntil {
    sleep 1.5;
    (missionNamespace getVariable [_moveCompletedVar, false]) or (call _check_damage)
};
if (call _check_damage) exitWith { call _abort };

[player, "height", [10]] remoteExec ["fnc_helolift_waypoints", 2];
deleteMarker _hookMarkerName;
_speaker = localize "STR_DUWS_T_crane";
_message = format[localize "STR_DUWS_T_helolift3"];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
if (call _check_damage) exitWith { call _abort };

// ========== 定义直升机连接点 ==========
private _heliPoints = [
    [ 1.4,  2.8, -2],   // 前右
    [ 1.4, -2.8, -2],   // 前左
    [-1.4,  2.8, -2],   // 后右
    [-1.4, -2.8, -2],   // 后左
    [0, -7, -1]         // 后方中间
];

// ========== 获取车辆重心并定义车辆连接点 ==========
private _com = getCenterOfMass _targetVehicle;
private _frontRadius = 2.5;
private _rearRadius = _frontRadius;
private _heightOffset = 0.3;

private _vehPoints = [];

// 前部两个点
private _frontAngles = [45, 135];
{
    private _angle = _x;
    private _xPos = (_com select 0) + (_frontRadius * cos _angle);
    private _yPos = (_com select 1) + (_frontRadius * sin _angle);
    private _zPos = (_com select 2) + _heightOffset;
    _vehPoints pushBack [_xPos, _yPos, _zPos];
} forEach _frontAngles;

// 后部两个点
private _rearAngles = [315, 225];
{
    private _angle = _x;
    private _xPos = (_com select 0) + (_rearRadius * cos _angle);
    private _yPos = (_com select 1) + (_rearRadius * sin _angle);
    private _zPos = (_com select 2) + _heightOffset;
    _vehPoints pushBack [_xPos, _yPos, _zPos];
} forEach _rearAngles;

// 后方中间点
private _rearX = (_com select 0) + (_rearRadius * cos 270);
private _rearY = (_com select 1) + (_rearRadius * sin 270);
private _rearZ = (_com select 2) + _heightOffset;
_vehPoints pushBack [_rearX, _rearY, _rearZ];

// ========== 定义所有绳索配对 ==========
private _mainPairs = [
    [0, 0], // 前右 -> 前右
    [1, 2], // 前左 -> 后右
    [2, 1], // 后右 -> 前左
    [3, 3]  // 后左 -> 后左
];
private _crossPairs = [
    [0, 2], // 直升机前右 -> 车辆后右
    [1, 0], // 直升机前左 -> 车辆前右
    [2, 3], // 直升机后右 -> 车辆后左
    [3, 1]  // 直升机后左 -> 车辆前左
];
private _rearPair = [4, 4];
private _allPairs = _mainPairs + _crossPairs + [_rearPair];

// ========== 计算初始松弛长度 ==========
private _dists = [];
{
    _x params ["_heliIdx", "_vehIdx"];
    private _heliPos = _helo modelToWorld (_heliPoints select _heliIdx);
    private _vehPos = _targetVehicle modelToWorld (_vehPoints select _vehIdx);
    _dists pushBack (_heliPos distance _vehPos);
} forEach _allPairs;
private _maxDist = selectMax _dists;
private _ropeLength = _maxDist * 1.1; // 10%松弛

// ========== 远程调用服务器创建并收紧绳索（此时服务器会设置 allowDamage false）==========
[player, "create", [_helo, _targetVehicle, _allPairs, _heliPoints, _vehPoints, _ropeLength, _originalMass]] remoteExec ["fnc_helolift_ropes", 2];

// 等待服务器完成绳索收紧
_ropesTightVar = _varPrefix + "_ropesTight";
waitUntil {
    sleep 1.5;
    (missionNamespace getVariable [_ropesTightVar, false]) or (call _check_damage)
};
if (call _check_damage) exitWith { call _abort };
sleep 6;
_speaker = localize "STR_DUWS_T_crane";
_message = format[localize "STR_DUWS_T_helolift5"];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

// ========== 6. 请求航点 ==========
[player, "height", [60]] remoteExec ["fnc_helolift_waypoints", 2];
if (call _check_damage) exitWith { call _abort };

_liftActionID = player addAction [
    format ["<t color='#00ff00'>%1</t>", localize "STR_DUWS_T_helolift_action_wp"],
    fnc_mapclicklift,
    nil,
    0,
    true,
    true,
    "",
    "true"
];
if (call _check_damage) exitWith { player removeAction _liftActionID; call _abort };

waitUntil {sleep 1.5; (player getVariable ["LiftTakeOff", false]) or (call _check_damage)};
player removeAction _liftActionID;
if (call _check_damage) exitWith { call _abort };

private _waypoints = player getVariable ["LiftWaypoints", []];
if (count _waypoints < 3) exitWith { hint localize "STR_DUWS_T_liftwp_incomplete"; call _abort };

// ========== 7. 飞往航点路线 ==========
// 更新最终航点标记位置（客户端视觉反馈）
private _heloPos = getPos _helo;
private _finalClickPos = _waypoints select 2;
private _offsetFinalPos = _finalClickPos getPos [-70, _finalClickPos getDir _heloPos];
private _markers = player getVariable ["LiftWaypointMarkers", []];
if (count _markers >= 3) then {
    _finalMarker = _markers select 2;
    _finalMarker setMarkerPos _offsetFinalPos;
};

// 远程调用服务器设置航点路线
_finalReachedVar = _varPrefix + "_finalReached";
missionNamespace setVariable [_finalReachedVar, false];
[player, "setRoute", [_waypoints]] remoteExec ["fnc_helolift_waypoints", 2];

[player, "height", [60]] remoteExec ["fnc_helolift_waypoints", 2];

waitUntil {
    sleep 0.5;
    (missionNamespace getVariable [_finalReachedVar, false]) or (call _check_damage)
};
if (call _check_damage) exitWith { call _abort };

[player, "height", [60]] remoteExec ["fnc_helolift_waypoints", 2];
_speaker = localize "STR_DUWS_T_crane";
_message = format[localize "STR_DUWS_T_helolift6"];
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
if (call _check_damage) exitWith { call _abort };

// ========== 8. 执行释放（远程调用服务器放松并销毁绳索，并恢复质量）==========
[player, "release", [_helo, _ropeLength, _targetVehicle, _originalMass]] remoteExec ["fnc_helolift_ropes", 2];
sleep 8; // 等待绳索放松

// 移除航点标记（客户端）
private _markers = player getVariable ["LiftWaypointMarkers", []];
{ deleteMarker _x } forEach _markers;
player setVariable ["LiftWaypointMarkers", []];


// ========== 9. 飞离并清理 ==========
[player, "height", [100]] remoteExec ["fnc_helolift_waypoints", 2];
[player, "depart", []] remoteExec ["fnc_helolift_waypoints", 2];
// 再次确保标记已清除
{ deleteMarker _x } forEach _markers;
player setVariable ["LiftWaypointMarkers", []];
[player, "cleanup", [_helo]] remoteExec ["fnc_helolift_ropes", 2];
sleep 120;
[player, "helo_lift"] call BIS_fnc_addCommMenuItem;