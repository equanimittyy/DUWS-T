// Formats a [minH, maxH] deadline window as the briefing "Time:" line; equal bounds collapse to a fixed
// clock. Hours are decimal (0.6667 = 40 min). Shared by the map picker and the journal so they can't drift.
params ["_minH", "_maxH"];
private _fmtHM = {
	private _m = round (_this * 60);
	private _mm = _m mod 60;
	format ["%1h%2", floor (_m / 60), [str _mm, "0" + str _mm] select (_mm < 10)]
};
if (_minH >= _maxH)
	then { format [localize "STR_DUWS_T_mission_time_fixed", _minH call _fmtHM] }
	else { format [localize "STR_DUWS_T_mission_time_range", _minH call _fmtHM, _maxH call _fmtHM] }
