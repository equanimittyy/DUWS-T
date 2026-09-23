// Locality: client -- called from the request dialog, so it runs on whoever opened it.
/*
    Fills the COMMAND AND CONTROL button column -- one builder for the HQ and every FOB, since a FOB
    carries the same command set minus what only the HQ has. What lives here vs the scroll wheel is
    whoever needs it without asking command.

    An entry that cannot apply is absent, not greyed: request_menu.hpp declares numbered slots with
    no text, applicable entries are written in top-down and the rest hidden, so a missing one leaves
    no hole. Overflow is a layout error and is logged.

    Row shape: [label, code, args, closes, colour], stashed for fnc_command_select because a control's
    action is a string and CODE cannot ride in the button.

    `closes` is set only on the four entries that open a dialog of their own, which would otherwise
    stack on this one; everything else leaves the menu up, so buying two things in a row needs no walk
    back to the HQ prop. `colour` marks what an entry costs -- orange is the same "costs money, not
    yet yours" signal the supports catalogue paints unbought permanents with. The garbage cleanup is
    free but wears it too: it deletes world state for every player and cannot be undone.
*/
#define COST_COLOUR [1, 0.502, 0, 1]

if (!hasInterface) exitWith {};

// _display is passed because the dialog is declared idd = -1, so there is no id to find it by.
// _site is the base the menu was opened on, which the FOB redeploy needs.
params [["_display", displayNull], ["_site", objNull], ["_isFob", false]];
if (isNull _display) exitWith {};

// The seven button IDCs in request_menu.hpp, in column order.
private _slots = [1610, 1611, 1612, 1613, 1614, 1615, 1616];
private _rows = [];

if ((vehiclevarname player) in Squad_Leaders) then {
    _rows pushBack [localize "STR_DUWS_T_l0xark5g", { [] call fnc_squad_manage }, [], true];
};

_rows pushBack [localize "STR_DUWS_T_iggpsdqo", { [] call fnc_FOBmanager }, [], true];

_rows pushBack [localize "STR_DUWS_T_0dlbonpc", { [] call fnc_operator_open }, [], true];

_rows pushBack [localize "STR_DUWS_T_uwdgfnbc", { [] call fnc_fast_travel }, [], true];

// HQ only: a FOB is a forward post with nobody to hand the take to.
if (!_isFob) then {
    _rows pushBack [localize "STR_DUWS_T_INTEL_ANALYSIS_ACTION", { [player] remoteExec ["fnc_intelAnalysis", 2] }, []];
};

// Game Master only, as rest is: one press deletes litter the whole team may still want.
if ((vehiclevarname player) in game_master) then {
    _rows pushBack [localize "STR_DUWS_T_GARBAGE_CLEANUP_ACTION", {
        if !([localize "STR_DUWS_T_GARBAGE_CLEANUP_CONFIRM", localize "STR_DUWS_T_GARBAGE_CLEANUP_ACTION",
            true, true] call BIS_fnc_guiMessage) exitWith {};
        [] remoteExec ["fnc_duws_forceCleanup", 2];
        hint localize "STR_DUWS_T_GARBAGE_CLEANUP_STARTED";
    }, [], false, COST_COLOUR];
};

// Below the free entries, for the reason the scroll bucket put it lowest: a mis-clicked spend costs
// more than an entry one line further down.
if (_isFob) then {
    _rows pushBack [localize "STR_DUWS_T_REDEPLOY_ACTION", { _this call fnc_redeployFOB }, [_site], false, COST_COLOUR];
} else {
    _rows pushBack [localize "STR_DUWS_T_REDEPLOY_ACTION", {
        // Advisory only; fnc_redeployHQUnits checks and charges on the server.
        if (commandpointsblu1 < 2) exitWith { hint format [localize "STR_DUWS_T_REDEPLOY_NO_CP", 2]; };
        [player] remoteExec ["fnc_redeployHQUnits", 2];
    }, [], false, COST_COLOUR];
};

if (count _rows > count _slots) then {
    ["WARN", "UI", format ["fnc_command_fill: %1 entries for %2 slots, the surplus is not shown",
        count _rows, count _slots]] call fnc_log;
};

{
    private _ctrl = _display displayCtrl _x;
    if (_forEachIndex < count _rows) then {
        private _row = _rows select _forEachIndex;
        _ctrl ctrlSetText (_row select 0);
        _ctrl ctrlSetTextColor (_row param [4, [0.8784, 0.8471, 0.651, 1]]);
        _ctrl ctrlShow true;
    } else {
        _ctrl ctrlShow false;
    };
} forEach _slots;

// uiNamespace, not missionNamespace: rows hold CODE, which is not serializable, and the
// mission namespace is written into save games.
uiNamespace setVariable ["DUWS_commandMenu_rows", _rows];
