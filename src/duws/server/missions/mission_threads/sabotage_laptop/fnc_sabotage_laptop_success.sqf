// Locality: server -- the addAction body in
// server/missions/mission_threads/sabotage_laptop/fnc_sabotage_laptop_mission.sqf remoteExecs
// here to target 2. The split exists because an addAction is dispatched to whoever used it and
// has no server-side form; only the action's own removal has to stay there.
params ["_object", "_missionPos", "_targetPos", "_mission_name", "_markername2", "_radius"];

_cpreward = 10;
_apreward = 35;

// setObjectTexture is local, so the dead screen only ever showed for the player who did the
// hacking; everyone else kept looking at a live laptop on a finished mission. The global form
// runs on the server, which owns the object. The loop this replaces only ever set index 0.
if (count getObjectTextures _object > 0) then {
  _object setObjectTextureGlobal [0, "#(rgb,8,8,3)color(0,0,1,1)"];
};

// The action body already dropped the activating player's copy; this clears everyone else's.
[_object,0] remoteExec ["removeAction",[0,-2] select isDedicated];

// Dropping the queued copy is what stops a joiner re-hacking a finished mission. The id is a
// string, so nothing deletes it implicitly, and the laptop outlives the hack.
remoteExec ["", format ["sabotage_action_%1", netId _object]];

[{hint localize "STR_DUWS_T_v5ylof1e"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated, false];

private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["sabotage%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];

deleteMarker str(_markername2);

[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;
missionNamespace setVariable ["current_mission_target_pos", nil];

// ========== 防止清理时误触发直升机增援 ==========
private _varSuffix = format ["%1_%2", round(_MissionPos select 0), round(_MissionPos select 1)];
private _triggeredVar = format ["opf_reinforce_%1", _varSuffix];
missionNamespace setVariable [_triggeredVar, true, true];
// ================================================

// 发放奖励
[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[] spawn fnc_missionTimer;
// Disposal of the laptop, table, pallet and camo net rides on this composition key: they are
// filed under it by fnc_duws_keep at spawn, and release hands each one to fnc_duws_disposeAfter.
// The hand-rolled sweep this replaces ran a second timer in the hacker's scheduler, so it was
// lost on disconnect, and it deleted by class and radius without the keep-radius the disposal
// path respects -- which meant the props could vanish in front of a player still standing there.
[_targetPos,_radius, "mission_sabotage_laptop"] spawn fnc_mission_cleanup;
