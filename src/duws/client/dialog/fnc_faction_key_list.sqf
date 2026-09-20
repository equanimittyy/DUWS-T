// Locality: client -- called by fnc_faction_key_edit once the list dialog is open for a vehicle key.
//
// The role's list, edited as a record (shared/faction_lib/fnc_faction_lists.sqf) rather than as the
// list itself. CONFIRM writes the record to duws_faction_edits and the resolved list to the table row;
// CANCEL drops the working record.

#define NO_EDITS ["", [], []]
#define LIST_CTRLS [8623, 8625, 8629, 8630, 8632, 8633, 8634, 8635, 8636, 8637]

private _key = duws_faction_edit_key;
duws_faction_list_record = (uiNamespace getVariable ["duws_faction_edits", createHashMap]) getOrDefault [_key, NO_EDITS];
// The pool the server built before the screen: the base of a record with no main, and the same value
// the server reads at the commit.
duws_faction_list_current = (createHashMapFromArray (missionNamespace getVariable ["DUWS_factionPreviewPools", []]))
    getOrDefault [_key, missionNamespace getVariable [_key, ""]];

// A main's base is its bucket in the server's config, so that branch blocks on the server: only
// scheduled callers ever set a main.
duws_faction_list_rebase = {
    duws_faction_list_base = if ((duws_faction_list_record select 0) isEqualTo "") then {
        [duws_faction_list_record, duws_faction_list_current, createHashMap] call fnc_faction_list_base
    } else {
        ["base", [duws_faction_list_record], []] call fnc_faction_ask
    };
};

// _sel is a row index or a class to land on.
duws_faction_list_fill = {
    params [["_sel", 0]];
    private _ctrl = [8633] call duws_faction_edit_ctrl;
    if (isNull _ctrl) exitWith {};
    private _list = [duws_faction_list_base, duws_faction_list_record] call fnc_faction_list_resolve;
    lbClear _ctrl;
    {
        private _i = _ctrl lbAdd _x;
        _ctrl lbSetData [_i, _x];
        _ctrl lbSetTooltip [_i, getText (configFile >> "CfgVehicles" >> _x >> "displayName")];
    } forEach _list;
    if (_list isEqualTo []) exitWith {};
    _ctrl lbSetColor [0, [0.4, 0.8, 1, 1]];
    if (_sel isEqualType "") then { _sel = 0 max (_list find _sel); };
    _ctrl lbSetCurSel (_sel min (count _list - 1));
};

private _display = uiNamespace getVariable ["duws_faction_edit_display", displayNull];
private _listCtrl = _display displayCtrl 8633;
(_display displayCtrl 8638) ctrlSetStructuredText parseText format ["<t size='0.7' color='#c0c0c0'>%1</t>",
    localize "STR_DUWS_T_faction_edit_pool"];

// The top row is main, which cannot be removed: a removal would re-parent the role to the next row
// without a word.
_listCtrl ctrlAddEventHandler ["LBSelChanged", {
    params ["_ctrl", "_i"];
    { ((ctrlParent _ctrl) displayCtrl _x) ctrlEnable (_i > 0); } forEach [8635, 8636];
}];

// Shows the row's vehicle in the browser: its faction (ALL when the combo lacks it), filter cleared.
_listCtrl ctrlAddEventHandler ["LBDblClick", {
    params ["_ctrl", "_i"];
    private _class = _ctrl lbData _i;
    private _factionCtrl = [8623] call duws_faction_edit_ctrl;
    ([8632] call duws_faction_edit_ctrl) ctrlSetText "";
    private _faction = getText (configFile >> "CfgVehicles" >> _class >> "faction");
    private _fIdx = 0 max (duws_faction_edit_list findIf { (_x select 1) isEqualTo _faction });
    duws_faction_edit_pick = _class;
    // Same faction: no selection change raises the combo's refetch, and the cleared filter needs a refill.
    if (lbCurSel _factionCtrl == _fIdx) then {
        [] call duws_faction_fill_classes;
    } else {
        _factionCtrl lbSetCurSel _fIdx;
    };
}];

