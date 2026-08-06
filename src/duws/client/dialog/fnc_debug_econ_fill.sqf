// Locality: the client that asked -- fnc_debug_econ_server answers this with its snapshot.
/*
    Draws the server-only half of the debug economy window: the town list and the escalation
    readout. Arrives asynchronously, so it finds its own controls by IDC rather than being handed
    them, and does nothing if the window has since been closed.
    Strings are English-only for the same reason as the rest of the debug tooling.
*/
if (!hasInterface) exitWith {};

params [["_towns", []], ["_escalation", []]];

disableSerialization;
// The window records itself in uiNamespace when it opens, because this answer arrives whole frames
// later and has no other way to find it. Null means the player closed it in the meantime.
private _display = uiNamespace getVariable ["DUWS_debug_econ_display", displayNull];
if (isNull _display) exitWith {};

private _list = _display displayCtrl 9522;
if (isNull _list) exitWith {};

lbClear _list;
{
    _x params ["_index", "_name", "_hasRep", "_rep", "_ap", ["_tier", 0], ["_str", 1]];
    // The row carries the town index as its data, so the buttons act on the town the player picked
    // rather than on the position it happens to occupy in a list that skips nothing today but might.
    // Tier is arabic here rather than the roman the map readout prints: this is the figure the +/-
    // button moves, so a tester reads it in the units they are typing a delta in.
    private _row = _list lbAdd format ["%1  --  rep %2, worth %3, tier %4, str %5",
        _name, if (_hasRep) then { _rep } else { "n/a" }, _ap, _tier, _str];
    _list lbSetData [_row, str _index];
} forEach _towns;
if (count _towns > 0) then { _list lbSetCurSel 0 };

private _readout = _display displayCtrl 9520;
if (isNull _readout) exitWith {};

_escalation params [["_destroyed", -1], ["_budget", 0], ["_tier", 0], ["_level", 0], ["_mult", 1]];
if (_destroyed < 0) then {
    _readout ctrlSetText "Escalation: not running in this campaign.";
} else {
    // Tier size is printed because it is what the level costs: the destroyed count on its own says
    // nothing about how close the next level is on this particular map.
    _readout ctrlSetText format
        ["Escalation: %1 of %2 houses destroyed | level %3/11 | %4 per level | prices x%5",
        _destroyed, _budget, _level, round _tier, _mult];
};
