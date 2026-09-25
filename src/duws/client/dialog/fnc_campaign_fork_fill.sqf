// Locality: client -- the load screen (fnc_campaign_fork.sqf).
lbClear 9802;
{
	_x params ["", "_pairs", "_why"];
	private _h = createHashMapFromArray _pairs;
	private _age = _h getOrDefault ["age", 0];
	private _ageText = switch (true) do {
		case (_age < 60): { format [localize "STR_DUWS_T_fork_age_min", _age max 1] };
		case (_age < 2880): { format [localize "STR_DUWS_T_fork_age_hours", floor (_age / 60)] };
		default { format [localize "STR_DUWS_T_fork_age_days", floor (_age / 1440)] };
	};
	private _i = lbAdd [9802, format [localize "STR_DUWS_T_fork_row", _h getOrDefault ["day", 1], _h getOrDefault ["world", ""],
		_h getOrDefault ["held", 0], _h getOrDefault ["zones", 0], _h getOrDefault ["cp", 0], _ageText]];
	lbSetValue [9802, _i, _forEachIndex];
	if (_why isNotEqualTo "") then { lbSetColor [9802, _i, [0.5, 0.5, 0.5, 1]] };
} forEach DUWS_saveList;
ctrlSetText [9806, ["", localize "STR_DUWS_T_fork_unreadable"] select (DUWS_saveStatus isEqualTo "unreadable")];
if (DUWS_saveList isNotEqualTo []) then { lbSetCurSel [9802, 0] };
[] call fnc_campaign_fork_select;
