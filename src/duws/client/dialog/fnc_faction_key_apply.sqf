// Locality: client -- called from the single-pick dialog's CONFIRM button, which only infantry and
// static keys open (fnc_faction_poolable_keys holds those roles to one class; a vehicle key opens the
// list editor, fnc_faction_key_list).
//
// Writes the picked class into the confirmation screen's working table and closes the editor.

// Read off the editor's own display. The IDC forms resolve against whichever display the engine
// holds current, and the confirmation screen is open underneath -- landing there they return "",
// which reads as "nothing picked" and would answer a CONFIRM click by closing the editor and
// changing nothing.
private _display = uiNamespace getVariable ["duws_faction_edit_display", displayNull];
if (isNull _display) exitWith {
    ["ERROR", "FACTION", "Key editor confirmed with no display; the pick was dropped."] call fnc_log;
    closeDialog 0;
};

private _key = duws_faction_edit_key;
private _factionCtrl = _display displayCtrl 8623;
private _classCtrl = _display displayCtrl 8625;
private _faction = _factionCtrl lbData (lbCurSel _factionCtrl);
private _class = _classCtrl lbData (lbCurSel _classCtrl);

if (_class isEqualTo "") exitWith {
    ["WARN", "FACTION", format ["Key editor confirmed with no class selected for %1.", _key]] call fnc_log;
    closeDialog 0;
};

["INFO", "FACTION", format ["Key editor: %1 <- %2 (faction %3)", _key, _class, _faction]] call fnc_log;

{
    private _rows = _x select 1;
    private _i = _rows findIf { (_x select 0) isEqualTo _key };
    if (_i >= 0) exitWith { _rows set [_i, [_key, [_class]]]; };
} forEach duws_faction_table;

// A picked class is the player's own choice, not a fallback: drop the row to white.
private _tiers = missionNamespace getVariable ["duws_faction_tiers", createHashMap];
_tiers set [_key, 0];

closeDialog 0;
[_key] call fnc_faction_row_paint;
