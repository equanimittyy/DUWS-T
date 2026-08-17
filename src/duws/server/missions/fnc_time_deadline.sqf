// Rolls a duration in 10-minute steps and returns it as an absolute engine-time (`time`) target, snapped
// up to the next in-game 10-minute wall-clock mark so every deadline and timed trigger built here reads a
// round "HH:MM" (14:40, not 14:32) and the `time > target` checks fire on that mark. The roll is a clean
// 10-minute duration, but a mission starts at an arbitrary minute and the raw target inherits it. daytime
// advances 1:1 with engine seconds (the time system's standing assumption), so a clock minute is 60 s of
// target; ceil only ever adds time, never shortening the rolled run. The clock reading is invariant as
// time passes -- daytime gains what the remaining loses -- so the snap holds for the target's life.
params ["_minSteps", ["_maxSteps", -1]];
private _target = time + ([_minSteps, _maxSteps] call fnc_time_roll);
private _clockMin = daytime * 60 + (_target - time) / 60;
_target + (ceil (_clockMin / 10) * 10 - _clockMin) * 60
