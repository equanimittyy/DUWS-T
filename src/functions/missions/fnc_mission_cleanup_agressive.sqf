// CLEANUP - 增强版，保留玩家相关对象，删除蓝方单位
params ["_targetpos","_radius"];
sleep 20;
private _hintMsg = localize "STR_DUWS_T_MISSION_CLEANUP_START";
[_hintMsg] remoteExec ["hint", 0];
["missionclean", [localize "STR_DUWS_T_renwuqingli", localize "STR_DUWS_T_renwuqingli2"]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated, false];
sleep 280;
["missionclean", [localize "STR_DUWS_T_renwuqingli", localize "STR_DUWS_T_renwuqingli4"]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated, false];
sleep 50;
["missionclean", [localize "STR_DUWS_T_renwuqingli", localize "STR_DUWS_T_renwuqingli5"]] remoteExec ['BIS_fnc_showNotification', [0,-2] select isDedicated, false];
sleep 10;
_close = false;

{
    if ((_targetpos distance _x) < (zones_max_radius * 1.2)) exitWith {_close = true};
} forEach WARCOM_zones_controled_by_OPFOR;

// 定义僵尸类名列表
private _zombieClasses = ["zombie_runner", "zombie_bolter", "zombie_walker"];

// 如果目标位置不靠近任何OPFOR控制区
if (_close == false) then {
    // 获取目标位置1.2倍半径范围内的所有对象
    _missObj = _targetpos nearObjects (_radius * 1.2);
    
    // 构建受保护对象列表（玩家自身及组员、载具）
    _protected = [];
    {
        _player = _x;
        // 保护玩家自身
        _protected pushBackUnique _player;
        // 保护玩家所在组的全体成员
        {
            _unit = _x;
            _protected pushBackUnique _unit;
            // 保护该组员驾驶的载具（如果它在载具内）
            _veh = vehicle _unit;
            if (_veh != _unit) then {
                _protected pushBackUnique _veh;
            };
        } forEach (units group _player);
        // 保护玩家当前乘坐的载具（如果玩家在载具内）
        _veh = vehicle _player;
        if (_veh != _player) then {
            _protected pushBackUnique _veh;
        };
    } forEach allPlayers;  // 遍历所有在线玩家

    // 删除范围内所有不受保护的对象
    {
        private _isHostile = _x getVariable ["isHostile", false];
        // 判断是否为 WBK 模式
        if (CIV_PRESENCE == "WBK") then {
            // WBK 模式：保留蓝方平民 (WEST)、绿方丧尸 (INDEPENDENT) 和普通平民
            if (!(_x in _protected) && (side _x != CIVILIAN) && (side _x != WEST) && (side _x != INDEPENDENT) && !(typeOf _x in _zombieClasses) && !_isHostile) then {
                deleteVehicleCrew _x;
                deleteVehicle _x;
            };
        } else {
            // 原逻辑：保留普通平民和受保护对象(僵尸和敌对平民)
            if (!(_x in _protected) && (side _x != CIVILIAN) && !(typeOf _x in _zombieClasses) && !_isHostile) then {
                deleteVehicleCrew _x;
                deleteVehicle _x;
            };
        };
    } foreach _missObj;
};