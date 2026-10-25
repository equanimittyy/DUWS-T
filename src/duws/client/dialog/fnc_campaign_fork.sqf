// Locality: client -- the game master's machine, from client_init.sqf.
if (!createDialog "duws_campaign_fork") exitWith {
	["ERROR", "SAVE", "Load screen failed to open; the server decides when its bound runs out."] call fnc_log;
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
