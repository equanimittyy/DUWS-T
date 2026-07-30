// Locality: any -- pure read of faction globals, called from both dialogs and server init.
//
// The one reader of a faction's request menu. Returns [[class, label, cost], ...] holding only the
// slots a faction actually filled: callers index it directly and iterate it whole, so the "empty"
// padding never reaches them.
//
// TRANSITIONAL: prefers the array globals (blufor_RQST_UNITS / blufor_RQST_VEHICLES) and falls back
// to walking the numbered blufor_RQST_UNIT_01_X ... _99_X names. The fallback exists so a faction
// file that has not been converted -- including one shipped by a third party against the old shape
// -- still populates its menus. Delete it once a vanilla, a modded and an auto-detected faction
// have each been seen filling both menus in game; nothing static can confirm that, because these
// globals are built at runtime and no linter sees them.
params [["_kind", "UNIT"]];

private _list = missionNamespace getVariable [format ["blufor_RQST_%1S", _kind], []];
if !(_list isEqualTo []) exitWith { _list };

// Same stopping rule the numbered menus always used: the first unset, "empty" or zero-cost slot
// ends the list, so a faction may leave gaps at the end but not in the middle. The walk runs to 99
// rather than the documented 50-slot ceiling because the old menu builder did, and an unconverted
// third-party faction is exactly the case this fallback exists to carry.
private _out = [];
for "_i" from 1 to 99 do {
    private _var = format ["blufor_RQST_%1_%2_X", _kind, if (_i < 10) then { "0" + str _i } else { str _i }];
    if (isNil _var) exitWith {};
    private _entry = missionNamespace getVariable [_var, []];
    if (count _entry < 3) exitWith {};
    // `==`, not isEqualTo: string equality here has to stay case-insensitive, because the padding
    // is spelled "empty" in most faction files and "Empty" in a handful.
    if ((_entry select 0) == "empty" || {(_entry select 2) == 0}) exitWith {};
    _out pushBack _entry;
};
_out
