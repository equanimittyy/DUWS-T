// Locality: server -- callers remoteExec to target 2.
// Tasks an EXISTING streamer-owned OPFOR hardpoint and pays a mission reward on top of the streamer's own
// bounty -- it spawns nothing itself, so the two payouts stack with no coupling.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;
if (!([16, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

_radius = 400;
_deadline = DUWS_curDeadlineAt;

// Re-validate through the offer's own site-finder (vet mode): launch reads the same filter the picker
// offered on -- one rule, no drift -- and server-side here it hits the authoritative DUWS_hardpoints.
private _site = [_MissionPos] call fnc_destroy_hardpoint_site;
if (_site isEqualTo []) exitWith { [16, _requester, "no_hardpoint"] call fnc_mission_abort };
_site params ["_hpPos", "_hpKey"];

// The emplacement already stands -- present at once, no spawn-up to narrate.
private _taskId = format ["hp%1%2", round (_hpPos select 0), round (_hpPos select 1)];
private _marker = [_hpPos, _radius, _taskId, localize "STR_DUWS_T_DESTROY_HARDPOINT_DESC", _mission_name, "destroy",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_hardpointoverlord", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_hardpointcopy"]]
] call fnc_mission_present;

// Win when the row leaves DUWS_hardpoints: watch liveness, not any one object. A gone row already paid its
// bounty; the deadline covers it left standing.
waitUntil {
    sleep 5;
    (DUWS_hardpoints findIf { (_x select 0) isEqualTo _hpKey }) < 0 || time > _deadline
};

if ((DUWS_hardpoints findIf { (_x select 0) isEqualTo _hpKey }) >= 0 && time > _deadline) exitWith {
    [_mission_name, _taskId, "FAILED", _hpPos, _radius, [_marker]] call fnc_mission_finish;
};

[_mission_name, _taskId, "SUCCEEDED", _hpPos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_hardpointclose"], true, "mission_destroy_hardpoint"] call fnc_mission_finish;
