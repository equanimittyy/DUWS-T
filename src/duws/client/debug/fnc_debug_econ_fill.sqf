// Locality: the client that asked -- fnc_debug_econ_server answers this with its snapshot. Arrives
// whole frames after the request, so it finds its controls by IDC and no-ops if the window closed
// meanwhile. English-only like the rest of the debug tooling.
if (!hasInterface) exitWith {};

params [["_towns", []], ["_escalation", []]];

disableSerialization;
// Recorded in uiNamespace by the menu on open; null = closed since the request.
private _display = uiNamespace getVariable ["DUWS_debug_econ_display", displayNull];
if (isNull _display) exitWith {};

// Client-side figures, re-read each snapshot so an edit shows its new total.
{
    private _ctrl = _display displayCtrl (_x select 0);
    if (!isNull _ctrl) then { _ctrl ctrlSetText format [_x select 1, _x select 2] };
} forEach [[9514, "BLU CP (%1)", commandpointsblu1], [9515, "BLU AP (%1)", WARCOM_blufor_ap], [9516, "OPF AP (%1)", WARCOM_opfor_ap],
    [9518, "Money (%1)", [player] call fnc_money_count]];

private _list = _display displayCtrl 9522;
if (isNull _list) exitWith {};

// Every edit refills the list; falling back to row 0 would aim the next click at the first town.
private _picked = if (lbCurSel _list < 0) then { "" } else { _list lbData (lbCurSel _list) };
private _sel = 0;
lbClear _list;
{
    _x params ["_index", "_name", "_hasRep", "_rep", "_ap", ["_tier", 0], ["_str", 1]];
    // Data = town index, not row position: buttons act on the picked town even if the list order changes.
    // Tier arabic here, not the map's roman -- it's the figure the +/- button moves.
    private _row = _list lbAdd format ["%1  --  rep %2, worth %3, tier %4, str %5",
        _name, if (_hasRep) then { _rep } else { "n/a" }, _ap, _tier, _str];
    _list lbSetData [_row, str _index];
    if (str _index == _picked) then { _sel = _row };
} forEach _towns;
if (count _towns > 0) then { _list lbSetCurSel _sel };
// The wheel scrolls the focused control, and the amount box holds focus from open.
ctrlSetFocus _list;

private _readout = _display displayCtrl 9520;
if (isNull _readout) exitWith {};

_escalation params [["_destroyed", -1], ["_budget", 0], ["_tier", 0], ["_level", 0], ["_mult", 1]];
if (_destroyed < 0) then {
    _readout ctrlSetText "Escalation: not running in this campaign.";
} else {
    // Print tier size too: the destroyed count alone doesn't say how close the next level is on this map.
    _readout ctrlSetText format
        ["Escalation: %1 of %2 houses destroyed | level %3/11 | %4 per level | prices x%5",
        _destroyed, _budget, _level, round _tier, _mult];
};
