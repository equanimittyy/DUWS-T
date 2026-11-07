// Locality: client -- the load screen (fnc_campaign_fork.sqf).
// The selection is kept by campaign ID across a refill, so marking AUTO-LOAD does not jump the cursor to the top.
private _cur = lbCurSel 9802;
private _keep = if (_cur < 0) then { "" } else { lbData [9802, _cur] };
private _sel = 0;
lbClear 9802;
{
	_x params ["_id", "_pairs", "_why"];
	private _h = createHashMapFromArray _pairs;
	private _age = _h getOrDefault ["age", 0];
	private _ageText = switch (true) do {
		case (_age < 60): { format [localize "STR_DUWS_T_fork_age_min", _age max 1] };
		case (_age < 2880): { format [localize "STR_DUWS_T_fork_age_hours", floor (_age / 60)] };
		default { format [localize "STR_DUWS_T_fork_age_days", floor (_age / 1440)] };
	};
	private _text = format [localize "STR_DUWS_T_fork_row", _h getOrDefault ["day", 1], _h getOrDefault ["world", ""],
		_h getOrDefault ["held", 0], _h getOrDefault ["zones", 0], _h getOrDefault ["cp", 0], _ageText];
	if (_h getOrDefault ["auto", false]) then { _text = (localize "STR_DUWS_T_fork_auto_tag") + " " + _text };
	private _i = lbAdd [9802, _text];
	lbSetValue [9802, _i, _forEachIndex];
	lbSetData [9802, _i, _id];
	if (_id isEqualTo _keep) then { _sel = _i };
	if (_why isNotEqualTo "") then { lbSetColor [9802, _i, [0.5, 0.5, 0.5, 1]] };
} forEach DUWS_saveList;
private _gm = missionNamespace getVariable ["DUWS_autoloadSkippedBy", ""];
ctrlSetText [9806, switch (true) do {
	case (DUWS_saveStatus isEqualTo "unreadable"): { localize "STR_DUWS_T_fork_unreadable" };
	case (_gm isNotEqualTo ""): { format [localize "STR_DUWS_T_fork_auto_skipped", _gm] };
	default { "" };
}];
if (DUWS_saveList isNotEqualTo []) then { lbSetCurSel [9802, _sel] };
[] call fnc_campaign_fork_select;
