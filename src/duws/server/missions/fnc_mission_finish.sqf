// Locality: server -- mission threads call it, all server-side.
//
// The single terminal step every side mission ends through, win or lose: speak the outcome line,
// clear the markers, set the task's final state, run any per-outcome teardown, pay the reward on a
// win, and release the mission slot. It is the one place the campaign-wide invariants live -- the
// lock is released exactly once (fnc_mission_end), the reward is paid from the one table
// (DUWS_curReward), and the token sweep runs -- so a thread cannot forget one by hand-rolling its own
// tail. Every thread, and every outcome branch within it, funnels here.
//
// _status   "SUCCEEDED" or "FAILED" -- the task's final state.
// _markers  marker names to clear (the search ellipse, plus any a thread drew itself); each is
//           cleared through fnc_missionMarkerClear, which no-ops on "" or nil.
// _line     [speakerKey, msgKey] spoken (callsign-substituted) as the outcome line, or [] for none.
//           When _line is [] and the mission FAILED, the generic "out of time" notice stands in
//           unless _notify is false.
// _pay      pay DUWS_curReward (true only on the success branch).
// _notify   suppress the generic timeout notice on a silent failure (a build-time abort speaks
//           nothing); ignored when _line is non-empty.
// _extra    optional teardown or post-win side effects run after the task state is set and before the
//           reward, receiving _handles -- the objective handles the thread built.
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

// Reward args evaluated here, before fnc_mission_end reopens the slot: fnc_mission_end sets
// Mission_available true, which lets the next mission's fnc_mission_begin overwrite DUWS_curReward.
// The spawn copies the two values now, so it pays this mission's reward regardless of what starts next.
if (_pay) then {
    sleep 1;
    [DUWS_curReward select 0, DUWS_curReward select 1, _mission_name] spawn fnc_mission_reward;
};

[_tpos, _radius, _compKey, _sweep] call fnc_mission_end;
