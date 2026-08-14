// Rolls a duration in 10-minute steps and returns it as an absolute engine-time (`time`) target,
// so the existing `time > deadline` checks fire after that much time has passed.
params ["_minSteps", ["_maxSteps", -1]];
time + ([_minSteps, _maxSteps] call fnc_time_roll)
