/*
    fnc_intro_heli.sqf - 修正版（客户端索降同步）
    功能：任务开始时，生成直升机，所有玩家乘机到基地上空，黑屏+音效模拟绳降，然后传送至直升机正下方。
    执行端：服务器
    依赖：PosOfBLUHQ, blufor_HELI_TRANS_UNARM_X
*/

if (!isServer) exitWith {};

// ==================== 单次执行锁 ====================
if (!isNil "intro_heli_executed") exitWith { ["WARN", "INTRO", "Already executed, skipping."] call fnc_log; };
missionNamespace setVariable ["intro_heli_executed", true, true];

// Late joiners are placed by the client, not here: client_init waits on intro_heli_done and
// teleports any player whose intro_completed is false. That path also clears the black screen,
// which the server never did.

// 等待所有玩家就绪
waitUntil { sleep 0.5; count allPlayers > 0 };

private _hqPos = missionNamespace getVariable ["PosOfBLUHQ", []];
if (_hqPos isEqualTo []) exitWith { ["INFO", "INTRO", "PosOfBLUHQ not defined."] call fnc_log;};

// ==================== 生成直升机 ====================
private _spawnPos = [_hqPos, 700, 1000, 10, 0, 0.2, 0] call BIS_fnc_findSafePos;
if (_spawnPos isEqualTo [0,0,0]) then {
    private _angle = random 360;
    private _dist = 250 + random 50;
    _spawnPos = _hqPos getPos [_dist, _angle];
    ["WARN", "INTRO", format ["Using fallback spawn position: %1", _spawnPos]] call fnc_log;
};
_spawnPos set [2, 50];

private _heliType = missionNamespace getVariable ["blufor_HELI_TRANS_UNARM_X", "B_Heli_Transport_01_F"];
private _veh = [_spawnPos, 0, _heliType, WEST] call BIS_fnc_spawnVehicle;
private _heli = _veh select 0;
private _heliGroup = _veh select 2;
_heliGroup deleteGroupWhenEmpty true;
["INFO", "INTRO", format ["Helicopter spawned, group ID: %1", groupId _heliGroup]] call fnc_log;

// 确保有驾驶员
private _pilot = driver _heli;
if (isNull _pilot) then {
    private _driverGroup = createGroup WEST;
    _pilot = _driverGroup createUnit [blufor_SOLDIER_X, [0,0,0], [], 0, "NONE"];
    _pilot moveInDriver _heli;
    _pilot joinSilent _heliGroup;
    deleteGroup _driverGroup;
};

// 设置直升机属性
_heli allowDamage false;
_heli setVehicleAmmo 0;
_heli engineOn true;
_heli flyInHeight 50;

_pilot allowDamage false;
_pilot setCaptive true;
_pilot disableAI "TARGET";
_pilot disableAI "AUTOTARGET";
_pilot disableAI "AUTOCOMBAT";
_pilot setBehaviour "CARELESS";
_pilot allowFleeing 0;

{ _x setVariable ["Vcm_Disable", true] } forEach units _heliGroup;

// ==================== 座位分配（客户端本地登机）====================
missionNamespace setVariable ["intro_heli_object", _heli, true];
private _players = call BIS_fnc_listPlayers;
private _boardedPlayers = [];
private _unboardedPlayers = [];

private _cargoSeats = _heli emptyPositions "cargo";
private _gunnerSeats = _heli emptyPositions "gunner";
private _commanderSeats = _heli emptyPositions "commander";
private _availableSeats = _cargoSeats + _gunnerSeats + _commanderSeats;

{
    if (count _boardedPlayers < _availableSeats) then {
        private _seatType = "";
        if (_cargoSeats > 0) then {
            _seatType = "cargo";
            _cargoSeats = _cargoSeats - 1;
        } else {
            if (_gunnerSeats > 0) then {
                _seatType = "gunner";
                _gunnerSeats = _gunnerSeats - 1;
            } else {
                if (_commanderSeats > 0) then {
                    _seatType = "commander";
                    _commanderSeats = _commanderSeats - 1;
                };
            };
        };
        if (_seatType != "") then {
            [netId _heli, _seatType, _x] remoteExec ["fnc_remoteBoard", _x];
            _boardedPlayers pushBack _x;
        } else {
            _unboardedPlayers pushBack _x;
        };
    } else {
        _unboardedPlayers pushBack _x;
    };
} forEach _players;

// 等待客户端登机
sleep 5;
["INFO", "INTRO", format ["Boarded players: %1, Unboarded: %2", count _boardedPlayers, count _unboardedPlayers]] call fnc_log;

// 通知客户端可以开始（但不执行淡入，避免干扰）
missionNamespace setVariable ["intro_heli_fadein", true, true];
[["", "BLACK IN", 1]] remoteExec ["titleCut", 0];
[] spawn fnc_bottom_right_message;
sleep 0.5;
// 航点到基地上空 50 米
private _hoverPos = _hqPos getPos [20, random 360];
_hoverPos set [2, 50];
private _wp = _heliGroup addWaypoint [_hoverPos, 0];
_wp setWaypointType "MOVE";
_wp setWaypointBehaviour "CARELESS";
_wp setWaypointSpeed "FULL";
_wp setWaypointCompletionRadius 30;
_wp setWaypointStatements ["true", "missionNamespace setVariable ['intro_heli_arrived', true, true];"];

