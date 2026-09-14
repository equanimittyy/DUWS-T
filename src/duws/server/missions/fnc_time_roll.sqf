// The shared mission-timing shape: a duration measured in whole 5-minute steps, for deadlines and
// timed triggers alike. One step is 300 s. Equal bounds are a fixed duration; a range rolls a uniform
// whole number of steps within it (inclusive), so every result is a clean 5-minute multiple.
//
// Returns seconds. Callers add it to the campaign clock (fnc_campaign_now) for a deadline target --
// DUWS_curDeadlineAt and every mission deadline are built that way (fnc_mission_begin), and so is the
// informant's leave.
params ["_minSteps", ["_maxSteps", -1]];
if (_maxSteps < _minSteps) then { _maxSteps = _minSteps };
(_minSteps + floor (random (_maxSteps - _minSteps + 1))) * 300
