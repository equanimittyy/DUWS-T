// Locality: client -- inherited from client/client_init.sqf. The roster is the server's
// (server/operative/fnc_operator_roster.sqf); a client only asks it for changes and repaints.

"duws_operator_list" addPublicVariableEventHandler {
	if (!isNull (uiNamespace getVariable ["duws_operative_display", displayNull])) then { [] call fnc_lbselected };
};

// The tests here only pick the hint; the server tests again.
DUWS_operator_add = {
	params ["_stat"];
	private _i = lbCurSel 1500;
	private _row = duws_operator_list select _i;
	if ((_row select 13) <= 0) exitWith {hint localize "STR_DUWS_T_operative_no_points"};
	if ((_row select _stat) >= 1) exitWith {hint localize "STR_DUWS_T_operative_stat_max"};
	[_i, _stat] remoteExecCall ["DUWS_fnc_operatorSpend", 2];
	hint localize "STR_DUWS_T_operative_stats_next_deploy";
};
