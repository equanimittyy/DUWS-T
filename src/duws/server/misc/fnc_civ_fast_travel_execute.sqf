/*
    fnc_civ_fast_travel_execute.sqf
    服务器：根据点击位置执行传送，传送到目标城镇外侧（远离玩家当前位置的方向）
    参数: [_clickPos, _caller]
*/
if (!isServer) exitWith {};

params ["_clickPos", "_caller"];
if (isNull _caller) exitWith {};

// 获取所有平民区域
private _locations = missionNamespace getVariable ["civ_locations", []];
private _radii = missionNamespace getVariable ["civ_radii", []];
if (_locations isEqualTo []) exitWith {
    [localize "STR_DUWS_T_FAST_TRAVEL_NO_AREAS"] remoteExec ["hint", _caller];
};

// 找到点击位置最近的平民区域（目标城镇）
private _targetLoc = objNull;
private _targetDist = 1e10;
private _targetIndex = -1;
{
    private _pos = getPos _x;
    private _dist = _clickPos distance _pos;
    if (_dist < _targetDist) then {
        _targetDist = _dist;
        _targetLoc = _x;
        _targetIndex = _forEachIndex;
    };
} forEach _locations;

if (isNull _targetLoc) exitWith {
    [localize "STR_DUWS_T_FAST_TRAVEL_NO_AREAS"] remoteExec ["hint", _caller];
};

private _targetPos = getPos _targetLoc;
private _targetRadius = _radii select _targetIndex;

// 距离限制：玩家当前位置与目标城镇中心距离超过5公里则拒绝
private _distance = _caller distance _targetPos;
if (_distance > 5000) exitWith {
    private _msg = format [localize "STR_DUWS_T_FAST_TRAVEL_TOO_FAR", round (_distance / 1000)];
    [_msg] remoteExec ["hint", _caller];
};

// 计算方向：从目标城镇指向玩家当前位置
private _dirToPlayer = _targetPos getDir _caller;
private _offset = _targetRadius * 1.1;
private _finalPos = _targetPos getPos [_offset, _dirToPlayer];

// 寻找安全位置
private _spawnPos = [_finalPos, 0, 30, 5, 0, 0.2, 0] call BIS_fnc_findSafePos;
if ((_spawnPos isEqualTo [0,0,0]) || {surfaceIsWater _spawnPos}) then {
    _spawnPos = _finalPos;
    _spawnPos set [2, 0];
    if (surfaceIsWater _spawnPos) then {
        _spawnPos = [_targetPos, _offset, _dirToPlayer + 45] call BIS_fnc_relPos;
        _spawnPos set [2, 0];
    };
};

_spawnPos = [_spawnPos select 0, _spawnPos select 1, 0];

["INFO", "CIV", format ["%1 teleported from %2 to %3 (target: %4, radius: %5, dir: %6)", name _caller, getPos _caller, _spawnPos, _targetPos, _targetRadius, _dirToPlayer]] call fnc_log;

// 临时无敌
_caller allowDamage false;

// 执行传送
_caller setPos _spawnPos;

// 淡入效果
[["", "BLACK IN", 1]] remoteExec ["titleCut", _caller];
// 延迟恢复伤害
[_caller] spawn {
    params ["_unit"];
    sleep 2;
    if (!isNull _unit) then {
        _unit allowDamage true;
    };
};
[localize "STR_DUWS_T_FAST_TRAVEL_there"] remoteExec ["hint", _caller];