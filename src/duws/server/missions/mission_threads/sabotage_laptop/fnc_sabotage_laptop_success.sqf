// Locality: server -- the laptop's hold-action completion in
// server/missions/mission_threads/sabotage_laptop/fnc_sabotage_laptop_mission.sqf remoteExecs
// here to target 2. The split exists because a hold action completes on whoever held it and has no
// server-side form; the shared state -- reward, task, teardown -- is decided here.
params ["_object", "_missionPos", "_targetPos", "_mission_name", "_markername2", "_radius", ["_crossMarkers", []]];

// Idempotent: two players can finish the hold on the same laptop a frame apart, and each one's
// completion calls in here. First pays, the rest no-op. Server-local flag is enough, since the server
// runs these calls in order.
if (_object getVariable ["DUWS_laptop_paid", false]) exitWith {};
_object setVariable ["DUWS_laptop_paid", true];

_cpreward = DUWS_curReward select 0;
_apreward = DUWS_curReward select 1;

// setObjectTexture is local, so the dead screen only ever showed for the player who did the
// hacking; everyone else kept looking at a live laptop on a finished mission. The global form
// runs on the server, which owns the object. The loop this replaces only ever set index 0.
if (count getObjectTextures _object > 0) then {
  _object setObjectTextureGlobal [0, "#(rgb,8,8,3)color(0,0,1,1)"];
};

// The hold action hides itself the instant DUWS_laptop_done is set on the laptop (in the hold's own
// completion, before this runs), so no per-client removal is needed. Dropping the queued JIP add still
// matters: it stops a late joiner from re-adding the entry. The id is a string, so nothing deletes it
// implicitly, and the laptop outlives the hack.
remoteExec ["", format ["sabotage_action_%1", netId _object]];

[localize "STR_DUWS_T_OVERLORD", [localize "STR_DUWS_T_laptopdone"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];

private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["sabotage%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];

[_markername2] call fnc_missionMarkerClear;
{ deleteMarker _x } forEach _crossMarkers;

[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;


[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
// Disposal of the laptop, table, pallet and camo net rides on this composition key: they are
// filed under it by fnc_duws_keep at spawn, and release hands each one to fnc_duws_disposeAfter.
// The hand-rolled sweep this replaces ran a second timer in the hacker's scheduler, so it was
// lost on disconnect, and it deleted by class and radius without the keep-radius the disposal
// path respects -- which meant the props could vanish in front of a player still standing there.
[_targetPos,_radius, "mission_sabotage_laptop"] call fnc_mission_end;
