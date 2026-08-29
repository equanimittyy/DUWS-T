// Locality: server -- mission threads call it, all server-side.
//
// The single terminal step every side mission ends through, win or lose: speak the outcome line, clear
// markers, set the task state, run per-outcome teardown, pay the reward on a win, release the slot. It is
// where the campaign-wide invariants live (lock released once via fnc_mission_end, reward paid from the
// one table, token sweep run), so no thread hand-rolls its own tail.
//
// _line is [speakerKey, msgKey] or [] for none; when [] on a FAILED mission the generic "out of time"
// notice stands in unless _notify is false. _extra runs after the task state is set and before the reward,
// receiving _handles (the objective handles the thread built).
params [
    "_mission_name", "_taskId", "_status", "_tpos", "_radius",
    ["_markers", []], ["_line", []], ["_pay", false], ["_compKey", ""], ["_sweep", false],
    ["_notify", true], ["_extra", {}], ["_handles", []]
];
if (!isServer) exitWith {};

if (!(_line isEqualTo [])) then {
    _line params ["_spk", "_msg"];
    [localize _spk, [localize _msg] call fnc_cs] remoteExec ["fnc_duws_dialogue", 0];
} else {
    if (_status isEqualTo "FAILED" && _notify) then { call fnc_mission_timeout_notice };
};

{ [_x] call fnc_missionMarkerClear } forEach _markers;
[_taskId, _status] call fnc_missionTaskEnd;
_handles call _extra;

// Reward args evaluated now, before fnc_mission_end reopens the slot and the next fnc_mission_begin can
// overwrite DUWS_curReward. The spawn copies the two values here, so it pays this mission's reward.
if (_pay) then {
    sleep 1;
    [DUWS_curReward select 0, DUWS_curReward select 1, _mission_name] spawn fnc_mission_reward;
};

[_tpos, _radius, _compKey, _sweep] call fnc_mission_end;
