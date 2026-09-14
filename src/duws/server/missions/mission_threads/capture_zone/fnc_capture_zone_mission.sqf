// Locality: server -- callers remoteExec to target 2.
// Tasks an EXISTING OPFOR-held zone and pays a bonus on top of the zone's own liberation reward
// (fnc_captured) when the player takes it: spawns nothing, so the two payouts stack uncoupled.
params ["_MissionPos", "_mission_name"];
private _requester = remoteExecutedOwner;
if (!([22, _MissionPos, _mission_name, _requester] call fnc_mission_begin)) exitWith {};

_deadline = DUWS_curDeadlineAt;

// Re-validate through the finder (vet mode) so launch reads the same filter the picker offered on. A
// zone taken between offer and launch resolves to the nearest still-OPFOR zone, or none.
private _site = [_MissionPos] call fnc_capture_zone_site;
if (_site isEqualTo []) exitWith { [22, _requester, "no_opfor_zone"] call fnc_mission_abort };
_site params ["_zonePos", "_radius"];

// Nothing to build -- the zone stands. Hold the generating beat anyway (cosmetic) so a present-only
// mission reads survey -> generating -> complete like the spawn-up ones.
[_requester, "STR_DUWS_T_MISSION_GEN_BUILD"] call fnc_mission_notice;
sleep 2;

private _taskId = format ["cz%1%2", round (_zonePos select 0), round (_zonePos select 1)];
private _marker = [_zonePos, _radius, _taskId, localize "STR_DUWS_T_CAPTURE_ZONE_DESC", _mission_name, "attack"] call fnc_mission_present;

// Overlord line spoken here, not via present's _brief: it takes two subs (zone name, place) where
// present formats only the place. Name from zone_namePOS_pairs by centre, place-name fallback.
private _place = [_zonePos] call fnc_place_name;
private _known = missionNamespace getVariable ["zone_namePOS_pairs", []];
private _zi = _known findIf { ((_x select 1) distance2D _zonePos) < 1 };
private _zoneName = if (_zi >= 0) then { (_known select _zi) select 0 } else { _place };
[localize "STR_DUWS_T_OVERLORD", [format [localize "STR_DUWS_T_capturezoneoverlord", _zoneName, _place]] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
sleep 6;
[localize "STR_DUWS_T_actionteam", [localize "STR_DUWS_T_capturezonecopy"] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];

// Win when the zone enters BLUFOR control (fnc_captured records its centre there), matched by centre
// on a sub-metre distance -- float identity. Deadline covers it left OPFOR-held.
waitUntil {
    sleep 5;
    (WARCOM_zones_controled_by_BLUFOR findIf { (_x distance2D _zonePos) < 1 }) >= 0 || [_deadline] call fnc_time_expired
};

if ((WARCOM_zones_controled_by_BLUFOR findIf { (_x distance2D _zonePos) < 1 }) < 0 && [_deadline] call fnc_time_expired) exitWith {
    [_mission_name, _taskId, "FAILED", _zonePos, _radius, [_marker]] call fnc_mission_finish;
};

[_mission_name, _taskId, "SUCCEEDED", _zonePos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_capturezoneclose"], true] call fnc_mission_finish;
