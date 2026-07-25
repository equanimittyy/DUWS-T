/*
    fnc_intro_heli.sqf - 修正版（客户端索降同步）
    功能：任务开始时，生成直升机，所有玩家乘机到基地上空，黑屏+音效模拟绳降，然后传送至直升机正下方。
    执行端：服务器
    依赖：PosOfBLUHQ, blufor_HELI_TRANS_UNARM_X
*/

if (!isServer) exitWith { diag_log "[INTRO] Not server, exit."; };

// ==================== 单次执行锁 ====================
if (!isNil "intro_heli_executed") exitWith { diag_log "[INTRO] Already executed, skipping."; };
missionNamespace setVariable ["intro_heli_executed", true, true];
diag_log "[INTRO] Script started, execution locked.";

// ==================== JIP 处理（流程结束后） ====================
if (!isNil "intro_heli_done" && {intro_heli_done}) then {
    diag_log "[INTRO] Detected intro_heli_done = true, handling JIP players.";
    private _hqPos = missionNamespace getVariable ["PosOfBLUHQ", []];
    if !(_hqPos isEqualTo []) then {
        {
            if (!(_x getVariable ["intro_completed", false])) then {
                private _landPos = [_hqPos, 5, 50, 3, 0, 0.2, 0] call BIS_fnc_findSafePos;
                if (_landPos isEqualTo [0,0,0]) then {
                    _landPos = _hqPos getPos [random 30, random 360];
                };
                _x setPos _landPos;
                _x setVariable ["intro_completed", true];
                diag_log format ["[INTRO] JIP player %1 teleported to base.", name _x];
            };
        } forEach (call BIS_fnc_listPlayers);
    };
    diag_log "[INTRO] JIP handling complete.";
    return;
};

// 等待所有玩家就绪
diag_log "[INTRO] Waiting for players to connect...";
waitUntil { sleep 0.5; count allPlayers > 0 };
diag_log format ["[INTRO] Players ready: %1", count allPlayers];

private _hqPos = missionNamespace getVariable ["PosOfBLUHQ", []];
if (_hqPos isEqualTo []) exitWith { diag_log "[INTRO] PosOfBLUHQ not defined." };
diag_log format ["[INTRO] HQ position: %1", _hqPos];

// ==================== 生成直升机 ====================
private _spawnPos = [_hqPos, 700, 1000, 10, 0, 0.2, 0] call BIS_fnc_findSafePos;
if (_spawnPos isEqualTo [0,0,0]) then {
    private _angle = random 360;
    private _dist = 250 + random 50;
    _spawnPos = _hqPos getPos [_dist, _angle];
    diag_log format ["[INTRO] Using fallback spawn position: %1", _spawnPos];
} else {
    diag_log format ["[INTRO] Found safe spawn position: %1", _spawnPos];
};
_spawnPos set [2, 50];

private _heliType = missionNamespace getVariable ["blufor_HELI_TRANS_UNARM_X", "B_Heli_Transport_01_F"];
diag_log format ["[INTRO] Helicopter type: %1", _heliType];
private _veh = [_spawnPos, 0, _heliType, WEST] call BIS_fnc_spawnVehicle;
private _heli = _veh select 0;
private _heliGroup = _veh select 2;
_heliGroup deleteGroupWhenEmpty true;
diag_log format ["[INTRO] Helicopter spawned, group ID: %1", groupId _heliGroup];

// 确保有驾驶员
private _pilot = driver _heli;
if (isNull _pilot) then {
    diag_log "[INTRO] No pilot, creating one.";
    private _driverGroup = createGroup WEST;
    _pilot = _driverGroup createUnit [blufor_SOLDIER_X, [0,0,0], [], 0, "NONE"];
    _pilot moveInDriver _heli;
    _pilot joinSilent _heliGroup;
    deleteGroup _driverGroup;
};
diag_log format ["[INTRO] Pilot: %1", _pilot];

// 设置直升机属性
_heli allowDamage false;
_heli setVehicleAmmo 0;
_heli engineOn true;
_heli flyInHeight 50;
diag_log "[INTRO] Helicopter properties set.";

_pilot allowDamage false;
_pilot setCaptive true;
_pilot disableAI "TARGET";
_pilot disableAI "AUTOTARGET";
_pilot disableAI "AUTOCOMBAT";
_pilot setBehaviour "CARELESS";
_pilot allowFleeing 0;
diag_log "[INTRO] Pilot configured.";

{ _x setVariable ["Vcm_Disable", true] } forEach units _heliGroup;
diag_log "[INTRO] VCOM disabled for helicopter crew.";

// ==================== 座位分配（客户端本地登机）====================
missionNamespace setVariable ["intro_heli_object", _heli, true];
diag_log "[INTRO] Helicopter object stored in missionNamespace.";
private _players = call BIS_fnc_listPlayers;
private _boardedPlayers = [];
private _unboardedPlayers = [];

private _cargoSeats = _heli emptyPositions "cargo";
private _gunnerSeats = _heli emptyPositions "gunner";
private _commanderSeats = _heli emptyPositions "commander";
private _availableSeats = _cargoSeats + _gunnerSeats + _commanderSeats;

