// Locality: server -- all 20 callers are mission threads running server-side, and it
// credits the shared CP and AP pools, so it must stay that way.
//event handler for mission complete
// PARAMS:
// 1: command points reward
// 2: army power reward (+BLUFOR only)
// 3: mission name (used in notifications)
// [25, 20, _mission_name] spawn fnc_mission_reward;

_cpreward = _this select 0;
_apreward = _this select 1;
_mission_name = _this select 2;

// Civilians off, RAVAGE and WBK register no town reputation, which zeroes BLUFOR's passive CP
// town faucet (server/misc/fnc_zonesundercontrol.sqf). Missions exist in every configuration, so
// the substitute rides them: mission CP lifts when the faucet is absent, restoring its rough share
// through a route that is always there. Gated on civ_town_rep being empty, not on the mode name, so
// a fourth mode added later inherits it. BLUFOR only -- OPFOR keeps its flat floor and a symmetric
// lift would over-pay it; AP is untouched, coming from zones every configuration has.
private _civsOffLift = if ((count (missionNamespace getVariable ["civ_town_rep", []])) == 0) then { 1.5 } else { 1 };
_cp_multiplied_reward = round (_cpreward * cp_reward_multiplier * _civsOffLift);
["INFO", "MISSION", format ["'%1' succeeded, paying %2 CP and %3 AP",
	_mission_name, _cp_multiplied_reward, _apreward]] call fnc_log;
[_cp_multiplied_reward, format ["mission %1", _mission_name]] remoteExec ["fnc_cp_adjust", 2];

// Missions are a faucet BLUFOR earns, so the whole AP reward credits the tier counter (4th arg).
["BLU", _apreward, format ["mission %1", _mission_name], _apreward] remoteExec ["fnc_ap_adjust", 2];

[] spawn fnc_operative_mission_complete;

sleep 10;
["cpaddedmission",[_cp_multiplied_reward]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
["apaddedmission",[_apreward]] remoteExec ['BIS_fnc_showNotification',[0,-2] select isDedicated,false];
