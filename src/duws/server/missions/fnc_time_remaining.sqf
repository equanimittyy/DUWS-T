// Seconds still to run before an engine-time (`time`) target. Negative once the target has passed;
// callers guard on a live target.
params ["_target"];
_target - time
