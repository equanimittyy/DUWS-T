// Locality: client; the event-handler bodies below run on the machine that triggers them, not here.
/*
    fnc_open_action_menu.sqf
    Reusable list menu: one titled dialog with a selectable listbox, opened in
    place of a cluster of scroll-wheel actions.

    Call:  ["<title>", [[_label, _code, _args, _color], ...]] call fnc_open_action_menu
      _label  STRING  row text; any <t> markup is stripped (listbox rows show it
                      literally), so colour the row via _color instead
      _code   CODE    run as (_args call _code) when the row is chosen
      _args   ANY     optional, default []
      _color  ARRAY   optional [r,g,b,a] applied to the row

    Choosing a row (Select button or double-click) closes this menu *before*
    running _code, so an entry that opens its own dialog does not stack on top.
*/
if (!hasInterface) exitWith {};
params [["_title", "", [""]], ["_entries", [], [[]]]];
if (_entries isEqualTo []) exitWith {};

disableSerialization;
private _display = createDialog ["RscDisplayEmpty", false];
if (isNull _display) exitWith {};

private _bg = _display ctrlCreate ["RscText", 9500];
_bg ctrlSetPosition [0.3, 0.22, 0.4, 0.46];
_bg ctrlSetBackgroundColor [0, 0, 0, 0.7];
_bg ctrlCommit 0;

private _titleCtrl = _display ctrlCreate ["RscText", 9501];
_titleCtrl ctrlSetPosition [0.3, 0.22, 0.4, 0.05];
_titleCtrl ctrlSetText _title;
_titleCtrl ctrlSetBackgroundColor [0, 0, 0, 0.9];
_titleCtrl ctrlCommit 0;

private _lb = _display ctrlCreate ["RscListBox", 9502];
_lb ctrlSetPosition [0.31, 0.28, 0.38, 0.30];
_lb ctrlCommit 0;

// Several source strings bake in <t color=...> markup, harmless in a scroll
// action but shown as literal tags in a listbox row. Strip tags for display.
private _fnc_stripTags = {
    params ["_s"];
    while { (_s find "<") >= 0 && { (_s find ">") > (_s find "<") } } do {
        _s = (_s select [0, _s find "<"]) + (_s select [(_s find ">") + 1]);
    };
    _s
};
{
    _x params [["_label", ""], ["_code", {}], ["_args", []], ["_color", []]];
    private _i = _lb lbAdd ([_label] call _fnc_stripTags);
    if (count _color == 4) then { _lb lbSetColor [_i, _color]; };
} forEach _entries;
_lb lbSetCurSel 0;

// Entries hold CODE, which cannot ride in lbSetData (string only), so stash the
// whole list in uiNamespace; only one action menu is open at a time.
uiNamespace setVariable ["DUWS_actionMenu_entries", _entries];
uiNamespace setVariable ["DUWS_actionMenu_run", {
    params ["_idx"];
    private _entries = uiNamespace getVariable ["DUWS_actionMenu_entries", []];
    closeDialog 0;
    if (_idx < 0 || _idx >= count _entries) exitWith {};
    private _entry = _entries select _idx;
    (_entry param [2, []]) call (_entry select 1);
}];

_lb ctrlAddEventHandler ["LBDblClick", {
    (_this select 1) call (uiNamespace getVariable "DUWS_actionMenu_run");
}];

private _selectBtn = _display ctrlCreate ["RscButton", 9503];
_selectBtn ctrlSetPosition [0.31, 0.60, 0.18, 0.05];
_selectBtn ctrlSetText (localize "STR_DUWS_T_MENU_SELECT");
_selectBtn ctrlCommit 0;
_selectBtn ctrlAddEventHandler ["ButtonClick", {
    private _lb = (ctrlParent (_this select 0)) displayCtrl 9502;
    (lbCurSel _lb) call (uiNamespace getVariable "DUWS_actionMenu_run");
}];

private _closeBtn = _display ctrlCreate ["RscButton", 9504];
_closeBtn ctrlSetPosition [0.51, 0.60, 0.18, 0.05];
_closeBtn ctrlSetText (localize "STR_DUWS_T_MENU_CLOSE");
_closeBtn ctrlCommit 0;
_closeBtn ctrlAddEventHandler ["ButtonClick", { closeDialog 0; }];
