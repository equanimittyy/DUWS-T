// Locality: client -- the game master's machine, from client_init.sqf.
if (!createDialog "duws_campaign_fork") exitWith {
	["ERROR", "SAVE", "Load screen failed to open; the server decides when its bound runs out."] call fnc_log;
};
// Only a dedicated server with DUWS_DediAutoload on reads the mark, and there the load screen is on a client.
if (isServer || {(["DUWS_DediAutoload", 0] call BIS_fnc_getParamValue) != 1}) then {
	private _display = uiNamespace getVariable "DUWS_forkDisplay";
	private _list = _display displayCtrl 9802;
	private _button = _display displayCtrl 9819;
	(ctrlPosition _list) params ["_lx", "_ly", "_lw"];
	(ctrlPosition _button) params ["", "_by", "", "_bh"];
	_button ctrlShow false;
	_list ctrlSetPosition [_lx, _ly, _lw, _by + _bh - _ly];
	_list ctrlCommit 0;
};
private _shown = +DUWS_saveList;
[] call fnc_campaign_fork_fill;
// Refilled on change rather than from a broadcast handler, which never fires on the host for its own broadcast.
while { DUWS_setupPhase isEqualTo "choose" } do {
	if !(DUWS_saveList isEqualTo _shown) then {
		_shown = +DUWS_saveList;
		[] call fnc_campaign_fork_fill;
	};
	sleep 0.25;
};
// An open params dialog would take the closeDialog and leave the load screen up.
(uiNamespace getVariable ["DUWS_forkParamsDisplay", displayNull]) closeDisplay 2;
closeDialog 0;
