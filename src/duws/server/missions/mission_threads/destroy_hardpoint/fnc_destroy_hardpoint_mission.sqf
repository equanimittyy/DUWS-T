// Locality: server -- callers remoteExec to target 2.
// Points the task at an EXISTING OPFOR hardpoint -- any destructible type except RADIO (its own mission)
// and MINEFIELD -- owned by the hardpoint streamer; this thread only tasks it and pays the mission reward
// on top. The streamer owns the emplacement, its crew and its own bounty, so the two payouts stack here.
params ["_MissionPos", "_mission_name"];
if (!([16, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

_radius = 400;
_deadline = DUWS_curDeadlineAt;

// Nearest live, revealed OPFOR standalone hardpoint of a destructible type to the anchor -- the same scan
// the offer's site-finder ran, so the two agree on which one. Row: [key, pos, type, side, zoneKey,
// revealed, dir]. None left in reach (it fell in the gap between offer and launch) releases the slot.
private _hpKey = "";
private _hpPos = [];
private _bestD = 2500;
{
    _x params ["_key", "_hp", "_type", "_side", "_zoneKey", "_revealed"];
    if (
        !(_type in ["RADIO", "MINEFIELD"])
        && {_side isEqualTo "opfor"}
        && {_zoneKey isEqualTo ""}
        && {_revealed}
    ) then {
        private _d = _hp distance2D _MissionPos;
        if (_d < _bestD) then { _bestD = _d; _hpKey = _key; _hpPos = _hp };
    };
} forEach DUWS_hardpoints;
if (_hpKey isEqualTo "") exitWith { [16, "STR_DUWS_T_crtzxs0j", "no_hardpoint"] call fnc_mission_abort };

// One tasking line either side of the marker/task: the emplacement and its crew already stand on the
// map, so there is no spawn-up to narrate.
private _taskId = format ["hp%1%2", round (_hpPos select 0), round (_hpPos select 1)];
private _marker = [_hpPos, _radius, _taskId, localize "STR_DUWS_T_DESTROY_HARDPOINT_DESC", _mission_name, "destroy",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_hardpointoverlord", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_hardpointcopy"]]
] call fnc_mission_present;

// Win when the hardpoint's row leaves DUWS_hardpoints -- watch the hardpoint's liveness, not any one
// object. A gone row means it fell and its bounty is already paid. Deadline covers it left standing.
waitUntil {
    sleep 5;
    (DUWS_hardpoints findIf { (_x select 0) isEqualTo _hpKey }) < 0 || time > _deadline
};

if ((DUWS_hardpoints findIf { (_x select 0) isEqualTo _hpKey }) >= 0 && time > _deadline) exitWith {
    [_mission_name, _taskId, "FAILED", _hpPos, _radius, [_marker]] call fnc_mission_finish;
};

[_mission_name, _taskId, "SUCCEEDED", _hpPos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_hardpointclose"], true, "mission_destroy_hardpoint"] call fnc_mission_finish;
