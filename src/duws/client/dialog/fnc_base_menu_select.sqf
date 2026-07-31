// Locality: client -- a dialog button action, so it runs on whoever pressed it.
/*
    fnc_base_menu_select.sqf
    Runs the BASE row the player picked. The dialog closes before the row's code runs,
    matching fnc_open_action_menu: several rows open a dialog of their own, which would
    otherwise stack on top of the request menu.
*/
private _sel = lbCurSel 2104;
private _rows = uiNamespace getVariable ["DUWS_baseMenu_rows", []];
if (_sel < 0 || {_sel >= count _rows}) exitWith {};

private _row = _rows select _sel;
closeDialog 0;
(_row select 2) call (_row select 1);