diag_log format ["[INTRO] Available seats: %1 (cargo: %2, gunner: %3, commander: %4)", 
    _availableSeats, _cargoSeats, _gunnerSeats, _commanderSeats];

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
            diag_log format ["[INTRO] Remote boarding command sent to %1 (seat: %2)", name _x, _seatType];
        } else {
            _unboardedPlayers pushBack _x;
            diag_log format ["[INTRO] %1 no seat available", name _x];
        };
    } else {
        _unboardedPlayers pushBack _x;
        diag_log format ["[INTRO] %1 no seat left", name _x];
    };
} forEach _players;

// 等待客户端登机
diag_log "[INTRO] Waiting 5 seconds for players to board...";
sleep 5;
diag_log format ["[INTRO] Boarded players: %1, Unboarded: %2", count _boardedPlayers, count _unboardedPlayers];

// 通知客户端可以开始（但不执行淡入，避免干扰）
missionNamespace setVariable ["intro_heli_fadein", true, true];
diag_log "[INTRO] Set intro_heli_fadein = true.";
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
diag_log format ["[INTRO] Helicopter waypoint set to %1", _hoverPos];

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

diag_log "[INTRO] Waiting for helicopter to reach waypoint...";
waitUntil {
    sleep 0.5;
    private _arrived = missionNamespace getVariable [_arrivedVar, false];
    private _timeoutReached = (time - _startTime) > _timeout;
    if (_timeoutReached) then {
        diag_log format ["[INTRO] Helicopter waypoint timeout after %1 seconds, forcing arrival.", _timeout];
        missionNamespace setVariable [_arrivedVar, true]; // 强制标记为到达
    };
    _arrived || !alive _heli || _timeoutReached
};
diag_log "[INTRO] Helicopter arrived at waypoint (or timeout forced).";

[localize "STR_DUWS_T_pilot", localize "STR_DUWS_T_heli_inpos"] remoteExec ["BIS_fnc_showSubtitle", 0];
[] remoteExec ["fnc_broadcastRadioChatter", 0];
sleep 3;

// ==================== 处理脚本执行过程中加入的 JIP 玩家 ====================
private _allPlayersNow = call BIS_fnc_listPlayers;
private _processedPlayers = _boardedPlayers + _unboardedPlayers;
diag_log format ["[INTRO] Current players after arrival: %1", count _allPlayersNow];
{
    if (!(_x in _processedPlayers) && !(_x getVariable ["intro_completed", false])) then {
        _unboardedPlayers pushBack _x;
        diag_log format ["[INTRO] JIP player %1 detected, will be teleported directly.", name _x];
    };
} forEach _allPlayersNow;

// ==================== 索降模拟 ====================
private _descentDuration = 10;      // 下降总时长（秒）

// 获取直升机当前位置（ASL）和正下方地面点 ASL
private _heliPosASL = getPosASL _heli;
private _heliPos2D = getPos _heli;
private _groundPosASL = [(_heliPos2D select 0), (_heliPos2D select 1), getTerrainHeightASL [_heliPos2D select 0, _heliPos2D select 1]];
diag_log format ["[INTRO] Helicopter ASL: %1, Ground ASL: %2", _heliPosASL, _groundPosASL];

// 登机玩家：直接传送（取消分段下降）
diag_log format ["[INTRO] Starting descent for %1 boarded players...", count _boardedPlayers];
{
    private _player = _x;
    diag_log format ["[INTRO] Processing boarded player %1", name _player];

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
    diag_log format ["[INTRO] Player %1 teleported to %2", name _player, _groundPosASL];

    // 5. 对该玩家单独淡入
    [["", "BLACK IN", 1]] remoteExec ["titleCut", _player];
    [([localize "STR_DUWS_T_actionteam"] call fnc_cs), ([localize "STR_DUWS_T_ground_reached"] call fnc_cs)] remoteExec ["BIS_fnc_showSubtitle", _player];
    diag_log format ["[INTRO] Player %1 received fade-in and subtitle.", name _player];
} forEach _boardedPlayers;
// 未登机玩家：等待相同时间后直接传送到直升机正下方
diag_log format ["[INTRO] Starting direct teleport for %1 unboarded players...", count _unboardedPlayers];
{
    private _player = _x;
    diag_log format ["[INTRO] Processing unboarded player %1", name _player];
    sleep 3; // 等待时间
    moveOut _player;
    sleep 0.5;
    _player setPosASL _groundPosASL;
    _player setVariable ["intro_completed", true, true];
    diag_log format ["[INTRO] Player %1 teleported to %2", name _player, _groundPosASL];
    [["", "BLACK IN", 1]] remoteExec ["titleCut", _player];
    [([localize "STR_DUWS_T_actionteam"] call fnc_cs), ([localize "STR_DUWS_T_ground_reached"] call fnc_cs)] remoteExec ["BIS_fnc_showSubtitle", _player];
    diag_log format ["[INTRO] Player %1 received fade-in and subtitle.", name _player];
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
diag_log format ["[INTRO] Helicopter flying away to %1", _flyAwayPos];
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
diag_log "[INTRO] Helicopter left the area.";

sleep 30;
{ deleteVehicle _x } forEach units _heliGroup;
deleteVehicle _heli;
diag_log "[INTRO] Helicopter and crew deleted.";