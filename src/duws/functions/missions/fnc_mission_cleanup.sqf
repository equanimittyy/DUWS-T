// Locality: server -- callers remoteExec to target 2.
// CLEANUP - 删除红方单位
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

if (_close == false) then {
    _missObj = _targetpos nearObjects (_radius * 1.2);
    {
        private _isHostile = _x getVariable ["isHostile", false];
        // 判断是否为 WBK 模式
        if (CIV_PRESENCE == "WBK") then {
            // WBK 模式：保留蓝方平民 (WEST)、绿方丧尸 (INDEPENDENT) 和普通平民
            if ((side _x != WEST) && (side _x != INDEPENDENT) && (side _x != CIVILIAN) && !(typeOf _x in _zombieClasses) && !_isHostile) then {
                deleteVehicleCrew _x;
                deleteVehicle _x;
            };
        } else {
            // 原逻辑：保留 WEST 和普通平民以及敌对平民
            if ((side _x != WEST) && (side _x != CIVILIAN) && !(typeOf _x in _zombieClasses) && !_isHostile) then {
                deleteVehicleCrew _x;
                deleteVehicle _x;
            };
        };
    } foreach _missObj;
};