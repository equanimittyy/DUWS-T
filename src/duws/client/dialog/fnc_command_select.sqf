// Locality: client -- a dialog button action, so it runs on whoever pressed it.
/*
    fnc_command_select.sqf
    Runs the COMMAND AND CONTROL entry whose slot the player pressed. The dialog closes before
    the entry's code runs, matching fnc_open_action_menu: several entries open a dialog of their
    own, which would otherwise stack on top of the request menu.

    The slot index is the argument rather than a listbox selection: the column is seven buttons,
    each carrying its own index in its action string.

    Those actions spawn this rather than calling it, which is load-bearing: three entries open a
    dialog and then `waitUntil {dialog}`, which throws unscheduled.
*/
params [["_slot", -1]];
private _rows = uiNamespace getVariable ["DUWS_commandMenu_rows", []];
if (_slot < 0 || {_slot >= count _rows}) exitWith {};

private _row = _rows select _slot;
closeDialog 0;
(_row select 2) call (_row select 1);
