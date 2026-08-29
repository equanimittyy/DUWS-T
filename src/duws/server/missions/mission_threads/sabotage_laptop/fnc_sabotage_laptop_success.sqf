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

// setObjectTexture is local, so only the player who set it would see the dead screen;
// setObjectTextureGlobal runs on the server, which owns the object, so every client sees it finished.
if (count getObjectTextures _object > 0) then {
  _object setObjectTextureGlobal [0, "#(rgb,8,8,3)color(0,0,1,1)"];
};

// The hold action hides itself once DUWS_laptop_done is set (in the hold's completion, before this runs),
// so no per-client removal is needed. Dropping the queued JIP add still matters -- it stops a late joiner
// re-adding the entry, since the string id is never deleted implicitly and the laptop outlives the hack.
remoteExec ["", format ["sabotage_action_%1", netId _object]];

private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["sabotage%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];

// Cross markers are raw createMarker names, cleared by hand; the ellipse, the win line, the task state,
// the reward and slot release go through finish. Disposal of the laptop, table, pallet and camo net
// rides on the composition key (fnc_duws_keep at spawn -> fnc_duws_disposeAfter on release in
// fnc_mission_end), so the props leave on the keep-radius clock rather than vanishing in a player's face.
{ deleteMarker _x } forEach _crossMarkers;
[_mission_name, _VARtaskgeneratedName, "SUCCEEDED", _targetPos, _radius, [_markername2], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_laptopdone"], true, "mission_sabotage_laptop", false, false] call fnc_mission_finish;
