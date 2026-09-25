// Locality: client -- the load screen's buttons. Spawned: the confirmations block.
params ["_action"];
private _sel = lbCurSel 9802;
private _row = if (_sel < 0) then { [] } else { DUWS_saveList param [lbValue [9802, _sel], []] };
private _fnc_lock = { { ctrlEnable [_x, false] } forEach [9807, 9808, 9809, 9810, 9811] };

switch (_action) do {
	case "new": {
		if (DUWS_saveStatus isEqualTo "unreadable"
			&& {!([localize "STR_DUWS_T_fork_unreadable_confirm", localize "STR_DUWS_T_fork_frame", true, true] call BIS_fnc_guiMessage)}) exitWith {};
		call _fnc_lock;
		[[]] remoteExec ["DUWS_fnc_saveChoose", 2];
	};
	case "load": {
		if (_row isEqualTo [] || {(_row select 2) isNotEqualTo ""}) exitWith {};
		call _fnc_lock;
		[[_row select 0, false]] remoteExec ["DUWS_fnc_saveChoose", 2];
	};
	case "delete": {
		if (_row isEqualTo []) exitWith {};
		if !([format [localize "STR_DUWS_T_fork_delete_confirm", lbText [9802, _sel]], localize "STR_DUWS_T_fork_frame", true, true] call BIS_fnc_guiMessage) exitWith {};
		[_row select 0] remoteExec ["DUWS_fnc_saveDeleteRequest", 2];
	};
	case "import": {
		private _json = ctrlText 9805;
		if (_json isEqualTo "") then { _json = (profileNamespace getVariable ["DUWST_carry", ["", ""]]) param [1, ""] };
		if (_json isEqualTo "") exitWith { hint localize "STR_DUWS_T_fork_import_empty" };
		ctrlSetText [9805, ""];
		[_json] remoteExec ["DUWS_fnc_saveImport", 2];
	};
	case "export": {
		if (_row isEqualTo []) exitWith {};
		[_row select 0] remoteExec ["DUWS_fnc_saveExport", 2];
	};
};
