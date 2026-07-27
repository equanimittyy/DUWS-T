// Locality: client -- passed as an addAction function value in
// server/missions/mission_threads/sabotage_laptop/fnc_sabotage_laptop_mission.sqf, so it runs on
// whoever sabotages the laptop. Rewards and cleanup are remoteExec'd to the server.
_object = _this select 0;

_arguments = _this select 3;
_missionPos = _arguments select 0;
_targetPos = _arguments select 1;
_mission_name = _arguments select 2;
_markername = _arguments select 3;
_markername2 = _arguments select 4;
_radius = _arguments select 5;

_cpreward = 10;
_apreward = 35;

_count = 0;
{
  _object setObjectTexture [_count,"#(rgb,8,8,3)color(0,0,1,1)"];
  _count = _count + 1;
  if (_count == 1) exitwith{};
} foreach getObjectTextures _object;

[_object,0] remoteExec ["removeAction",[0,-2] select isDedicated];

hint localize "STR_DUWS_T_v5ylof1e";

private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["sabotage%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];

deleteMarker str(_markername2);
deleteMarker str(_markername);

[_VARtaskgeneratedName, "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated,true];
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