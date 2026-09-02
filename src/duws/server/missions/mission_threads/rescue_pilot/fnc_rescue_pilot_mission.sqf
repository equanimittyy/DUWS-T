// Locality: server; the addAction/trigger bodies below run on the machine that triggers them, not here (callers remoteExec to target 2).
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;
if (!([4, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

// Broadcast to every client (JIP) so the carry actions exist on the carrier's own machine; guarded so a
// second launch skips the re-broadcast.
if (isNil "DUWS_fnc_addCarryAction") then {
    private _carryDefs = compile preprocessFileLineNumbers "duws\server\missions\mission_threads\rescue_pilot\fnc_pilot_carry.sqf";
    call _carryDefs;
    [_carryDefs] remoteExec ["call", 0, true];
};

_radius = 300;
_deadline = DUWS_curDeadlineAt;
_speaker = localize "STR_DUWS_T_OVERLORD";
_speaker1 = localize "STR_DUWS_T_pilot_downed";
_message = localize "STR_DUWS_T_pilotletsdothis";
_message1 = localize "STR_DUWS_T_pilotfound";
_message2 = localize "STR_DUWS_T_pilotend";

private _site = [_MissionPos, _radius, 4, _requester] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// The task name finish reads back; the marker follows once the pilot is down (below).
private _VARtaskgeneratedName = format ["rescue%1%2",round(_MissionPos select 0),round(_MissionPos select 1)];
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;

_vehPos = _targetpos;


_spawnPos = _targetpos;
_vec =[random [-1,0,1], random [-1,0,1], 0];
_dist = 75;
_spawnPos = ((vectorNormalized _vec) vectorMultiply _dist) vectorAdd _spawnPos;

sleep 1;
[_spawnPos, _radius] spawn fnc_missionPatrols;
_choppa = "";
switch (VERSION_X) do {
    case "MODERN": {
        _choppa = "Land_Wreck_Heli_Attack_01_F" createVehicle (_vehPos);
        [_choppa, "mission_rescue_pilot"] call fnc_duws_keep;
    };
};
_group = [ [_vehPos select 0, (_vehPos select 1)+2], WEST, [blufor_HELI_PILOT_X] ] call BIS_fnc_spawnGroup;
_pilot = units _group select 0;
_group deleteGroupWhenEmpty true;
_pilot setcaptive true; 
[_pilot, "Acts_InjuredLyingRifle01"] remoteExec ["switchMove", 0];
removeAllItems _pilot;
_pilot setDamage 0.8;
_pilot disableAI "PATH";

_pilot addEventHandler ["Killed", {
    params ["_unit", "_killer"];
    private _carrier = _unit getVariable ["carrier", objNull];
    if (!isNull _carrier) then {
        [_carrier] remoteExec ["DUWS_fnc_clearCarrierActions", 0];
    };
    [_unit] remoteExec ["DUWS_fnc_removeCarryAction", 0];
}];

missionNamespace setVariable ["currentMissionPilot", _pilot];
publicVariable "currentMissionPilot";

[_pilot] call DUWS_fnc_addCarryAction;

// Marker + task now the pilot is down; the brief below is manual (fixed speaker).
_markername2 = [_randomPos, _radius, _VARtaskgeneratedName, localize "STR_DUWS_T_njsu8ofz", _mission_name, "help"] call fnc_mission_present;
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[localize "STR_DUWS_T_actionteam", localize "STR_DUWS_T_pilotcopy"] remoteExec ["fnc_duws_dialogue", 0];
sleep 8;

pilot_west_close = false;
_trg=createTrigger["EmptyDetector",_choppa];
_trg setTriggerArea[50,50,0,false];
_trg setTriggerActivation["WEST","PRESENT",false];
_trg setTriggerStatements["this","pilot_west_close = true;", ""];
_trg setTriggerTimeout [10, 10, 10, true ];  

sleep 5;


waitUntil {
    sleep 1;
    pilot_west_close || !(alive _pilot) || time > _deadline
};

#define CLEANUP_PILOT(pilot) \
    [pilot] call DUWS_fnc_cleanupPilotActions; \
    [pilot] remoteExec ["DUWS_fnc_cleanupPilotActions", 0];
if (!pilot_west_close && time > _deadline) exitWith {
    CLEANUP_PILOT(_pilot);
    if (!isNull attachedTo _pilot) then { detach _pilot; };
    _pilot setDamage 1;
    [{hint localize "STR_DUWS_T_fxysw123"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [_mission_name, _VARtaskgeneratedName, "FAILED", _targetpos, _radius, [_markername2], [], false, "mission_rescue_pilot", false, false] call fnc_mission_finish;
};

if (!(alive _pilot)) exitWith {
    CLEANUP_PILOT(_pilot);
    if (!isNull attachedTo _pilot) then { detach _pilot; };
    [{hint localize "STR_DUWS_T_q3iy1vcz"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [_mission_name, _VARtaskgeneratedName, "FAILED", _targetpos, _radius, [_markername2], [], false, "mission_rescue_pilot", false, false] call fnc_mission_finish;
};

sleep 5;
_pilot setcaptive false;
_pilot disableAI "PATH";
[_pilot, "Acts_InjuredLyingRifle01"] remoteExec ["switchMove", 0];
[_speaker1, _message1] remoteExec ["fnc_duws_dialogue", 0];

sleep 55;

waitUntil {sleep 1; (_pilot distance PosOfBLUHQ)<50 OR !(alive _pilot) OR time > _deadline};

if (alive _pilot && (_pilot distance PosOfBLUHQ) >= 50 && time > _deadline) exitWith {
    CLEANUP_PILOT(_pilot);
    if (!isNull attachedTo _pilot) then { detach _pilot; };
    [_mission_name, _VARtaskgeneratedName, "FAILED", _targetpos, _radius, [_markername2], [], false, "mission_rescue_pilot", false, true] call fnc_mission_finish;
};

if (!(alive _pilot)) exitWith {
    CLEANUP_PILOT(_pilot);
    if (!isNull attachedTo _pilot) then { detach _pilot; };
    [{hint localize "STR_DUWS_T_q3iy1vcz"}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated,false];
    [_mission_name, _VARtaskgeneratedName, "FAILED", _targetpos, _radius, [_markername2], [], false, "mission_rescue_pilot", false, false] call fnc_mission_finish;
};

if (!isNull attachedTo _pilot) then {
    detach _pilot;
    CLEANUP_PILOT(_pilot);
};

// Win outro plays inline (pilot handed over, then deleted, then Overlord's sign-off); the task ticks
// complete at the end through finish, which also pays the reward and releases the slot.
[_speaker1, _message2] remoteExec ["fnc_duws_dialogue", 0];
deleteVehicle _pilot;
missionNamespace setVariable ["currentMissionPilot", nil];
publicVariable "currentMissionPilot";
sleep 5;
_speaker = localize "STR_DUWS_T_OVERLORD";
_message = ([localize "STR_DUWS_T_pilotend2"] call fnc_cs);
[_speaker, _message] remoteExec ["fnc_duws_dialogue", 0];
[_mission_name, _VARtaskgeneratedName, "SUCCEEDED", _targetpos, _radius, [_markername2], [], true, "mission_rescue_pilot", false, false] call fnc_mission_finish;

// Guaranteed and called, not spawned into a client function: intel_payout began `if (!hasInterface)
// exitWith {}`, so spawning it from this server thread evaporated the reward on a dedicated server. The
// mission site stands in for the earner's position -- a server thread has no one player to ask.
if (hardcore_mode_enable) then {[_targetpos] call fnc_intel_payout};