// Locality: client -- spawned from the key editor's CONFIRM button.
//
// Writes the picked class into the confirmation screen's working table and closes the editor.
//
// It does not write a bare classname. A role global may hold an array -- the pool fnc_faction_pick
// draws from at each spawn, which is how AutoDetect gives a faction more than one APC -- and
// collapsing that to the single class the player clicked would throw away the variety detection
// exists to produce. So the pick is put back through the same classifier AutoDetect uses:
// fnc_parseFaction buckets the chosen faction, the bucket holding the picked class becomes the
// pool, and the pick is moved to the front of it. fnc_faction_pools_publish then takes the first
// entry as the representative, so the row shows what the player chose and every single-value
// reader gets it, while the rest of the bucket stays available per spawn.
//
// The smallest matching bucket wins: a rifleman appears in both the whole-infantry list and the
// grunt list, and the tighter of the two is the role the player was editing.

// Read off the editor's own display. The IDC forms resolve against whichever display the engine
// holds current, and the confirmation screen is open underneath -- landing there they return "",
// which this used to read as "nothing picked" and answer a CONFIRM click by closing the editor and
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

// Per faction and per screen: the parse walks a whole faction's CfgVehicles, and its answer cannot
// change while the confirmation screen is open.
private _cache = uiNamespace getVariable ["duws_faction_parse_cache", createHashMap];
private _parsed = _cache get _faction;
if (isNil "_parsed") then {
    _parsed = [_faction] call fnc_parseFaction;
    _cache set [_faction, _parsed];
};

// Index 1 of the parse is itself a list of per-role infantry buckets; everything else is a flat
// list of classnames. Flattening one level gives every bucket the class could belong to.
private _buckets = [];
{ if (_forEachIndex != 1) then { _buckets pushBack _x; }; } forEach _parsed;
_buckets append (_parsed select 1);

private _matching = _buckets select { _x isEqualType [] && {!(_x isEqualTo [])} && {_class in _x} };

private _pool = [_class];
if !(_matching isEqualTo []) then {
    private _best = _matching select 0;
    { if (count _x < count _best) then { _best = _x; }; } forEach _matching;
    _pool = [_class] + (_best select { _x isEqualType "" && {_x != _class} });
};

{
    private _rows = _x select 1;
    private _i = _rows findIf { (_x select 0) isEqualTo _key };
    if (_i >= 0) exitWith { _rows set [_i, [_key, _pool]]; };
} forEach duws_faction_table;

closeDialog 0;
[_key] call fnc_faction_row_paint;
