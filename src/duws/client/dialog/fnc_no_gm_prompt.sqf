// Locality: client. Opened on every interface machine by the server's Game Master watchdog
// (server/server_init.sqf) when slot 1 is unmanned. That slot alone drives faction/HQ setup, so
// with it empty the campaign never generates and the player is left on a forced map behind which
// no menu can open -- this button is the only way out short of killing the process. No Cancel: a
// dismissable prompt would just strand the player again with no way to bring it back.
if (!hasInterface) exitWith {};
disableSerialization;

private _display = createDialog ["RscDisplayEmpty", false];
if (isNull _display) exitWith {};

private _bg = _display ctrlCreate ["RscText", 9600];
_bg ctrlSetPosition [0.3, 0.4, 0.4, 0.2];
_bg ctrlSetBackgroundColor [0, 0, 0, 0.85];
_bg ctrlCommit 0;

private _txt = _display ctrlCreate ["RscStructuredText", 9601];
_txt ctrlSetPosition [0.31, 0.42, 0.38, 0.09];
_txt ctrlSetStructuredText parseText format ["<t align='center' size='1.1'>%1</t><br/><t align='center'>%2</t>",
    localize "STR_DUWS_T_NO_GM_TITLE", localize "STR_DUWS_T_NO_GM_MSG"];
_txt ctrlCommit 0;

private _btn = _display ctrlCreate ["RscButton", 9602];
_btn ctrlSetPosition [0.38, 0.53, 0.24, 0.05];
_btn ctrlSetText (localize "STR_DUWS_T_NO_GM_ABORT_BTN");
_btn ctrlSetBackgroundColor [0.6, 0.1, 0.1, 1];
_btn ctrlAddEventHandler ["ButtonClick", {
    closeDialog 0;
    // Local end (not the ...Server variant): drops only the machine that clicked back to the
    // lobby, so one player's abort cannot end a session a late-joining Game Master could rescue.
    ["setup_aborted", false] call BIS_fnc_endMission;
}];
_btn ctrlCommit 0;
