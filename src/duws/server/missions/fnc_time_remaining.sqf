// In-game seconds still to run before an engine-time (`time`) target. Timed things are stored on the
// real-seconds `time` clock so the mission's many `time > deadline` checks keep working, but every
// duration is meant in in-game time, so the gap is scaled back up by the day/night multiplier for any
// display or clock maths. Negative once the target has passed; callers guard on a live target.
params ["_target"];
private _mult = missionNamespace getVariable ["time_Multiplier", 1];
if (_mult <= 0) then { _mult = 1 };
(_target - time) * _mult
