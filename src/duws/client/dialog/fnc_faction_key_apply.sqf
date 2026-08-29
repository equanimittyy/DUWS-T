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

// Only vehicle keys draw from a pool at spawn (fnc_faction_poolable_keys), so a man or static key
// holds just the picked class: a bucket would show the row a (+N) count the commit then collapses
// away, and pay the faction parse below to build it.
private _pool = [_class];
if (duws_faction_edit_kind isEqualTo "vehicle") then {
    // Said before the parse rather than after, because that parse walks a whole faction's CfgVehicles
    // and on a heavy mod set takes long enough that the screen reads as frozen: the button stops
    // responding and nothing on it changes. The controls are disabled alongside so a second impatient
    // click cannot start the work twice.
    { (_display displayCtrl _x) ctrlEnable false; } forEach [8623, 8625, 8629, 8630];
    (_display displayCtrl 8628) ctrlSetStructuredText parseText format ["<t size='0.8' color='#ffcc55'>%1</t>",
        localize "STR_DUWS_T_faction_edit_working"];
    // One frame for the line above to actually paint. The parse that follows holds the frame for its
    // whole run, so without this yield the message is set and overwritten without ever being drawn.
    uiSleep 0.05;

    // Per faction and per screen: the parse walks a whole faction's CfgVehicles, and its answer cannot
    // change while the confirmation screen is open.
    private _cache = uiNamespace getVariable ["duws_faction_parse_cache", createHashMap];
    private _parsed = _cache get _faction;
    if (isNil "_parsed") then {
        _parsed = [_faction] call fnc_parseFaction;
        _cache set [_faction, _parsed];
    };

    // The pool the row locks and fnc_faction_pick later draws from -- the class plus its faction's
    // tightest role bucket. Same classifier the post-commit augment pass runs, so an edited role and
    // an augmented one build their pool the one way.
    _pool = [_class, _parsed] call fnc_faction_pool_for_class;
};

{
    private _rows = _x select 1;
    private _i = _rows findIf { (_x select 0) isEqualTo _key };
    if (_i >= 0) exitWith { _rows set [_i, [_key, _pool]]; };
} forEach duws_faction_table;

// A picked class is the player's own choice, not a fallback: drop the row to white.
private _tiers = missionNamespace getVariable ["duws_faction_tiers", createHashMap];
_tiers set [_key, 0];

closeDialog 0;
[_key] call fnc_faction_row_paint;
