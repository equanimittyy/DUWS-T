// Locality: client -- a dialog button action, so it runs on whoever pressed it.
/*
    Runs the COMMAND AND CONTROL entry whose slot the player pressed.

    The menu closes first only for an entry that says so, which is the four that open a dialog of
    their own -- those would otherwise stack on top of the request menu. Everything else spends,
    hints and leaves the menu standing, because a player buying two things in a row should not have
    to walk back to the prop between them.

    The slot index is the argument rather than a listbox selection: the column is seven buttons,
    each carrying its own index in its action string.

    Those actions spawn this rather than calling it, which is load-bearing: an entry that fills a
    dialog waits on it with `waitUntil {dialog}`, which throws unscheduled.
*/
params [["_slot", -1]];
private _rows = uiNamespace getVariable ["DUWS_commandMenu_rows", []];
if (_slot < 0 || {_slot >= count _rows}) exitWith {};

private _row = _rows select _slot;
if (_row param [3, false]) then { closeDialog 0 };
(_row select 2) call (_row select 1);
