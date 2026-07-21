// 现有严重bug————客户端呼叫的直升机无法生成路点。已经在fnc_request_support里为客户端禁用了直升机吊装功能。
// 修改说明：将所有 setMass 和 allowDamage 操作移到服务器；故障处理改为远程调用服务器清理。
// 二次修改：在 setMass 和 allowDamage 后添加 remoteExec 广播，使状态同步到所有客户端。
// 三次修改：将广播提前到绳索创建之前，进一步保证物理一致性。
params ["_unused1", "_unused2", "_cost"];

// ==================== 全局服务器函数定义（所有机器可见）====================
// ---------- 绳索操作函数（仅在服务器执行核心逻辑）----------
if (isNil "fnc_helolift_ropes") then {
    fnc_helolift_ropes = {
        params ["_caller", "_mode", "_params"];
        if (!isServer) exitWith {}; // 只在服务器执行

        private _playerUID = getPlayerUID _caller;
        private _varPrefix = format ["LiftTask_%1", _playerUID];

        switch (_mode) do {
            case "create": { // 创建并收紧绳索，同时设置载具无敌
                _params params ["_helo", "_targetVehicle", "_allPairs", "_heliPoints", "_vehPoints", "_ropeLength", "_originalMass"];
                private _ropes = [];

                // 【修改点】先设置质量并广播，确保所有客户端在绳索创建前获得正确状态
                if (_originalMass > 4200) then {
                 _targetVehicle setMass 4200;
                [_targetVehicle, 4200] remoteExec ["setMass", 0];
                };
                _targetVehicle allowDamage false;
                [_targetVehicle, false] remoteExec ["allowDamage"];//重复设置质量并广播以避免设置质量失效

                // 创建9根绳索（此时客户端质量已更新或正在更新，至少服务器端正确）
                {
                    _x params ["_heliIdx", "_vehIdx"];
                    private _heliPos = _heliPoints select _heliIdx;
                    private _vehPos = _vehPoints select _vehIdx;
                    private _rope = ropeCreate [_helo, _heliPos, _targetVehicle, _vehPos, _ropeLength];
                    _ropes pushBack _rope;
                } forEach _allPairs;

                if (_originalMass > 4200) then {
                 _targetVehicle setMass 4200;
                [_targetVehicle, 4200] remoteExec ["setMass", 0];
                };
                _targetVehicle allowDamage false;
                [_targetVehicle, false] remoteExec ["allowDamage"];//重复设置质量并广播以避免设置质量失效

                _helo setVariable ["attachedRopes", _ropes, true]; // 广播给所有客户端
                _helo flyInHeight 10;

                if (_originalMass > 4200) then {
                 _targetVehicle setMass 4200;
                [_targetVehicle, 4200] remoteExec ["setMass", 0];
                };
                _targetVehicle allowDamage false;
                [_targetVehicle, false] remoteExec ["allowDamage"];//重复设置质量并广播以避免设置质量失效

                _speaker = localize "STR_DUWS_T_pilot";
                _message = format[localize "STR_DUWS_T_helolift4"];
                [_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
                [] remoteExec ["fnc_broadcastRadioChatter", 0];
                
                if (_originalMass > 4200) then {
                 _targetVehicle setMass 4200;
                [_targetVehicle, 4200] remoteExec ["setMass", 0];
                };
                _targetVehicle allowDamage false;
                [_targetVehicle, false] remoteExec ["allowDamage"];//重复设置质量并广播以避免设置质量失效

                // 收紧绳索
                private _targetLength = _ropeLength * 0.2;
                { ropeUnwind [_x, 3.5, _targetLength]; } forEach _ropes;

                if (_originalMass > 4200) then {
                 _targetVehicle setMass 4200;
                [_targetVehicle, 4200] remoteExec ["setMass", 0];
                };
                _targetVehicle allowDamage false;
                [_targetVehicle, false] remoteExec ["allowDamage"];//重复设置质量并广播以避免设置质量失效

                // 标记绳索已收紧（广播给客户端）
                missionNamespace setVariable [_varPrefix + "_ropesTight", true, true];
            };
            case "release": { // 放松并销毁绳索，恢复载具状态
                _params params ["_helo", "_ropeLength", "_targetVehicle", "_originalMass"];
                private _ropes = _helo getVariable ["attachedRopes", []];
                if (_ropes isEqualTo []) exitWith {};

                // 放松绳索
                { ropeUnwind [_x, 7, _ropeLength * 1.1]; } forEach _ropes;
                sleep 8; // 等待放松完成
                { ropeDestroy _x } forEach _ropes;
                _helo setVariable ["attachedRopes", nil, true];

                // 恢复载具质量及允许伤害（服务器设置，并广播给所有客户端）
                if (!isNull _targetVehicle) then {
                    _targetVehicle setMass _originalMass;
                    [_targetVehicle, _originalMass] remoteExec ["setMass"];
                    _targetVehicle allowDamage true;
                    [_targetVehicle, true] remoteExec ["allowDamage"];
                };
            };
            case "abort": { // 紧急清理（故障时调用）
                _params params ["_helo", "_targetVehicle", "_originalMass", "_heloGroup"];
                // 销毁绳索
                private _ropes = _helo getVariable ["attachedRopes", []];
                { ropeDestroy _x } forEach _ropes;
                _helo setVariable ["attachedRopes", nil, true];

                // 恢复载具状态（服务器设置，并广播给所有客户端）
                if (!isNull _targetVehicle) then {
                    _targetVehicle setMass _originalMass;
                    [_targetVehicle, _originalMass] remoteExec ["setMass"];
                    _targetVehicle allowDamage true;
                    [_targetVehicle, true] remoteExec ["allowDamage"];
                };

                // 让直升机降落并删除
                if (!isNull _helo) then {
                    _helo land "LAND";
                    _helo engineOn false;
                    // 延时后删除机组和直升机
                    [_helo, _heloGroup] spawn {
                        params ["_helo", "_heloGroup"];
                        sleep 160;
                        if (!isNull _heloGroup) then { { deleteVehicle _x } forEach units _heloGroup; };
                        if (!isNull _helo) then { deleteVehicle _helo; };
                    };
                };
            };
        };
    };
};

// ---------- 航点操作函数（仅在服务器执行）----------
if (isNil "fnc_helolift_waypoints") then {
    fnc_helolift_waypoints = {
        params ["_caller", "_mode", "_params"];
        if (!isServer) exitWith {};
        private _playerUID = getPlayerUID _caller;
        private _varPrefix = format ["LiftTask_%1", _playerUID];
        private _helo = missionNamespace getVariable (_varPrefix + "_helo");
        if (isNull _helo) exitWith {};
        private _heloGroup = group (currentPilot _helo);
        if (isNull _heloGroup) exitWith {};

        switch (_mode) do {
            case "setInitial": { // 设置飞往目标的初始航点
                _params params ["_targetVehicle"];
                // 清除现有航点
                while {count (waypoints _heloGroup) > 0} do {
                    deleteWaypoint ((waypoints _heloGroup) select 0);
                };
                private _targetPos = getPos _targetVehicle;
                private _heloPos = getPos _helo;
                private _dirToHelo = _targetPos getDir _helo;
                private _offsetPos = _targetPos getPos [-70, _dirToHelo];
                private _wp = _heloGroup addWaypoint [_offsetPos, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointCompletionRadius 5;
                _wp setWaypointBehaviour "CARELESS";
                _wp setWaypointStatements ["true", format ["missionNamespace setVariable ['LiftTask_%1_moveCompleted', true, true];", _playerUID]];
            };
            case "setRoute": { // 设置玩家选择的三个航点
                _params params ["_waypoints"];
                // 清除现有航点
                while {count (waypoints _heloGroup) > 0} do {
                    deleteWaypoint ((waypoints _heloGroup) select 0);
                };
                private _heloPos = getPos _helo;
                private _finalClickPos = _waypoints select 2;
                private _offsetFinalPos = _finalClickPos getPos [-70, _finalClickPos getDir _heloPos];
                _waypoints set [2, _offsetFinalPos];
                {
                    private _wp = _heloGroup addWaypoint [_x, 0];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointCompletionRadius 5;
                    _wp setWaypointBehaviour "CARELESS";
                    if (_forEachIndex == (count _waypoints - 1)) then {
                        _wp setWaypointStatements ["true", format ["missionNamespace setVariable ['LiftTask_%1_finalReached', true, true];", _playerUID]];
                    };
                } forEach _waypoints;
            };
        };
    };
};

// ==================== 客户端执行部分 ====================

// ========== 1. 目标检查与初始化 ==========
_target = cursorObject;
if (isNull _target) exitWith {
    hint localize "STR_DUWS_T_imz98waj";
    [player, "helo_lift"] call BIS_fnc_addCommMenuItem;
};
if !(_target isKindOf "Car" || _target isKindOf "Tank" || _target isKindOf "Helicopter" || _target isKindOf "Plane") exitWith {
    hint localize "STR_DUWS_T_1gk907or";
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
// 客户端向服务器请求生成直升机
[player, _target] remoteExec ["fnc_helolift_spawnHeli", 2]; 


_vehpos = getPos player;
_vec = [random [-1,0,1], random [-1,0,1], 0];
_dist = 1200;
_spawnPos = ((vectorNormalized _vec) vectorMultiply _dist) vectorAdd _vehpos;
_spawnPos set [2, 200];

_veh = [_spawnPos, 0, "C_IDAP_Heli_Transport_02_F", WEST] call BIS_fnc_spawnvehicle;
_helo = _veh select 0;
_helo setPos _spawnPos;
_helo flyInHeight 30;
_heloGroup = _veh select 2;
_heloGroup deleteGroupWhenEmpty true;
_pilot = currentPilot _helo;

// 设置机组状态
_pilot setCaptive false;
_pilot allowFleeing 0;
_pilot disableAI "TARGET";
_pilot allowDamage true;
{ _x setVariable ["Vcm_Disable", true]; } forEach units _heloGroup;

// 将直升机对象存储到公共变量供服务器使用（广播给客户端）
missionNamespace setVariable [_varPrefix + "_helo", _helo, true];

// ========== 3. 保存目标引用 ==========
_targetVehicle = _target;
_originalMass = getMass _targetVehicle;

// 定义绳索清理函数（远程调用服务器清理）
_cleanupRopes = {
    params ["_helo"];
    [player, "cleanup", [_helo]] remoteExec ["fnc_helolift_ropes", 2];
};

// ========== 添加直升机损坏检测 ==========
_helo_maxDamage = 0.7;
_helo_minFuel = 0.4;
_check_damage = compile format ["(isNull _helo) or (damage _helo > %1) or (fuel _helo < %2) or (vehicle _pilot == _pilot)", _helo_maxDamage, _helo_minFuel];

// ========== 4. 通知并飞往载具位置 ==========
_speaker = localize "STR_DUWS_T_actionteam";
_message = format[localize "STR_DUWS_T_heloliftcall"];
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];

// 创建临时吊装点标记
_hookMarkerName = format ["hook_%1", floor random 10000];
createMarker [_hookMarkerName, getPos _target];
_hookMarkerName setMarkerType "hd_dot";
_hookMarkerName setMarkerColor "ColorBlue";
_hookMarkerName setMarkerText "HOOK POINT";

// ========== 5. 飞抵目标上空并执行挂钩 ==========
// 清除现有航点（确保客户端组干净）
while {count (waypoints _heloGroup) > 0} do {
    deleteWaypoint ((waypoints _heloGroup) select 0);
};

// 远程调用服务器设置初始航点
_moveCompletedVar = _varPrefix + "_moveCompleted";
missionNamespace setVariable [_moveCompletedVar, false]; // 初始化（客户端本地）
[player, "setInitial", [_targetVehicle]] remoteExec ["fnc_helolift_waypoints", 2];

sleep 8;
_speaker = localize "STR_DUWS_T_dispatcher";
_message = format[localize "STR_DUWS_T_helolift1"];
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 6;
_speaker = localize "STR_DUWS_T_pilot";
_message = format[localize "STR_DUWS_T_helolift2"];
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 6;
waitUntil {
    sleep 1.5;
    (missionNamespace getVariable [_moveCompletedVar, false]) or (call _check_damage)
};
if (call _check_damage) exitWith {
    // 客户端清理标记
    private _markers = player getVariable ["LiftWaypointMarkers", []];
    { deleteMarker _x } forEach _markers;
    player setVariable ["LiftWaypointMarkers", []];
    // 远程调用服务器 abort 模式清理
    [player, "abort", [_helo, _targetVehicle, _originalMass, _heloGroup]] remoteExec ["fnc_helolift_ropes", 2];
    sleep 160;
    [player, "helo_lift"] call BIS_fnc_addCommMenuItem;
};

_helo flyInHeight 10;
deleteMarker _hookMarkerName;
_speaker = localize "STR_DUWS_T_pilot";
_message = format[localize "STR_DUWS_T_helolift3"];
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 6;
if (call _check_damage) exitWith {
    private _markers = player getVariable ["LiftWaypointMarkers", []];
    { deleteMarker _x } forEach _markers;
    player setVariable ["LiftWaypointMarkers", []];
    [player, "abort", [_helo, _targetVehicle, _originalMass, _heloGroup]] remoteExec ["fnc_helolift_ropes", 2];
    sleep 160;
    [player, "helo_lift"] call BIS_fnc_addCommMenuItem;
};

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
if (call _check_damage) exitWith {
    private _markers = player getVariable ["LiftWaypointMarkers", []];
    { deleteMarker _x } forEach _markers;
    player setVariable ["LiftWaypointMarkers", []];
    [player, "abort", [_helo, _targetVehicle, _originalMass, _heloGroup]] remoteExec ["fnc_helolift_ropes", 2];
    sleep 160;
    [player, "helo_lift"] call BIS_fnc_addCommMenuItem;
};
sleep 6;
_speaker = localize "STR_DUWS_T_pilot";
_message = format[localize "STR_DUWS_T_helolift5"];
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];

// ========== 6. 请求航点 ==========
_helo flyInHeight 60;
if (call _check_damage) exitWith {
    private _markers = player getVariable ["LiftWaypointMarkers", []];
    { deleteMarker _x } forEach _markers;
    player setVariable ["LiftWaypointMarkers", []];
    [player, "abort", [_helo, _targetVehicle, _originalMass, _heloGroup]] remoteExec ["fnc_helolift_ropes", 2];
    sleep 160;
    [player, "helo_lift"] call BIS_fnc_addCommMenuItem;
};

_liftActionID = player addAction [
    "<t color='#00ff00' size='2'>Give Waypoints to pilot</t>",
    fnc_mapclicklift,
    nil,
    0,
    true,
    true,
    "",
    "true"
];
if (call _check_damage) exitWith {
    player removeAction _liftActionID;
    private _markers = player getVariable ["LiftWaypointMarkers", []];
    { deleteMarker _x } forEach _markers;
    player setVariable ["LiftWaypointMarkers", []];
    [player, "abort", [_helo, _targetVehicle, _originalMass, _heloGroup]] remoteExec ["fnc_helolift_ropes", 2];
    sleep 160;
    [player, "helo_lift"] call BIS_fnc_addCommMenuItem;
};

waitUntil {sleep 1.5; (player getVariable ["LiftTakeOff", false]) or (call _check_damage)};
player removeAction _liftActionID;
if (call _check_damage) exitWith {
    private _markers = player getVariable ["LiftWaypointMarkers", []];
    { deleteMarker _x } forEach _markers;
    player setVariable ["LiftWaypointMarkers", []];
    [player, "abort", [_helo, _targetVehicle, _originalMass, _heloGroup]] remoteExec ["fnc_helolift_ropes", 2];
    sleep 160;
    [player, "helo_lift"] call BIS_fnc_addCommMenuItem;
};

private _waypoints = player getVariable ["LiftWaypoints", []];
if (count _waypoints < 3) exitWith {
    hint "Waypoints not fully set. Mission aborted.";
    // 清理标记
    private _markers = player getVariable ["LiftWaypointMarkers", []];
    { deleteMarker _x } forEach _markers;
    player setVariable ["LiftWaypointMarkers", []];
    // 远程调用服务器 abort 清理
    [player, "abort", [_helo, _targetVehicle, _originalMass, _heloGroup]] remoteExec ["fnc_helolift_ropes", 2];
    sleep 160;
    [player, "helo_lift"] call BIS_fnc_addCommMenuItem;
};

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

_helo flyInHeight 60; // 客户端设置飞行高度

waitUntil {
    sleep 0.5;
    (missionNamespace getVariable [_finalReachedVar, false]) or (call _check_damage)
};
if (call _check_damage) exitWith {
    private _markers = player getVariable ["LiftWaypointMarkers", []];
    { deleteMarker _x } forEach _markers;
    player setVariable ["LiftWaypointMarkers", []];
    [player, "abort", [_helo, _targetVehicle, _originalMass, _heloGroup]] remoteExec ["fnc_helolift_ropes", 2];
    sleep 160;
    [player, "helo_lift"] call BIS_fnc_addCommMenuItem;
};

_helo flyInHeight 60;
_speaker = localize "STR_DUWS_T_pilot";
_message = format[localize "STR_DUWS_T_helolift6"];
[_speaker, _message] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 6;
if (call _check_damage) exitWith {
    private _markers = player getVariable ["LiftWaypointMarkers", []];
    { deleteMarker _x } forEach _markers;
    player setVariable ["LiftWaypointMarkers", []];
    [player, "abort", [_helo, _targetVehicle, _originalMass, _heloGroup]] remoteExec ["fnc_helolift_ropes", 2];
    sleep 160;
    [player, "helo_lift"] call BIS_fnc_addCommMenuItem;
};

// ========== 8. 执行释放（远程调用服务器放松并销毁绳索，并恢复质量）==========
[player, "release", [_helo, _ropeLength, _targetVehicle, _originalMass]] remoteExec ["fnc_helolift_ropes", 2];
sleep 8; // 等待绳索放松

// 移除航点标记（客户端）
private _markers = player getVariable ["LiftWaypointMarkers", []];
{ deleteMarker _x } forEach _markers;
player setVariable ["LiftWaypointMarkers", []];

if (!isNull _targetVehicle) then {
_targetVehicle setMass _originalMass;
[_targetVehicle, _originalMass] remoteExec ["setMass"];
_targetVehicle allowDamage true;
[_targetVehicle, true] remoteExec ["allowDamage"];
};//再次恢复质量和伤害以避免bug

// ========== 9. 飞离并清理 ==========
_helo flyInHeight 100;
while {count (waypoints _heloGroup) > 0} do {
    deleteWaypoint ((waypoints _heloGroup) select 0);
};
private _worldCenter = getArray (configFile >> "CfgWorlds" >> worldName >> "centerPosition");
_worldCenter set [2, 200];
_heloGroup addWaypoint [_worldCenter, 0];
// 再次确保标记已清除
{ deleteMarker _x } forEach _markers;
player setVariable ["LiftWaypointMarkers", []];
[_helo, _heloGroup] spawn {
    params ["_helo", "_heloGroup"];
    sleep 210;
    if (!isNull _helo) then {
        [_helo] call _cleanupRopes; // 远程清理可能残留的绳索
        if (!isNull _heloGroup) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _heloGroup;
        };
        deleteVehicle _helo;
    };
};
sleep 200;
[player, "helo_lift"] call BIS_fnc_addCommMenuItem;