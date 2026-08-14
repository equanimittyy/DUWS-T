// Formats an absolute playtime target (seconds, the form DUWS_curDeadlineAt holds) as an in-game wall
// clock "HH:MM". daytime is taken to advance 1:1 with engine seconds -- the same assumption the
// deadline is built on, tolerated because a >1 time multiplier is the exception -- so the seconds
// still to run convert straight onto the current clock.
//
// Rounds to whole minutes before splitting h:mm: flooring the raw fractional hour lands a minute short
// whenever it sits just under an integer (x.999 h would read one minute early).
params ["_target"];
private _clock = (daytime + (_target - time) / 3600) mod 24;
private _totalMin = round (_clock * 60);
private _h = (floor (_totalMin / 60)) mod 24;
private _m = _totalMin mod 60;
private _pad = { if (_this < 10) then { "0" + str _this } else { str _this } };
format ["%1:%2", _h call _pad, _m call _pad]
