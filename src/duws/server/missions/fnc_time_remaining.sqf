// Seconds still to run before a campaign-clock (fnc_campaign_now) target. Negative once the target has
// passed; callers guard on a live target.
params ["_target"];
_target - (call fnc_campaign_now)
