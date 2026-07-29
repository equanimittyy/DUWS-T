// Locality: client -- passed as an addAction function value in
// server/missions/mission_threads/sabotage_laptop/fnc_sabotage_laptop_mission.sqf, so it runs on
// whoever sabotages the laptop. Rewards and cleanup are remoteExec'd to the server.
_object = _this select 0;

_arguments = _this select 3;
_missionPos = _arguments select 0;
_targetPos = _arguments select 1;
_mission_name = _arguments select 2;
_markername2 = _arguments select 3;
_radius = _arguments select 4;

_cpreward = 10;
_apreward = 35;

// setObjectTexture is local, so the dead screen only ever showed for the player who did the
// hacking; everyone else kept looking at a live laptop on a finished mission. The global form
// runs on the server, which owns the object. The loop this replaces only ever set index 0.
if (count getObjectTextures _object > 0) then {
  [_object, [0, "#(rgb,8,8,3)color(0,0,1,1)"]] remoteExec ["setObjectTextureGlobal", 2];
};

[_object,0] remoteExec ["removeAction",[0,-2] select isDedicated];

// Dropping the queued copy is what stops a joiner re-hacking a finished mission. The id is a
// string, so nothing deletes it implicitly, and the laptop outlives the hack anyway -- the
// delete at the foot of this file waits 340 s and dies with the player if they disconnect
// first. Run on the server, which owns the queue.
[format ["sabotage_action_%1", netId _object], { remoteExec ["", _this] }] remoteExec ["call", 2];

hint localize "STR_DUWS_T_v5ylof1e";

private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["sabotage%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];

deleteMarker str(_markername2);

[_VARtaskgeneratedName, "SUCCEEDED"] remoteExec ["fnc_missionTaskEnd", 2];
missionNamespace setVariable ["current_mission_target_pos", nil];

// ========== 防止清理时误触发直升机增援 ==========
private _varSuffix = format ["%1_%2", round(_MissionPos select 0), round(_MissionPos select 1)];
private _triggeredVar = format ["opf_reinforce_%1", _varSuffix];
missionNamespace setVariable [_triggeredVar, true, true];
// ================================================

// 发放奖励
[_cpreward, _apreward, _mission_name] remoteExec ["fnc_mission_reward", 2];
[] remoteExec ["fnc_missionTimer", 2];
[_targetPos,_radius, "mission_sabotage_laptop"] remoteExec ["fnc_mission_cleanup", 2];

sleep 340;
private _nearObjects = nearestObjects [_targetPos, ["Land_WoodenTable_large_F","VirtualReammoBox_camonet_F","Land_Laptop_unfolded_F","CamoNet_INDP_open_F"], 20];
{ deleteVehicle _x } forEach _nearObjects;