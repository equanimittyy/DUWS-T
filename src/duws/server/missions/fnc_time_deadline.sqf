// Rolls a duration in 5-minute steps and returns it as an absolute campaign-clock (fnc_campaign_now)
// target, snapped up to the next in-game 5-minute wall-clock mark so every deadline and timed trigger
// built here reads a round "HH:MM" (14:45, not 14:42) and the fnc_time_expired checks fire on that mark.
// The roll is a clean
// 5-minute duration, but a mission starts at an arbitrary minute and the raw target inherits it. daytime
// advances 1:1 with engine seconds (the time system's standing assumption), so a clock minute is 60 s of
// target; ceil only ever adds time, never shortening the rolled run. The clock reading is invariant as
// time passes -- daytime gains what the remaining loses -- so the snap holds for the target's life.
params ["_minSteps", ["_maxSteps", -1]];
private _target = (call fnc_campaign_now) + ([_minSteps, _maxSteps] call fnc_time_roll);
private _clockMin = daytime * 60 + (_target - (call fnc_campaign_now)) / 60;
_target + (ceil (_clockMin / 5) * 5 - _clockMin) * 60
