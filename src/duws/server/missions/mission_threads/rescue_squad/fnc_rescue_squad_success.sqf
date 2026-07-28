// Locality: server -- inherited from server/missions/mission_threads/rescue_squad/fnc_rescue_squad_mission.sqf.
params ["_markername","_markername2","_sol1","_sol2","_sol3","_MissionPos","_targetPos","_radius","_mission_name"];


_speaker = localize "STR_DUWS_T_Signal";
_message = localize "STR_DUWS_T_lyjjiteq";

_trigger = player1;
if (isMultiplayer) then {

	_nearestUnits = [];
	if (alive _sol1) then {
		_nearestUnits = nearestObjects [_sol1,["Man"],150];
	} else {
		if (alive _sol2) then {
			_nearestUnits = nearestObjects [_sol2,["Man"],150];
		} else {
			if (alive _sol3) then {
				_nearestUnits = nearestObjects [_sol3,["Man"],150];
			};
		};
	};


	{
		if (_x in _nearestUnits) then {_trigger = _x}; 
	} forEach call BIS_fnc_ListPlayers;   

};


_sol1 setcaptive false;
_sol2 setcaptive false;
_sol3 setcaptive false;
//_sol1 switchMove "AmovPpneMstpSnonWnonDnon";
//_sol2 switchMove "AmovPpneMstpSnonWnonDnon";
//_sol3 switchMove "AmovPpneMstpSnonWnonDnon";
_sol1 switchMove "";
_sol2 switchMove "";
_sol3 switchMove "";

_cpreward = 45;
_apreward = 15;

sleep 30;

private "_VARtaskgeneratedName";
_VARtaskgeneratedName = format ["rescue%1%2",round(_MissionPos select 0),round(_MissionPos select 1)]; // generate taskname/variable name

// remove markers
deleteMarker str(_markername2);
deleteMarker str(_markername);

// IF SOLDIERS DEAD
if (!(alive _sol1) && !(alive _sol2) && !(alive _sol3)) exitWith {

	[{hint localize "STR_DUWS_T_1sp94d75"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    _speaker = localize "STR_DUWS_T_OVERLORD";
    _message = ([localize "STR_DUWS_T_squadfail"] call fnc_cs);
    [_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

	[_VARtaskgeneratedName, "FAILED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated,true];

	[] spawn fnc_missionTimer;

	[_targetPos,_radius] spawn fnc_mission_cleanup;
};

[_VARtaskgeneratedName, "SUCCEEDED"] remoteExec ["BIS_fnc_taskSetState", [0,-2] select isDedicated,true];

// Define globalChat source
_solRadio = "";
if (alive _sol1) then {
	_solRadio = _sol1;
} else {
	if (alive _sol2) then {
		_solRadio = _sol2;
	} else {
		if (alive _sol3) then {
			_solRadio = _sol3;
		};
	};
};

// JOIN PLAYER
if (alive _sol1) then {
	[_sol1] joinSilent (group _trigger);
};
if (alive _sol2) then {
	[_sol2] joinSilent (group _trigger);
};
if (alive _sol3) then {
	[_sol3] joinSilent (group _trigger);
};

[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];

[{hint localize "STR_DUWS_T_q9yne5ax"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
sleep 5;

// Give cookies  (bonus & notifications)
[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
// Spawn the "next mission" wait
[] spawn fnc_missionTimer;

// ========== 防止清理时误触发直升机增援 ==========
private _varSuffix = format ["%1_%2", round(_MissionPos select 0), round(_MissionPos select 1)];
private _triggeredVar = format ["opf_reinforce_%1", _varSuffix];
missionNamespace setVariable [_triggeredVar, true, true];
// ================================================

// Spawn the cleanup
[_targetpos,_radius] spawn fnc_mission_cleanup;

// If HARDCORE, Rescue pays intel. Guaranteed, and called rather than spawned into a client
// function: the shape this replaced ran from a server thread through one that began
// `if (!hasInterface) exitWith {}`, so on a dedicated server the reward evaporated.
if (hardcore_mode_enable) then {call fnc_intel_payout};