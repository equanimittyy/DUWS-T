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

// The body says "Knight 1-5 to HQ" under a "Pilot" slot on purpose: the insertion flight has
// its own callsign, but the player is in the cabin hearing a person rather than on the net
// hearing a callsign. Do not reconcile the two -- it is intro flavour, not an attribution bug.
[localize "STR_DUWS_T_pilot_intro", localize "STR_DUWS_T_heli_moving"] remoteExec ["fnc_duws_dialogue", 0];
sleep 1;
[["DUWST", "PLAIN", 0, true]] remoteExec ["cutRsc", 0];
sleep 8;
// Double brackets: remoteExec hands the command an argument list, so a unary command whose one
// argument is itself an array needs the outer pair. Written flat, titleText is passed the string
// alone and throws on the type -- which is the memorial card silently not displaying at all.
[["In memory of KillaTomata, the creator of the original DUWS_X.", "PLAIN", 3]] remoteExec ["titleText", 0];
sleep 12;
[["", "PLAIN", 5]] remoteExec ["titleText", 0];
sleep 3;
[["", "PLAIN", 5]] remoteExec ["cutText", 0];
[localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_heli_ttgtw"] remoteExec ["fnc_duws_dialogue", 0];
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

[localize "STR_DUWS_T_pilot_intro", localize "STR_DUWS_T_heli_inpos"] remoteExec ["fnc_duws_dialogue", 0];
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

// The whole stick ropes at once. These waits used to sit inside a forEach on the server, so a
// player's black screen only began once the player before them was already on the ground --
// about 13.5 s each, most of a minute of nothing for the last man of a four.
private _dropThreads = [];
private _dropping = (_boardedPlayers apply {[_x, true]}) + (_unboardedPlayers apply {[_x, false]});
{
    _x params ["_dropPlayer", "_wasBoarded"];
    _dropThreads pushBack ([_dropPlayer, _wasBoarded, _groundPosASL, _forEachIndex, count _dropping] spawn {
        params ["_player", "_wasBoarded", "_groundPosASL", "_index", "_total"];

        // 登机玩家：黑屏 + 索降音效；未登机玩家只等待相同的节奏
        if (_wasBoarded) then {
            [["", "BLACK OUT", 1.5]] remoteExec ["titleCut", _player];
            sleep 3;
            "rappel" remoteExec ["playSound", _player];
            sleep 10;
        } else {
            sleep 3;
        };

        moveOut _player;
        sleep 0.5;

        // Fanned around the rope point rather than dropped onto it: the serial version arrived
        // 13 s apart and could share one spot, but a stick landing together ends up inside one
        // another, which the engine resolves by shoving them apart. Sized for a full cabin --
        // the ring holds a fixed radius, so the more players it seats the tighter the spacing.
        private _ringRadius = 10;
        private _angle = 360 * _index / _total;
        private _landing = [(_groundPosASL select 0) + (sin _angle) * _ringRadius, (_groundPosASL select 1) + (cos _angle) * _ringRadius, 0];
        _landing set [2, getTerrainHeightASL [_landing select 0, _landing select 1]];
        _player setPosASL _landing;
        _player setVariable ["intro_completed", true, true];

        [["", "BLACK IN", 1]] remoteExec ["titleCut", _player];
        [localize "STR_DUWS_T_actionteam", ([localize "STR_DUWS_T_ground_reached"] call fnc_cs)] remoteExec ["fnc_duws_dialogue", _player];
    });
} forEach _dropping;

// Held until the last man is down: the flyaway below moves the helicopter off the point every
// one of these threads is placing a player on.
waitUntil {sleep 0.5; (_dropThreads findIf {!scriptDone _x}) isEqualTo -1};

missionNamespace setVariable ["intro_heli_done", true, true];
publicVariable "intro_heli_done";

sleep 6;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_heli_roger"] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_vzjqx5tp"] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_heli_money"] remoteExec ["fnc_duws_dialogue", 0];

// 直升机飞离
_heli flyInHeight 100;
private _flyAwayPos = _hqPos getPos [15000, random 360];
_flyAwayPos set [2, 100];
private _wp2 = _heliGroup addWaypoint [_flyAwayPos, 0];
_wp2 setWaypointType "MOVE";
_wp2 setWaypointBehaviour "CARELESS";
sleep 10;

// Despawn on distance plus a hard cap, like the helo taxi -- never on the flyaway waypoint
// completing. The exit point is 15 km out and routinely off-map, so the group can orbit the
// boundary indefinitely and a completion-gated wait would leave the heli parked over the base.
private _leaveStart = time;
waitUntil {
    sleep 1;
    (_heli distance2D _hqPos > 2000) || !alive _heli || (time - _leaveStart) > 180
};
if (alive _heli && {_heli distance2D _hqPos < 2000}) then {
    ["WARN", "INTRO", "Helicopter never cleared the base; deleting on timeout."] call fnc_log;
};

sleep 30;
{ deleteVehicle _x } forEach units _heliGroup;
deleteVehicle _heli;
["INFO", "INTRO", "Helicopter and crew deleted."] call fnc_log;
