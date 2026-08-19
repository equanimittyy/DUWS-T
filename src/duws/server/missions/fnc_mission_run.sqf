// Locality: server -- side-mission threads call it, and every thread runs server-side.
//
// The shared spine of the default-shaped side missions: reach a marked spot, spawn the objective,
// wait until a win predicate holds or the deadline passes, pay out or fail, tear down. Every step
// here is identical across those missions and was copy-pasted per thread; only two things ever
// vary, and both are passed in the spec -- what the mission spawns (_build) and how it is won
// (_done). A thread becomes: build a spec, call this.
//
// NOT for the missions whose win is continuous or scripted (hold-for-duration, the domination
// battle, protect-civ, the informant hunt) -- their win does not reduce to a one-shot predicate,
// and forcing them through here would mean a hook for every step the spine is supposed to own.
//
// The spec is a positional array, destructured below -- the mission layer passes arrays through
// params everywhere (fnc_mission_begin, fnc_mission_site), and a HashMap's get/getOrDefault do not
// parse under the pinned sqf-vm, so this stays verifiable alongside its neighbours. Fields:
//   _index    num   mission-type index handed to fnc_mission_begin (the entry gate / cooldown)
//   _radius   num   objective ring the site is found within and the marker drawn at
//   _taskType str   CfgTaskTypes class -- picks the task icon only
//   _descKey  str   stringtable key for the task description
//   _nameKey  str   stringtable key for the mission name, hinted alongside the intro card
//   _idPrefix str   task-id stem; the rounded mission position is appended so it is unique
//   _build    code  [_targetpos,_randomPos,_radius,_Building] -> handles. Spawns and claims the
//                   objective (garrison, target group, vehicle, ...) and returns whatever _done
//                   needs to test. Runs after the marker/task so the player already sees the area.
//   _done     code  handles -> bool. The win predicate, polled every 2s against the deadline. A
//                   mission won by a trigger or an action tests its own flag here (see recon).
//   _brief    array optional [[speakerKey,msgKey,delayAfter], ...] -- intro dialogue, played in order
//   _endLine  array optional [speakerKey,msgKey] -- success line, callsign-substituted via fnc_cs
//   _compKey  str   optional composition key handed to fnc_mission_end / _deadline_fail for teardown
//   _sweep    bool  optional, forwarded to teardown
params ["_MissionPos", "_mission_name", "_spec"];
_spec params [
    "_index", "_radius", "_taskType", "_descKey", "_nameKey", "_idPrefix", "_build", "_done",
    ["_brief", []], ["_endLine", []], ["_compKey", ""], ["_sweep", false]
];

if (!([_index, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

private _site = [_MissionPos, _radius, _index] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// Marked before anything is built: the ellipse and the task are the only things telling the player
// where the objective is, and the build below can run for tens of seconds.
private _marker = [_randomPos, _radius] call fnc_missionMarkerData;
private _taskId = format ["%1%2%3", _idPrefix, round (_MissionPos select 0), round (_MissionPos select 1)];
[_taskId, localize _descKey, _mission_name, _randomPos, _taskType] call fnc_missionTaskCreate;
[localize _nameKey, {hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];

private _handles = [_targetpos, _randomPos, _radius, _Building] call _build;
if (isNil "_handles") then { _handles = [] };

// Nearest named settlement to the marker, for the "marked near <place>" briefs. Altis names are
// dense enough the ring effectively always resolves; the grid fallback covers the empty edge.
private _place = format ["grid %1", mapGridPosition _randomPos];
{
    if (text _x != "") exitWith { _place = text _x };
} forEach nearestLocations [_randomPos, ["NameCityCapital", "NameCity", "NameVillage", "NameLocal", "NameMarine"], 5000];

{
    _x params ["_spk", "_msg", ["_delay", 0]];
    [localize _spk, format [localize _msg, _place]] remoteExec ["fnc_duws_dialogue", 0];
    if (_delay > 0) then { sleep _delay };
} forEach _brief;

sleep 5; // let the patrols the build spawned finish arriving before the win poll starts

private _deadline = DUWS_curDeadlineAt;

waitUntil {sleep 2; (_handles call _done) || time > _deadline};

if (!(_handles call _done) && time > _deadline) exitWith {
    [_taskId, _marker, _compKey, _targetpos, _radius, _sweep] call fnc_mission_deadline_fail;
};

if (!(_endLine isEqualTo [])) then {
    _endLine params ["_spk", "_msg"];
    [localize _spk, [localize _msg] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
};
[_marker] call fnc_missionMarkerClear;
[_taskId, "SUCCEEDED"] call fnc_missionTaskEnd;

sleep 1;

[DUWS_curReward select 0, DUWS_curReward select 1, _mission_name] spawn fnc_mission_reward;
[_targetpos, _radius, _compKey, _sweep] call fnc_mission_end;