[localize "STR_DUWS_T_pilot", localize "STR_DUWS_T_heli_moving"] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 1;
cutRsc ["DUWST", "PLAIN", 0, true] remoteExec ["call", 0];
sleep 8;
// 显示
titleText ["In memory of KillaTomata, the creator of the original DUWS_X", "PLAIN", -1] remoteExec ["call", 0];
sleep 5;
// 清除
titleText ["", "PLAIN", 5] remoteExec ["call", 0];
sleep 3;
cutText ["", "PLAIN", 5] remoteExec ["call", 0];
[([localize "STR_DUWS_T_actionteam"] call fnc_cs), localize "STR_DUWS_T_heli_ttgtw"] remoteExec ["BIS_fnc_showSubtitle", 0];
// 等待直升机到达航点，超时 120 秒后强制继续
private _arrivedVar = "intro_heli_arrived";
missionNamespace setVariable [_arrivedVar, false];
private _startTime = time;
private _timeout = 120; // 超时时间（秒），可根据需要调整

waitUntil {
    sleep 0.5;
    private _arrived = missionNamespace getVariable [_arrivedVar, false];
    private _timeoutReached = (time - _startTime) > _timeout;
    if (_timeoutReached) then {
        ["WARN", "INTRO", format ["Helicopter waypoint timeout after %1 seconds, forcing arrival.", _timeout]] call fnc_log;
        missionNamespace setVariable [_arrivedVar, true]; // 强制标记为到达
    };
    _arrived || !alive _heli || _timeoutReached
};

[localize "STR_DUWS_T_pilot", localize "STR_DUWS_T_heli_inpos"] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 3;

// ==================== 处理脚本执行过程中加入的 JIP 玩家 ====================
private _allPlayersNow = call BIS_fnc_listPlayers;
private _processedPlayers = _boardedPlayers + _unboardedPlayers;
{
    if (!(_x in _processedPlayers) && !(_x getVariable ["intro_completed", false])) then {
        _unboardedPlayers pushBack _x;
    };
} forEach _allPlayersNow;

// ==================== 索降模拟 ====================
// 获取直升机正下方地面点 ASL
private _heliPos2D = getPos _heli;
private _groundPosASL = [(_heliPos2D select 0), (_heliPos2D select 1), getTerrainHeightASL [_heliPos2D select 0, _heliPos2D select 1]];

// 登机玩家：直接传送（取消分段下降）
{
    private _player = _x;

    // 1. 对该玩家单独黑屏
    [["", "BLACK OUT", 1.5]] remoteExec ["titleCut", _player];
    sleep 3; // 短暂等待，确保黑屏指令已发送

    // 2. 播放音效（仅该玩家）
    "rappel" remoteExec ["playSound", _player];
    sleep 10; // 等待音效播放和黑屏持续

    // 3. 强制移出载具
    moveOut _player;
    sleep 0.5;

    // 4. 直接传送到直升机正下方地面点
    _player setPosASL _groundPosASL;
    _player setVariable ["intro_completed", true, true];

    // 5. 对该玩家单独淡入
    [["", "BLACK IN", 1]] remoteExec ["titleCut", _player];
    [([localize "STR_DUWS_T_actionteam"] call fnc_cs), ([localize "STR_DUWS_T_ground_reached"] call fnc_cs)] remoteExec ["BIS_fnc_showSubtitle", _player];
} forEach _boardedPlayers;
// 未登机玩家：等待相同时间后直接传送到直升机正下方
{
    private _player = _x;
    sleep 3; // 等待时间
    moveOut _player;
    sleep 0.5;
    _player setPosASL _groundPosASL;
    _player setVariable ["intro_completed", true, true];
    [["", "BLACK IN", 1]] remoteExec ["titleCut", _player];
    [([localize "STR_DUWS_T_actionteam"] call fnc_cs), ([localize "STR_DUWS_T_ground_reached"] call fnc_cs)] remoteExec ["BIS_fnc_showSubtitle", _player];
} forEach _unboardedPlayers;

missionNamespace setVariable ["intro_heli_done", true, true];
publicVariable "intro_heli_done";

sleep 6;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_heli_roger"] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 8;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_vzjqx5tp"] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 8;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_heli_money"] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];

// 直升机飞离
_heli flyInHeight 100;
private _flyAwayPos = _hqPos getPos [15000, random 360];
_flyAwayPos set [2, 100];
private _wp2 = _heliGroup addWaypoint [_flyAwayPos, 0];
_wp2 setWaypointType "MOVE";
_wp2 setWaypointBehaviour "CARELESS";
_wp2 setWaypointStatements ["true", "missionNamespace setVariable ['intro_heli_leave', true, true];"];
sleep 10;
// ========== 焦土模式字幕 ==========
if (!isNil "scorched_earth_enabled" && scorched_earth_enabled) then {
    [localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_SEEsub"] remoteExec ["BIS_fnc_showSubtitle", 0];
    [] remoteExec ["fnc_broadcastRadioChatter", 0];
};
waitUntil {
    sleep 1;
    missionNamespace getVariable ["intro_heli_leave", false] || !alive _heli
};

sleep 30;
{ deleteVehicle _x } forEach units _heliGroup;
deleteVehicle _heli;
["INFO", "INTRO", "Helicopter and crew deleted."] call fnc_log;
