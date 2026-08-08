// Locality: server -- inherited from server/missions/mission_threads/rescue_squad/fnc_rescue_squad_mission.sqf.
params ["_markername2","_sol1","_sol2","_sol3","_MissionPos","_targetPos","_radius","_mission_name"];


_speaker = localize "STR_DUWS_T_Signal";
_message = localize "STR_DUWS_T_lyjjiteq";

// Whose squad the rescued three join. Nearest living player at any range, not nearest inside a
// radius: success turns on the prisoners' state rather than on anyone standing close, so "nobody
// within 150 m" is reachable -- and the radius fallback was player1, an editor slot that in co-op
// may be unoccupied, dead or across the map, handing three soldiers to a phantom. The shape this
// replaced also compared no distances at all, letting the last player in list order win. Seeded
// from the first candidate so no magic number stands in for "further than any map".
private _anchor = ([_sol1, _sol2, _sol3] select {alive _x}) param [0, objNull];
private _players = (call BIS_fnc_ListPlayers) select {alive _x};
private _trigger = objNull;
if (!isNull _anchor && {!(_players isEqualTo [])}) then {
	_trigger = _players select 0;
	{ if (_x distance _anchor < _trigger distance _anchor) then {_trigger = _x} } forEach _players;
};


_sol1 setcaptive false;
_sol2 setcaptive false;
_sol3 setcaptive false;
// Broadcast, and the queued pose dropped with it: a local clear released the captives on the
// server alone, leaving every client a squad still crouching after it had walked away.
{
	[_x, ""] remoteExec ["switchMove", 0];
	remoteExec ["", format ["rescue_pose_%1", netId _x]];
} forEach [_sol1,_sol2,_sol3];

_cpreward = 45;
_apreward = 12;

sleep 30;

private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["rescue%1%2",round(_MissionPos select 0),round(_MissionPos select 1)]; // generate taskname/variable name

// remove markers
[_markername2] call fnc_missionMarkerClear;

// IF SOLDIERS DEAD
if (!(alive _sol1) && !(alive _sol2) && !(alive _sol3)) exitWith {

	[{hint localize "STR_DUWS_T_1sp94d75"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    _speaker = localize "STR_DUWS_T_OVERLORD";
    _message = ([localize "STR_DUWS_T_squadfail"] call fnc_cs);
    [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

	[_VARtaskgeneratedName, "FAILED"] call fnc_missionTaskEnd;


	[_targetPos,_radius] call fnc_mission_end;
};

[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;

// JOIN PLAYER
// Null only when every player is dead, and then there is nobody to hand them to: they stay in
// their own group as friendly AI rather than joining group objNull.
if (!isNull _trigger) then {
	{ if (alive _x) then {[_x] joinSilent (group _trigger)} } forEach [_sol1, _sol2, _sol3];
};

[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

[{hint localize "STR_DUWS_T_q9yne5ax"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
sleep 5;

// Give cookies  (bonus & notifications)
[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
// Spawn the "next mission" wait


// Spawn the cleanup
[_targetpos,_radius] call fnc_mission_end;

// If HARDCORE, Rescue pays intel. Guaranteed, and called rather than spawned into a client
// function: the shape this replaced ran from a server thread through one that began
// `if (!hasInterface) exitWith {}`, so on a dedicated server the reward evaporated.
// The mission site stands in for the earner's position: a server thread has no one player to ask,
// and this is the ground the rescue was fought over.
if (hardcore_mode_enable) then {[_targetpos] call fnc_intel_payout};