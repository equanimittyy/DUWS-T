// Locality: server. The Intelligence Center's recon tasking has its own slot (DUWS_intelRecon_live), so it runs
// beside the HQ mission and never touches its lock, gate or reward globals. The roll claims the slot; every exit
// here frees it.

// The HQ mission's reach, so a tasking lands where an HQ recon offer could.
private _targets = (["ALL"] call fnc_recon_observe_pick) select {
    (_x distance2D PosOfBLUHQ) > 1500 && {(_x distance2D PosOfBLUHQ) < (zones_max_dist_from_hq * 1.5)}
};
private _pick = [];
private _overwatch = [];
{
    _pick = [_x] call fnc_recon_observe_pick;
    _overwatch = [_pick] call fnc_recon_observe_overwatch;
    if (_overwatch isNotEqualTo []) exitWith {};
} forEach (_targets call BIS_fnc_arrayShuffle);
if (_overwatch isEqualTo []) exitWith {
    DUWS_intelRecon_live = false;
    ["DEBUG", "INTEL", format ["recon tasking dropped: no target with an overwatch among %1", count _targets]] call fnc_log;
};

// Paid and timed from the HQ recon row, so the two jobs never drift apart.
private _defs = [
#include "..\..\..\..\shared\includes\mission_types.hpp"
];
(_defs select 12) params ["", "", "", "", "", "", "_cp", "_ap", "", "_band"];
private _deadline = [round ((_band select 0) * 12), round ((_band select 1) * 12)] call fnc_time_deadline;

private _title = format ["%1: %2", localize "STR_DUWS_T_allseer", localize "STR_DUWS_T_c12"];
private _taskId = format ["intel_recon_%1", round time];
private _desc = localize "STR_DUWS_T_RECON_OBSERVE_TASK"
    + "<br />" + format [localize "STR_DUWS_T_mission_deadline_desc", [_deadline] call fnc_time_clock]
    + "<br />" + localize "STR_DUWS_T_mission_divider"
    + format [localize "STR_DUWS_T_mission_cpap", _cp, _ap]
    + (_band call fnc_time_band);
// Server-side, never remoteExec'd (arma_engine_gotchas.md). "CREATED" leaves the HQ mission the current task.
[west, [_taskId], [_desc, _title, ""], _overwatch select [0, 2], "CREATED", 1, true, "scout", false] call BIS_fnc_taskCreate;
["INFO", "INTEL", format ["recon tasking on %1 %2, overwatch %3", _pick select 0, _pick select 1, _overwatch]] call fnc_log;

private _won = ["intel", _pick, _overwatch, _deadline, ["STR_DUWS_T_allseer", "STR_DUWS_T_INTEL_RECON_FLAG"]] call fnc_recon_observe_run;
[_taskId, ["FAILED", "SUCCEEDED"] select _won] call fnc_missionTaskEnd;
if (_won) then { [_cp, _ap, _title] spawn fnc_mission_reward } else { call fnc_mission_timeout_notice };
DUWS_intelRecon_live = false;
