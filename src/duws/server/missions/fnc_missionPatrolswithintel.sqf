// Locality: server -- inherited from server/missions/mission_threads/destroy_cache/fnc_destroy_cache_mission.sqf.
params ["_missionPos", "_radius"];

// 原有的巡逻生成代码（保持不变）
sleep 1;
[[(_missionPos select 0)+30, (_missionPos select 1)+20],_radius, false] spawn fnc_createoppatrol2;
sleep 1;
[[(_missionPos select 0)+30, (_missionPos select 1)],_radius, false] spawn fnc_createoppatrol2;
sleep 1;
[[(_missionPos select 0)+35, (_missionPos select 1)],_radius, false] spawn fnc_createoppatrol2;
sleep 1;
[[(_missionPos select 0), (_missionPos select 1)+35], _radius, false] spawn fnc_createopteam2;
sleep 1;
if (WARCOM_opfor_ap > 100) then {
    [OPFOR_Faction_X,"armored",[(_missionPos select 0)+30, (_missionPos select 1)+10],_radius] spawn fnc_random_veh;
} else {
    [OPFOR_Faction_X,"car",[(_missionPos select 0)+30, (_missionPos select 1)+10],_radius] spawn fnc_random_veh;
};
sleep 1;
[OPFOR_Faction_X,"car",[(_missionPos select 0)+28, (_missionPos select 1)+12],_radius] spawn fnc_random_veh;

// ========== 为区域内所有敌方单位添加死亡情报动作 ==========
[_missionPos, _radius] spawn {
    params ["_pos", "_rad"];
    sleep 5; // 等待单位生成完毕
    private _units = _pos nearEntities [["CAManBase", "LandVehicle", "Air"], _rad * 1.5];
    {
        if (side _x == EAST && !isPlayer _x && !(_x getVariable ["intel_action_added", false])) then {
            [[_x], "mission"] call fnc_search_flag_group;
            _x setVariable ["intel_action_added", true];
        };
    } forEach _units;
};
// ================================================================