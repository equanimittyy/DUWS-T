// Locality: server -- callers remoteExec to target 2.
//
// Destroy an EXISTING standalone OPFOR hardpoint -- any destructible type except RADIO (its own Destroy
// Signal Tower mission) and MINEFIELD (a hazard, not an emplacement) -- rather than a spawned stand-in.
// The emplacement, its crew and its destruction bounty are all owned by the hardpoint streamer; this
// thread only points the task at one and pays the mission reward on top when it falls.
//
// Win is the hardpoint falling -- its DUWS_hardpoints row disappearing -- not any one object dying: the
// streamer runs the per-type clearance test (garrison beaten, guns wrecked) and a cleared row is the
// broadcast signal that the emplacement is gone by any means. The streamer removes the row and credits the
// bounty in the same step, so the two payouts stack with no coupling here. Off the fnc_mission_run spine --
// the win watches broadcast state, not a one-shot predicate.
params ["_MissionPos", "_mission_name"];
if (!([17, _MissionPos, _mission_name, remoteExecutedOwner] call fnc_mission_begin)) exitWith {};

_radius = 400;
_cpreward = DUWS_curReward select 0;
_apreward = DUWS_curReward select 1;
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
if (_hpKey isEqualTo "") exitWith { [17, "STR_DUWS_T_crtzxs0j", "no_hardpoint"] call fnc_mission_abort };

_markername2 = [_hpPos, _radius] call fnc_missionMarkerData;
private _VARtaskgeneratedName = format ["hp%1%2", round (_hpPos select 0), round (_hpPos select 1)];
[_VARtaskgeneratedName, localize "STR_DUWS_T_DESTROY_HARDPOINT_DESC", _mission_name, _hpPos, "destroy"] call fnc_missionTaskCreate;

[localize "STR_DUWS_T_c17", {hint _this}] remoteExec ["BIS_fnc_Spawn", [0,-2] select isDedicated];

// One tasking line: the emplacement and its crew already stand on the map, so there is no spawn-up to narrate.
[localize "STR_DUWS_T_OVERLORD", localize "STR_DUWS_T_hardpointoverlord"] remoteExec ["fnc_duws_dialogue", 0];

// Win when the hardpoint's row leaves DUWS_hardpoints -- watch the hardpoint's liveness, not any one
// object. A gone row means it fell and its bounty is already paid. Deadline covers it left standing.
waitUntil {
    sleep 5;
    (DUWS_hardpoints findIf { (_x select 0) isEqualTo _hpKey }) < 0 || time > _deadline
};

if ((DUWS_hardpoints findIf { (_x select 0) isEqualTo _hpKey }) >= 0 && time > _deadline) exitWith {
    [_VARtaskgeneratedName, _markername2, "", _hpPos, _radius, false, ["STR_DUWS_T_OVERLORD", "STR_DUWS_T_hardpointfail"]] call fnc_mission_deadline_fail;
};

[_markername2] call fnc_missionMarkerClear;
[_VARtaskgeneratedName, "SUCCEEDED"] call fnc_missionTaskEnd;
[_cpreward, _apreward, _mission_name] spawn fnc_mission_reward;
[_hpPos, _radius, "mission_destroy_hardpoint"] call fnc_mission_end;
