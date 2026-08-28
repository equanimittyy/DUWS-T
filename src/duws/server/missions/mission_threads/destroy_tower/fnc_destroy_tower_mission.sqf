// Locality: server -- callers remoteExec to target 2.
//
// Destroy an EXISTING standalone OPFOR RADIO hardpoint (a signal mast, DUWS_radioMastClass) rather than
// a spawned stand-in. The mast, its crew and its destruction bounty are all owned by the hardpoint
// streamer; this thread only points the task at one and pays the mission reward on top when it falls.
// Win is the hardpoint falling -- its DUWS_hardpoints row disappearing -- not the tower object dying:
// the mission never handles the streamer-owned mast, and a cleared row is the broadcast signal for the
// hardpoint being gone by any means (player, support, anything the streamer recognizes). The streamer
// removes the row and credits the bounty in the same step, so the two payouts stack with no coupling
// here. Off the fnc_mission_run spine -- the win watches broadcast state, not a one-shot predicate.
params ["_MissionPos", "_mission_name"];
if (!([3, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

_radius = 400;
_deadline = DUWS_curDeadlineAt;

// Nearest live OPFOR standalone RADIO mast to the anchor -- the same scan the offer's site-finder ran,
// so the two agree on which mast. Row: [key, pos, type, side, zoneKey, revealed, dir]. None left in
// reach (the mast fell in the gap between offer and launch) releases the slot and gate.
private _hpKey = "";
private _hpPos = [];
private _bestD = 2500;
{
    _x params ["_key", "_hp", "_type", "_side", "_zoneKey"];
    if (_type isEqualTo "RADIO" && {_side isEqualTo "opfor"} && {_zoneKey isEqualTo ""}) then {
        private _d = _hp distance2D _MissionPos;
        if (_d < _bestD) then { _bestD = _d; _hpKey = _key; _hpPos = _hp };
    };
} forEach DUWS_hardpoints;
if (_hpKey isEqualTo "") exitWith { [3, "STR_DUWS_T_crtzxs0j", "no_radio_hp"] call fnc_mission_abort };

// One tasking line either side of the marker/task: the mast and its crew already stand on the map, so
// there is no spawn-up to narrate.
private _taskId = format ["tower%1%2", round (_hpPos select 0), round (_hpPos select 1)];
private _marker = [_hpPos, _radius, _taskId, localize "STR_DUWS_T_dgpqenyw", _mission_name, "destroy",
    [["STR_DUWS_T_OVERLORD", "STR_DUWS_T_toweroverlord", 6], ["STR_DUWS_T_actionteam", "STR_DUWS_T_towercopy"]]
] call fnc_mission_present;

// Win when the hardpoint's row leaves DUWS_hardpoints -- watch the hardpoint's liveness, not the tower
// object. A gone row means the hardpoint fell and its bounty is already paid. Deadline covers it left up.
waitUntil {
    sleep 5;
    (DUWS_hardpoints findIf { (_x select 0) isEqualTo _hpKey }) < 0 || time > _deadline
};

if ((DUWS_hardpoints findIf { (_x select 0) isEqualTo _hpKey }) >= 0 && time > _deadline) exitWith {
    [_mission_name, _taskId, "FAILED", _hpPos, _radius, [_marker]] call fnc_mission_finish;
};

[_mission_name, _taskId, "SUCCEEDED", _hpPos, _radius, [_marker], ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_towerclose"], true, "mission_destroy_tower"] call fnc_mission_finish;
