// Locality: client -- pure UI, for the faction class browser.
/*
    Fills a class list from [displayName, className] rows, narrowed by a filter box.
    Params: [_classCtrl, _filterCtrl, _rows, _pick].

    Returns the rows that survived the filter, so a caller can tell an empty result from a full one:
    lbSetCurSel raises no LBSelChanged on an empty list, and the preview the selection drives has to
    be told itself.
*/
params ["_classCtrl", "_filterCtrl", ["_rows", []], ["_pick", ""]];
if (isNull _classCtrl) exitWith { [] };

// Case-insensitive substring over both the display name and the classname, so a filter matches either
// what the player reads or the raw class they already know.
private _filter = toLower (if (isNull _filterCtrl) then {""} else {ctrlText _filterCtrl});
if (_filter != "") then {
    _rows = _rows select {
        ((toLower (_x select 0)) find _filter >= 0) || {(toLower (_x select 1)) find _filter >= 0}
    };
};

lbClear _classCtrl;
{
    private _i = _classCtrl lbAdd format ["%1  --  %2", _x select 0, _x select 1];
    // The classname is the only thing read back off the control.
    _classCtrl lbSetData [_i, _x select 1];
} forEach _rows;

if (_rows isNotEqualTo []) then {
    _classCtrl lbSetCurSel (0 max (_rows findIf { (_x select 1) isEqualTo _pick }));
};

_rows