(_display displayCtrl 8634) ctrlAddEventHandler ["ButtonClick", {
    private _classCtrl = [8625] call duws_faction_edit_ctrl;
    private _class = _classCtrl lbData (lbCurSel _classCtrl);
    if (_class isEqualTo "") exitWith {};
    duws_faction_list_record = [duws_faction_list_record, "add", _class, duws_faction_list_base] call fnc_faction_list_edit;
    [_class] call duws_faction_list_fill;
}];

(_display displayCtrl 8635) ctrlAddEventHandler ["ButtonClick", {
    private _ctrl = [8633] call duws_faction_edit_ctrl;
    private _i = lbCurSel _ctrl;
    if (_i < 1) exitWith {};
    duws_faction_list_record = [duws_faction_list_record, "remove", _ctrl lbData _i, duws_faction_list_base] call fnc_faction_list_edit;
    [_i] call duws_faction_list_fill;
}];

// Spawned, with the working line up: a new main's base can take a parse of its whole faction.
(_display displayCtrl 8636) ctrlAddEventHandler ["ButtonClick", {
    private _ctrl = [8633] call duws_faction_edit_ctrl;
    private _i = lbCurSel _ctrl;
    if (_i < 1) exitWith {};
    [_ctrl lbData _i] spawn {
        params ["_class"];
        private _display = uiNamespace getVariable ["duws_faction_edit_display", displayNull];
        { (_display displayCtrl _x) ctrlEnable false; } forEach LIST_CTRLS;
        (_display displayCtrl 8628) ctrlSetStructuredText parseText format ["<t size='0.8' color='#ffcc55'>%1</t>",
            localize "STR_DUWS_T_faction_edit_working"];
        uiSleep 0.05;

        duws_faction_list_record = [duws_faction_list_record, "main", _class, duws_faction_list_base] call fnc_faction_list_edit;
        [] call duws_faction_list_rebase;

        { (_display displayCtrl _x) ctrlEnable true; } forEach LIST_CTRLS;
        [] call duws_faction_edit_preview;
        [0] call duws_faction_list_fill;
    };
}];

(_display displayCtrl 8637) ctrlAddEventHandler ["ButtonClick", {
    duws_faction_list_record = NO_EDITS;
    [] call duws_faction_list_rebase;
    [0] call duws_faction_list_fill;
}];

(_display displayCtrl 8630) ctrlAddEventHandler ["ButtonClick", {
    private _key = duws_faction_edit_key;
    private _list = [duws_faction_list_base, duws_faction_list_record] call fnc_faction_list_resolve;
    private _edits = uiNamespace getVariable ["duws_faction_edits", createHashMap];
    private _tiers = missionNamespace getVariable ["duws_faction_tiers", createHashMap];
    // A list left as detected is no edit: it keeps the tier resolution gave it, and sends no record.
    if (duws_faction_list_record isEqualTo NO_EDITS) then {
        _edits deleteAt _key;
        _tiers set [_key, (createHashMapFromArray (missionNamespace getVariable ["DUWS_factionTiers", []])) getOrDefault [_key, 0]];
    } else {
        _edits set [_key, duws_faction_list_record];
        _tiers set [_key, 0];
    };
    {
        private _rows = _x select 1;
        private _i = _rows findIf { (_x select 0) isEqualTo _key };
        if (_i >= 0) exitWith { _rows set [_i, [_key, _list]]; };
    } forEach duws_faction_table;

    ["INFO", "FACTION", format ["List editor: %1 <- %2 (edits %3)", _key, _list, duws_faction_list_record]] call fnc_log;
    closeDialog 0;
    [_key] call fnc_faction_row_paint;
}];

[] call duws_faction_list_rebase;
[0] call duws_faction_list_fill;
