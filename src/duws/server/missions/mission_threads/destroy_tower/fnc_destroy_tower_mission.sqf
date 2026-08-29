// Locality: server -- callers remoteExec to target 2.
// Tasks an EXISTING streamer-owned OPFOR RADIO mast (DUWS_radioMastClass) and pays a mission reward on top
// of the streamer's own bounty -- it spawns nothing itself, so the two payouts stack with no coupling.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;
if (!([3, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

_radius = 400;
_deadline = DUWS_curDeadlineAt;

// Re-validate through the offer's own site-finder (vet mode): launch reads the same filter the picker
// offered on -- one rule, no drift -- and server-side here it hits the authoritative DUWS_hardpoints.
private _site = [_MissionPos] call fnc_destroy_tower_site;
if (_site isEqualTo []) exitWith { [3, _requester, "no_radio_hp"] call fnc_mission_abort };
_site params ["_hpPos", "_hpKey"];

// The mast already stands -- nothing to build. Hold the generating beat anyway (cosmetic 2s) so a
// present-only mission reads survey -> generating -> complete like the spawn-up missions: UX consistency.
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;
sleep 2;

private _taskId = format ["tower%1%2", round (_hpPos select 0), round (_hpPos select 1)];
private _marker = [_hpPos, _radius, _taskId, localize "STR_DUWS_T_dgpqenyw", _mission_name, "destroy",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_toweroverlord", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_towercopy"]]
] call fnc_mission_present;

// Win when the row leaves DUWS_hardpoints: watch the row, not the tower object. A gone row already paid its
// bounty; the deadline covers it left standing.
waitUntil {
    sleep 5;
    (DUWS_hardpoints findIf { (_x select 0) isEqualTo _hpKey }) < 0 || time > _deadline
};

if ((DUWS_hardpoints findIf { (_x select 0) isEqualTo _hpKey }) >= 0 && time > _deadline) exitWith {
    [_mission_name, _taskId, "FAILED", _hpPos, _radius, [_marker]] call fnc_mission_finish;
};

[_mission_name, _taskId, "SUCCEEDED", _hpPos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_towerclose"], true, "mission_destroy_tower"] call fnc_mission_finish;
