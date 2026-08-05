// Locality: client -- inherited from client/dialog/fnc_faction_confirm.sqf.
//
// Fills the confirmation screen's scroll group with one row per role key, both sides side by side.
//
// The four shared sections hold the same keys in the same order on both sides, so a role reads
// across one line. SPECIAL is the exception by design -- what only one army fields, filed there
// rather than into a shared section precisely so it cannot push the other column out of step.
// The padding below is what serves it: a section is as tall as the longer side's share of it and
// the shorter side leaves the tail blank.
//
// Everything is created into the one group (idc 8606) so its single scrollbar carries both columns
// at once. Two groups would need their scroll positions synchronised every frame.

// Mirrors shared/includes/defines.hpp. That file cannot be included here -- it is a config, not
// SQF -- and the row positions have to land on the same grid the dialog around them is laid out on.
#define GUI_GRID_W  0.025
#define GUI_GRID_H  0.04

#define ROW_H       1.0
#define BLOCK_W     18.2
#define BLU_X       0.2
#define OPF_X       18.9
#define LABEL_W     12.6
#define SELECT_X    12.8
#define SELECT_W    3.2
#define CLEAR_X     16.2
#define CLEAR_W     2.0

private _display = uiNamespace getVariable ["duws_faction_confirm_display", displayNull];
if (isNull _display) exitWith {};
private _group = _display displayCtrl 8606;

// Label handles by key, so an edit repaints its own row without walking the group.
private _rowCtrls = createHashMap;
uiNamespace setVariable ["duws_faction_row_ctrls", _rowCtrls];

private _sides = ["blufor", "opfor"];
private _schemas = _sides apply { [_x] call fnc_faction_schema };

private _y = 0;
{
    private _section = _x;
    private _perSide = _schemas apply { _x select {(_x select 1) isEqualTo _section} };

    // Section caption, drawn on both columns at the same height. It is what the alignment above
    // exists to preserve, so it is emitted before the rows rather than inferred from them.
    {
        private _caption = _display ctrlCreate ["RscText", -1, _group];
        _caption ctrlSetPosition [_x * GUI_GRID_W, _y * GUI_GRID_H, BLOCK_W * GUI_GRID_W, ROW_H * GUI_GRID_H];
        _caption ctrlSetBackgroundColor [1, 1, 1, 0.12];
        _caption ctrlSetText format ["  %1", localize format ["STR_DUWS_T_faction_group_%1", toLower _section]];
        _caption ctrlSetFont "PuristaMedium";
        _caption ctrlSetFontHeight 0.026;
        _caption ctrlCommit 0;
    } forEach [BLU_X, OPF_X];
    _y = _y + ROW_H;

    private _rows = 0;
    { _rows = _rows max (count _x); } forEach _perSide;

    for "_i" from 0 to (_rows - 1) do {
        {
            private _sideIdx = _forEachIndex;
            private _keys = _x;
            if (_i < count _keys) then {
                private _key = (_keys select _i) select 0;
                private _blockX = [BLU_X, OPF_X] select _sideIdx;

                private _label = _display ctrlCreate ["RscText", -1, _group];
                _label ctrlSetPosition [(_blockX) * GUI_GRID_W, _y * GUI_GRID_H, LABEL_W * GUI_GRID_W, ROW_H * GUI_GRID_H];
                _label ctrlSetFontHeight 0.025;
                _label ctrlCommit 0;
                _rowCtrls set [_key, _label];

                private _select = _display ctrlCreate ["RscButton", -1, _group];
                _select ctrlSetPosition [(_blockX + SELECT_X) * GUI_GRID_W, (_y + 0.075) * GUI_GRID_H, SELECT_W * GUI_GRID_W, 0.85 * GUI_GRID_H];
                _select ctrlSetText localize "STR_DUWS_T_faction_confirm_select";
                _select ctrlSetFontHeight 0.022;
                _select ctrlSetBackgroundColor [0.16, 0.3, 0.55, 0.7];
                _select setVariable ["duws_key", _key];
                _select setVariable ["duws_side", _sides select _sideIdx];
                _select ctrlAddEventHandler ["ButtonClick", {
                    params ["_ctrl"];
                    [_ctrl getVariable "duws_side", _ctrl getVariable "duws_key"] spawn fnc_faction_key_edit;
                }];
                _select ctrlCommit 0;

                private _clear = _display ctrlCreate ["RscButton", -1, _group];
                _clear ctrlSetPosition [(_blockX + CLEAR_X) * GUI_GRID_W, (_y + 0.075) * GUI_GRID_H, CLEAR_W * GUI_GRID_W, 0.85 * GUI_GRID_H];
                _clear ctrlSetText localize "STR_DUWS_T_faction_confirm_clear";
                _clear ctrlSetFontHeight 0.022;
                _clear ctrlSetBackgroundColor [0.5, 0.2, 0.2, 0.7];
                _clear setVariable ["duws_key", _key];
                _clear ctrlAddEventHandler ["ButtonClick", {
                    params ["_ctrl"];
                    [_ctrl getVariable "duws_key"] call fnc_faction_prompt_clear;
                }];
                _clear ctrlCommit 0;
                _rowCtrls set [_key + "_clear", _clear];

                [_key] call fnc_faction_row_paint;
            };
        } forEach _perSide;
        _y = _y + ROW_H;
    };
} forEach ["INFANTRY", "VEHICLES", "STATIC", "OPERATORS", "SPECIAL"];
