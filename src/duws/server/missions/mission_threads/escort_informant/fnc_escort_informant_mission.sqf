// Locality: server -- callers remoteExec to target 2.
//
// STUB. Wires the offer, site pick and briefing so the type runs end to end and completes, but the real
// objective is not built yet: no informant NPC is spawned, and the mission succeeds the moment a player
// reaches the pickup rather than on escorting the informant clear. The full version spawns a civilian at
// the site, has the player carry them out (DUWS_fnc_unitCarry) to a safe town, and pays town rep on the
// outcome -- see fnc_transport_IDAP_mission for the escort/hand-over shape to model it on.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;
if (!([20, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

private _radius = 400;
private _reach = 30;
private _deadline = DUWS_curDeadlineAt;

private _site = [_MissionPos, _radius, 20, _requester] call fnc_mission_site;
if (_site isEqualTo []) exitWith {};
_site params ["_randomPos", "_Building", "_targetpos"];

// Hold the generating beat (cosmetic) so a present-only stub reads survey -> generating -> complete like a
// spawn-up mission does.
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;
sleep 2;

private _taskId = format ["escortinf%1%2", round (_targetpos select 0), round (_targetpos select 1)];
private _marker = [_randomPos, _radius, _taskId, localize "STR_DUWS_T_ESCORT_INFORMANT_DESC", _mission_name, "move",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_escortinformant_brief", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_escortinformant_copy"]]
] call fnc_mission_present;

// STUB win: a player reaches the pickup. Replace with the informant escorted clear to safety.
waitUntil {
    sleep 2;
    (allPlayers findIf { _x distance2D _targetpos < _reach }) >= 0 || time > _deadline
};

if ((allPlayers findIf { _x distance2D _targetpos < _reach }) < 0 && time > _deadline) exitWith {
    [_mission_name, _taskId, "FAILED", _targetpos, _radius, [_marker]] call fnc_mission_finish;
};

[_mission_name, _taskId, "SUCCEEDED", _targetpos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_escortinformant_close"], true] call fnc_mission_finish;
