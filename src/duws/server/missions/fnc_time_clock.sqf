// Formats an absolute engine-time target (the form DUWS_curDeadlineAt holds) as the in-game wall clock
// "HH:MM" it falls on. The gap to the target is in-game seconds (fnc_time_remaining scales it by the
// day/night multiplier), so the clock is correct at any multiplier, not just 1x.
//
// Rounds to whole minutes before splitting h:mm: flooring the raw fractional hour lands a minute short
// whenever it sits just under an integer (x.999 h would read one minute early).
params ["_target"];
private _clock = (daytime + ([_target] call fnc_time_remaining) / 3600) mod 24;
private _totalMin = round (_clock * 60);
private _h = (floor (_totalMin / 60)) mod 24;
private _m = _totalMin mod 60;
private _pad = { if (_this < 10) then { "0" + str _this } else { str _this } };
format ["%1:%2", _h call _pad, _m call _pad]
