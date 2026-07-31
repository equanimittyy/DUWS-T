// Locality: client -- called from the request dialog, so it runs on whoever opened it.
/*
    fnc_command_fill.sqf
    Fills the COMMAND AND CONTROL button column. One builder for the HQ and every FOB, since a FOB
    carries the same command set minus what only the HQ has.

    The dividing line against the scroll wheel is who needs it and how fast: anything a player
    reaches for without asking command sits on the prop it belongs to instead.

    An entry that cannot apply is absent rather than greyed, which is why request_menu.hpp declares
    numbered slots with no text: applicable entries are written in from the top down and the rest
    hidden, so a missing one leaves no hole. Overflow is a layout error, so it is logged.

    Row shape: [label, code, args], stashed for fnc_command_select because a control's action is a
    string and CODE cannot ride in the button.
*/

if (!hasInterface) exitWith {};

// _display is passed because the dialog is declared idd = -1, so there is no id to find it by.
// _site is the base the menu was opened on, which the FOB redeploy needs.
params [["_display", displayNull], ["_site", objNull], ["_isFob", false]];
if (isNull _display) exitWith {};

// The seven button IDCs in request_menu.hpp, in column order.
private _slots = [1610, 1611, 1612, 1613, 1614, 1615, 1616];
private _rows = [];

if ((vehiclevarname player) in Squad_Leaders) then {
    _rows pushBack [localize "STR_DUWS_T_l0xark5g", { [] call fnc_squad_manage }, []];
};

_rows pushBack [localize "STR_DUWS_T_iggpsdqo", { [] call fnc_FOBmanager }, []];

// Last of the three, for the reason the scroll bucket put it lowest: a mis-clicked spend costs
// more than an entry one line further down.
if (_isFob) then {
    _rows pushBack [localize "STR_DUWS_T_REDEPLOY_ACTION", { _this call fnc_redeployFOB }, [_site]];
} else {
    _rows pushBack [localize "STR_DUWS_T_REDEPLOY_ACTION", {
        // Advisory only; fnc_redeployHQUnits checks and charges on the server.
        if (commandpointsblu1 < 2) exitWith { hint format [localize "STR_DUWS_T_REDEPLOY_NO_CP", 2]; };
        [player] remoteExec ["fnc_redeployHQUnits", 2];
    }, []];
};

_rows pushBack [localize "STR_DUWS_T_0dlbonpc", { [] call fnc_operator_open }, []];

// HQ only: these three came off the HQ terminal, which a FOB does not have.
if (!_isFob) then {
    _rows pushBack [localize "STR_DUWS_T_HIRE_PARTISANS", { [player] remoteExec ["fnc_hirePartisans", 2] }, []];
    _rows pushBack [localize "STR_DUWS_T_HIRE_PMC", { [player] remoteExec ["fnc_hirePMC", 2] }, []];
    _rows pushBack [localize "STR_DUWS_T_INTEL_ANALYSIS_ACTION", { [player] remoteExec ["fnc_intelAnalysis", 2] }, []];
};

if (count _rows > count _slots) then {
    ["WARN", "UI", format ["fnc_command_fill: %1 entries for %2 slots, the surplus is not shown",
        count _rows, count _slots]] call fnc_log;
};

{
    private _ctrl = _display displayCtrl _x;
    if (_forEachIndex < count _rows) then {
        _ctrl ctrlSetText ((_rows select _forEachIndex) select 0);
        _ctrl ctrlShow true;
    } else {
        _ctrl ctrlShow false;
    };
} forEach _slots;

// uiNamespace, not missionNamespace: rows hold CODE, which is not serializable, and the
// mission namespace is written into save games.
uiNamespace setVariable ["DUWS_commandMenu_rows", _rows];
