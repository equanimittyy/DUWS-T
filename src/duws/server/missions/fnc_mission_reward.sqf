// Locality: server -- all 20 callers are mission threads running server-side, and it
// credits the shared CP and AP pools, so it must stay that way.
//event handler for mission complete
// PARAMS:
// 1: command points reward
// 2: army power reward (both +BLUFOR and -OPFOR)
// 3: mission name (used in notifications)
// [25, 20, _mission_name] spawn fnc_mission_reward;

_cpreward = _this select 0;
_apreward = _this select 1;
_mission_name = _this select 2;

_cp_multiplied_reward = (_cpreward * cp_reward_multiplier);
["INFO", "MISSION", format ["'%1' succeeded, paying %2 CP and %3 AP",
	_mission_name, _cp_multiplied_reward, _apreward]] call fnc_log;
[_cp_multiplied_reward, format ["mission %1", _mission_name]] remoteExec ["fnc_cp_adjust", 2];

// MODIFY ARMY POWER - OPF loses 1/2 the points, BLU gains full points
["BLU", _apreward, format ["mission %1", _mission_name]] remoteExec ["fnc_ap_adjust", 2];

//_opfreward = round(_apreward/2);
//WARCOM_opfor_ap = WARCOM_opfor_ap - _opfreward;
//publicVariable "WARCOM_opfor_ap";

[] spawn fnc_operative_mission_complete;

sleep 10;
["cpaddedmission",[_cp_multiplied_reward]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
["apaddedmission",[_apreward]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
